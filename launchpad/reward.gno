package launchpad

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/common"
)

var rewardStore = NewRewardStore() // TODO: init?

// Calculator is an interface responsible for calculating project rewards.
type Calculator interface {
	// CalculateRewards calculates the rewards for a specific project.
	CalculateRewards(pid string, height uint64) (*u256.Uint, error)

	// GetAccumulatedRewards returns the accumulated rewards for a project up to the current point.
	GetAccumulatedRewards(pid string) (*u256.Uint, error)

	// GetRewardsInRange calculates the rewards for a specific range.
	GetRewardsInRange(pid string, startHeight, endHeight uint64) (*u256.Uint, error)

	// UpdateRewardSnapshot saves the reward snapshot at the current point in time.
	UpdateRewardSnapshot(pid string) error
}

// RewardStore stores reward-related metadata
type RewardStore struct {
	accumulatedRewards   *avl.Tree // key: project ID, value: *u256.Uint
	lastCalculatedHeight *avl.Tree // key: project ID, value: uint64
	rewardSnapshots      *avl.Tree // key: <project ID, height>, value: *RewardSnapshot
}

func NewRewardStore() *RewardStore {
	return &RewardStore{
		accumulatedRewards:   avl.NewTree(),
		lastCalculatedHeight: avl.NewTree(),
		rewardSnapshots:      avl.NewTree(),
	}
}

type RewardSnapshot struct {
	Height             uint64
	AccumulatedRewards *u256.Uint
	TierRewards        *avl.Tree // key: tier, value: *u256.Uint
}

func (rs *RewardStore) CalculateRewards(pid string, height uint64) (*u256.Uint, error) {
	lastHeight, exists := rs.lastCalculatedHeight.Get(pid)
	if !exists {
		lastHeight = uint64(0)
	}

	lstHeight := lastHeight.(uint64)
	if height <= lstHeight {
		// return cached value if height already calculated
		rwd, exists := rs.accumulatedRewards.Get(pid)
		if !exists {
			return u256.NewUint(0), nil
		}
		return rwd.(*u256.Uint), nil
	}

	project, exists := projects[pid] // TODO: avl later
	if !exists {
		return nil, ufmt.Errorf("project(%s) not found", pid)
	}

	// not started yet
	if project.startHeight > height {
		return u256.Zero(), nil
	}

	// calculate rewards
	totalReward := calculateProjectReward(&project, lstHeight, height)

	// update accumulated rewards
	rs.accumulatedRewards.Set(pid, totalReward)
	rs.lastCalculatedHeight.Set(pid, height)

	return totalReward, nil
}

func calculateProjectReward(proj *Project, startHeight, endHeight uint64) *u256.Uint {
	totalReward := u256.Zero()

	tiers := []struct {
		tier  *Tier
		ratio uint64
	}{
		{&proj.tier30, proj.tier30Ratio},
		{&proj.tier90, proj.tier90Ratio},
		{&proj.tier180, proj.tier180Ratio},
	}

	for _, t := range tiers {
		if t.tier.startHeight == 0 || t.tier.startHeight > endHeight {
			continue
		}

		calcStart := common.U64Maxstart(startHeight, t.tier.startHeight)
		calcEnd := common.U64Min(endHeight, t.tier.endHeight)

		if calcStart > calcEnd {
			continue
		}

		blockReward := calcTierRewardPerBlock(t.tier, t.ratio)

		blocks := calcEnd - calcStart // +1?
		tierReward := new(u256.Uint).Mul(blockReward, u256.NewUint(blocks))
		totalReward = new(u256.Uint).Add(totalReward, tierReward)
	}

	return totalReward
}

// calcTierRewardPerBlock calculates the reward per block for a given tier
func calcTierRewardPerBlock(tier *Tier, ratio uint64) *u256.Uint {
	if tier.tierAmountPerBlockX96 != nil {
		return tier.tierAmountPerBlockX96
	}

	totalBlocks := tier.endHeight - tier.startHeight // +1?
	if totalBlocks == 0 {
		return u256.Zero()
	}

	amountPerBlock := new(u256.Uint).Div(
		new(u256.Uint).Mul(u256.NewUint(tier.tierAmount), q96),
		u256.NewUint(totalBlocks),
	)

	return amountPerBlock
}

func (rs *RewardStore) GetAccumulatedRewards(pid string) (*u256.Uint, error) {
	reward, exists := rs.accumulatedRewards.Get(pid)
	if !exists {
		return u256.Zero(), nil
	}
	return reward.(*u256.Uint), nil
}

func (rs *RewardStore) UpdateRewardSnapshot(pid string) error {
	height := uint64(std.GetHeight())

	reward, err := rs.CalculateRewards(pid, height)
	if err != nil {
		return err
	}

	snapshot := &RewardSnapshot{
		Height:             height,
		AccumulatedRewards: reward,
		TierRewards:        avl.NewTree(),
	}

	project, exists := projects[pid] // TODO: avl later
	if !exists {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("project(%s) not found", pid),
		))
	}

	tiers := []struct {
		tier *Tier
		id   string
	}{
		{&project.tier30, "30"},
		{&project.tier90, "90"},
		{&project.tier180, "180"},
	}

	for _, t := range tiers {
		tierReward := calculateTierReward(t.tier, height)
		snapshot.TierRewards.Set(t.id, tierReward)
	}

	key := createSnapshotkey(pid, height)
	rs.rewardSnapshots.Set(key, snapshot)

	return nil
}

func calculateTierReward(tier *Tier, height uint64) *u256.Uint {
	if tier.startHeight == 0 || tier.startHeight > height {
		return u256.Zero()
	}

	endHeight := common.U64Min(height, tier.endHeight)
	if tier.startHeight >= endHeight {
		return u256.Zero()
	}

	blocks := endHeight - tier.startHeight
	return new(u256.Uint).Mul(tier.tierAmountPerBlockX96, u256.NewUint(blocks))
}

func createSnapshotkey(pid string, height uint64) string {
	return ufmt.Sprintf("%s:%d", pid, height)
}

func (rs *RewardStore) GetRewardsInRange(pid string, startHeight, endHeight uint64) (*u256.Uint, error) {
	if startHeight >= endHeight {
		return u256.Zero(), nil
	}

	startReward, err := rs.CalculateRewards(pid, startHeight)
	if err != nil {
		return nil, err
	}

	endReward, err := rs.CalculateRewards(pid, endHeight)
	if err != nil {
		return nil, err
	}

	return new(u256.Uint).Sub(endReward, startReward), nil
}
