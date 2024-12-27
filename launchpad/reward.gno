package launchpad

import (
	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

var (
	rewardStore = NewRewardStore() // TODO: init?
)

// RewardStore stores reward-related metadata
type RewardStore struct {
	accumulatedRewards *avl.Tree // key: project ID, value: *u256.Uint
	lastCalculatedHeight *avl.Tree // key: project ID, value: uint64
	rewardSnapshots *avl.Tree // key: <project ID, height>, value: *RewardSnapshot
}

func NewRewardStore() *RewardStore {
	return &RewardStore{
		accumulatedRewards: avl.NewTree(),
		lastCalculatedHeight: avl.NewTree(),
		rewardSnapshots: avl.NewTree(),
	}
}

type RewardSnapshot struct {
	Height uint64
	AccumulatedRewards *u256.Uint
	TierRewards *avl.Tree // key: tier, value: *u256.Uint
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

// func calculateProjectReward(proj *Project, startHeight, endHeight uint64) *u256.Uint {
// 	totalReward := u256.Zero()

// 	tiers := []struct{
// 		tier *Tier
// 		ratio uint64
// 	}{
// 		{&proj.tier30, proj.tier30Ratio},
// 		{&proj.tier90, proj.tier90Ratio},
// 		{&proj.tier180, proj.tier180Ratio},
// 	}
// }
