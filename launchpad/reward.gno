package launchpad

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/common"
)

var rewardStore *RewardStore

func init() {
	rewardStore = NewRewardStore()
}

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

// RewardStore manages reward calculations and snapshots for projects.
// It tracks accumulated rewards, calculation heights, and maintains reward history.
type RewardStore struct {
	// accumulatedRewards stores total rewards for each project
	accumulatedRewards   *avl.Tree // project ID -> *u256.Uint

	// lastCalculatedHeights tracks the last block height where rewards were calculated
	lastCalculatedHeight *avl.Tree // project ID -> uint64

	// rewardSnapshots stores point-in-time reward state
	rewardSnapshots      *avl.Tree // <project ID, height> -> *RewardSnapshot
}

func NewRewardStore() *RewardStore {
	return &RewardStore{
		accumulatedRewards:   avl.NewTree(),
		lastCalculatedHeight: avl.NewTree(),
		rewardSnapshots:      avl.NewTree(),
	}
}

// RewardSnapshot represents a point-in-time capture of reward state.
// It includes the total accumulated reward and tier-specific rewards.
type RewardSnapshot struct {
	Height             uint64
	AccumulatedRewards *u256.Uint
	TierRewards        *avl.Tree // tier -> *u256.Uint
}

// CalculateRewards computes rewards for a project up to the specified height.
//
// It returns the total calculated reward and any error encountered.
// The calculation takes into account tier-specific reward rates and durations.
//
// Parameters:
//  - pid: the project ID
//  - height: the block height up to which rewards are calculated
//
// Returns:
//  - *u256.Uint: the total calculated reward
//  - error: any error encountered during the calculation
func (rs *RewardStore) CalculateRewards(pid string, height uint64) (*u256.Uint, error) {
	lastHeight, exists := rs.lastCalculatedHeight.Get(pid)
	lstHeight := uint64(0)
	if exists {
		lstHeight = lastHeight.(uint64)
	}

	if height <= lstHeight {
		// return cached value if height already calculated
		rwd, exists := rs.accumulatedRewards.Get(pid)
		if !exists {
			return u256.Zero(), nil
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

	// (1) compute a new reward for the interval lstHeight to height
	newReward := calculateProjectReward(&project, lstHeight, height)

	// (2) add the existing accumulated reward and update it to the final accumulated value
	oldAccum := u256.Zero()
	if accum, ok := rs.accumulatedRewards.Get(pid); ok {
		oldAccum = accum.(*u256.Uint)
	}

	totalReward := new(u256.Uint).Add(oldAccum, newReward)

	// (3) update accumulated rewards
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
		reward := calculateTierRewardForRange(t.tier, t.ratio, startHeight, endHeight)
		totalReward = new(u256.Uint).Add(totalReward, reward)
	}

	return totalReward
}

// calculate start to end height range compensation for a specific tier
func calculateTierRewardForRange(tier *Tier, ratio, startHeight, endHeight uint64) *u256.Uint {
	if tier.startHeight == 0 || tier.startHeight > endHeight {
		return u256.Zero()
	}

	calcStart := common.U64Max(startHeight, tier.startHeight)
	calcEnd := common.U64Min(endHeight, tier.endHeight)

	if calcStart > calcEnd {
		return u256.Zero()
	}

	blocks := calcEnd - calcStart + 1 // consider off by one

	// reward per block * blocks
	return new(u256.Uint).Mul(calcTierRewardPerBlock(tier, ratio), u256.NewUint(blocks))
}

// calcTierRewardPerBlock calculates the reward per block for a given tier
func calcTierRewardPerBlock(tier *Tier, ratio uint64) *u256.Uint {
	if tier.tierAmountPerBlockX96 != nil {
		// assume ratio is used as a simple scale factor
		return new(u256.Uint).Mul(tier.tierAmountPerBlockX96, u256.NewUint(ratio))
	}

	totalBlocks := (tier.endHeight - tier.startHeight + 1)
	if totalBlocks == 0 {
		return u256.Zero()
	}

	amountPerBlock := new(u256.Uint).Div(
		new(u256.Uint).Mul(u256.NewUint(tier.tierAmount), q96),
		u256.NewUint(totalBlocks),
	)

	return amountPerBlock
}

// GetAccumulatedRewards returns the total accumulated rewards for a project.
// If no rewards exist, returns zero.
func (rs *RewardStore) GetAccumulatedRewards(pid string) (*u256.Uint, error) {
	reward, exists := rs.accumulatedRewards.Get(pid)
	if !exists {
		return u256.Zero(), nil
	}
	return reward.(*u256.Uint), nil
}

// UpdateRewardSnapshot creates a new snapshot of the current reward state.
// It captures both total and tier-specific rewards at the current block height.
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

	blocks := endHeight - tier.startHeight + 1
	return new(u256.Uint).Mul(tier.tierAmountPerBlockX96, u256.NewUint(blocks))
}

func createSnapshotkey(pid string, height uint64) string {
	return ufmt.Sprintf("%s:%d", pid, height)
}

func (rs *RewardStore) GetRewardsInRange(pid string, startHeight, endHeight uint64) (*u256.Uint, error) {
	if startHeight >= endHeight {
		return u256.Zero(), ufmt.Errorf("startHeight(%d) >= endHeight(%d)", startHeight, endHeight)
	}

	startReward, err := rs.CalculateRewards(pid, startHeight)
	if err != nil {
		return nil, err
	}

	endReward, err := rs.CalculateRewards(pid, endHeight)
	if err != nil {
		return nil, err
	}

	if endReward.Cmp(startReward) < 0 {
		return u256.Zero(), ufmt.Errorf(
			"invalid reward range: endReward(%s) < startReward(%s)",
			endReward.ToString(), startReward.ToString(),
		)
	}

	return new(u256.Uint).Sub(endReward, startReward), nil
}
