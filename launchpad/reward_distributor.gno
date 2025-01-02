package launchpad

import (
	"std"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
	en "gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
	gs "gno.land/r/gnoswap/v1/gov/staker"
)

var rewardDistributor = NewRewardDistributor()

type DistributionRecord struct {
	User             std.Address
	ProjectId        string
	Amount           *u256.Uint
	DistributeHeight uint64
	DistributeTime   uint64
}

type RewardDistributor struct {
	pendingRewards      *avl.Tree // userAddr:projectId -> *u256.Uint
	distributionHistory *avl.Tree // userAddr:projectId:height -> *DistributionRecord
	lastUpdateHeight    *avl.Tree // projectId -> uint64
}

func NewRewardDistributor() *RewardDistributor {
	return &RewardDistributor{
		pendingRewards:      avl.NewTree(),
		distributionHistory: avl.NewTree(),
		lastUpdateHeight:    avl.NewTree(),
	}
}

func (rd *RewardDistributor) PendingRewards(user std.Address, pid string) (*u256.Uint, error) {
	key := generateRewardKey(user, pid)
	value, exists := rd.pendingRewards.Get(key)
	if !exists {
		return u256.Zero(), nil
	}

	return value.(*u256.Uint), nil
}

// DistributeRewards distributes rewards to all depositors in a specific project
func (rd *RewardDistributor) DistributeRewards(pid string) error {
	_, exists := projects[pid]
	if !exists {
		return ufmt.Errorf("project(%s) not found", pid)
	}

	common.IsHalted()
	en.MintAndDistributeGns()

	// update reward calculation
	if err := rewardStore.UpdateRewardSnapshot(pid); err != nil {
		return err
	}

	// get all deposits for the project
	dpsts, err := depositStore.GetProjectDeposits(pid)
	if err != nil {
		return err
	}

	for _, dpst := range dpsts {
		if !isRewardClaimable(dpst) {
			continue
		}

		reward, err := rd.calculateDepositReward(dpst)
		if err != nil {
			continue
		}

		if reward.IsZero() {
			continue
		}

		// update pending rewards
		rd.updatePendingReward(dpst.depositor, pid, reward)
	}

	return nil
}

func (rd *RewardDistributor) DistributeUserReward(user std.Address, pid string) (*u256.Uint, error) {
	key := generateRewardKey(user, pid)

	rv, exists := rd.pendingRewards.Get(key)
	if !exists {
		return u256.Zero(), nil
	}

	reward := rv.(*u256.Uint)
	if reward.IsZero() {
		return reward, nil // no pending rewards
	}

	// TODO: use avl
	gns.TransferFrom(a2u(consts.LAUNCHPAD_ADDR), a2u(user), reward.Uint64()) // ???

	record := &DistributionRecord{
		User:             user,
		ProjectId:        pid,
		Amount:           reward,
		DistributeHeight: uint64(std.GetHeight()),
		DistributeTime:   uint64(time.Now().Unix()),
	}

	historyKey := generateDistributionHistoryKey(key, record.DistributeHeight)
	rd.distributionHistory.Set(historyKey, record)

	// clear pending reward
	rd.pendingRewards.Set(key, u256.Zero()) // or use Remove?

	// update project stastics
	project := projects[pid]
	rd.updateProjectStats(project, reward)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"DistributeReward",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"user", user.String(),
		"projectId", pid,
		"amount", reward.ToString(),
	)

	return reward, nil
}

func (rd *RewardDistributor) BatchDistribute(users []std.Address, pid string) error {
	for _, user := range users {
		_, err := rd.DistributeUserReward(user, pid)
		if err != nil {
			continue
		}
	}

	return nil
}

func (rd *RewardDistributor) updateProjectStats(p Project, distributedAmount *u256.Uint) {
	p.totalCollectedAmount += distributedAmount.Uint64()
	projects[p.id] = p

	// update gov/staker contract
	gs.CollectRewardFromLaunchPad(p.recipient)
}

func (rd *RewardDistributor) calculateDepositReward(dpst *Deposit) (*u256.Uint, error) {
	project := projects[dpst.projectId]
	tier := getTier(project, dpst.tier)

	if tier.tierAmountPerBlockX96 == nil || tier.tierAmountPerBlockX96.IsZero() {
		return u256.Zero(), nil
	}

	ratioX96 := calcDepositRatioX96(tier.actualDepositAmount, dpst.amount)
	if ratioX96.IsZero() {
		return u256.Zero(), nil
	}

	// calculate blocks since last update
	lastHeight, exists := rd.lastUpdateHeight.Get(dpst.projectId)
	if !exists {
		lastHeight = dpst.depositHeight
	}

	currentHeight := uint64(std.GetHeight())
	if currentHeight <= lastHeight.(uint64) {
		return u256.Zero(), nil
	}

	blocks := currentHeight - lastHeight.(uint64) + 1 // off by one

	println("blocks", blocks)

	rewardX96 := new(u256.Uint).Mul(tier.tierAmountPerBlockX96, u256.NewUint(blocks))
	rewardForPeriodX96 := new(u256.Uint).Mul(rewardX96, ratioX96)
	reward := new(u256.Uint).Div(rewardForPeriodX96, new(u256.Uint).Mul(q96, q96))

	return reward, nil
}

func (rd *RewardDistributor) updatePendingReward(user std.Address, pid string, reward *u256.Uint) {
	key := generateRewardKey(user, pid)
	existingReward, exists := rd.pendingRewards.Get(key)
	if !exists {
		rd.pendingRewards.Set(key, reward)
		return
	}

	updateReward := new(u256.Uint).Add(existingReward.(*u256.Uint), reward)
	rd.pendingRewards.Set(key, updateReward)
}

func generateRewardKey(user std.Address, pid string) string {
	return ufmt.Sprintf("%s:%s", user.String(), pid)
}

func generateDistributionHistoryKey(key string, height uint64) string {
	return ufmt.Sprintf("%s:%d", key, height)
}

func isRewardClaimable(dpst *Deposit) bool {
	currentHeight := uint64(std.GetHeight())
	return currentHeight >= dpst.claimableHeight &&
		dpst.rewardCollectTime == 0 &&
		dpst.depositCollectHeight == 0
}
