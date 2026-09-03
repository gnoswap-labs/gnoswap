package staker

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/p/gnoswap/gnsmath"
	"gno.land/p/gnoswap/utils"

	sr "gno.land/r/gnoswap/staker"
)

// UnstakedPositions manages exit checkpoints.
type UnstakedPositions struct {
	tree *bptree.BPTree
}

// NewUnstakedPositions creates a new UnstakedPositions instance.
func NewUnstakedPositions() *UnstakedPositions {
	return &UnstakedPositions{
		tree: sr.NewBPTreeN(16), // positionId -> *UnstakedPosition
	}
}

// Has checks if a position ID has an exit checkpoint.
func (self *UnstakedPositions) Has(positionId uint64) bool {
	return self.tree.Has(utils.EncodeUint64(positionId))
}

// get retrieves an exit checkpoint by position ID, or nil when there is none.
func (self *UnstakedPositions) get(positionId uint64) *sr.UnstakedPosition {
	value := self.tree.Get(utils.EncodeUint64(positionId))
	if value == nil {
		return nil
	}

	position, ok := value.(*sr.UnstakedPosition)
	if !ok {
		panic(ufmt.Sprintf("failed to cast value to *UnstakedPosition: %T", value))
	}

	return position
}

// set stores an exit checkpoint for a position ID.
func (self *UnstakedPositions) set(positionId uint64, position *sr.UnstakedPosition) {
	self.tree.Set(utils.EncodeUint64(positionId), position)
}

// remove deletes an exit checkpoint by position ID.
func (self *UnstakedPositions) remove(positionId uint64) {
	self.tree.Remove(utils.EncodeUint64(positionId))
}

// getUnstakedPositions returns the exit checkpoints backed by the store.
func (s *stakerV1) getUnstakedPositions() *UnstakedPositions {
	return &UnstakedPositions{tree: s.store.GetUnstakedPositions()}
}

// uncollectedIncentiveCountOf returns how many checkpoints still owe the incentive.
//
// The count is per incentive, not per pool: one checkpoint that can never be funded would
// otherwise lock the refunds of every other incentive in the same pool.
func (s *stakerV1) uncollectedIncentiveCountOf(incentiveId string) int64 {
	value := s.store.GetUncollectedIncentiveCounts().Get(incentiveId)
	if value == nil {
		return 0
	}

	count, ok := value.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast uncollected incentive count to int64: %T", value))
	}

	return count
}

// addUncollectedIncentiveCount moves the incentive's count by delta, dropping the entry at zero.
func (s *stakerV1) addUncollectedIncentiveCount(incentiveId string, delta int64) {
	next := gnsmath.SafeAddInt64(s.uncollectedIncentiveCountOf(incentiveId), delta)
	if next < 0 {
		panic(makeErrorWithDetails(
			errCalculationError,
			ufmt.Sprintf("uncollected count of incentive(%s) went negative", incentiveId),
		))
	}

	counts := s.store.GetUncollectedIncentiveCounts()
	if next == 0 {
		counts.Remove(incentiveId)
		return
	}

	counts.Set(incentiveId, next)
}

// recordUnstakedPosition writes the exit checkpoint before the teardown touches the pool.
// The deposit's incentive index is brought up to date first, so the checkpoint owes exactly
// the incentives the position accrued from.
func (s *stakerV1) recordUnstakedPosition(_ int, rlm realm, positionId uint64, deposit *sr.Deposit, exitTime int64) {
	poolPath := deposit.TargetPoolPath()

	pool, ok := s.getPools().Get(poolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("pool(%s) does not exist", poolPath),
		))
	}

	poolResolver := NewPoolResolver(pool)
	depositResolver := NewDepositResolver(deposit)

	lastUpdatedAt := depositResolver.LastExternalIncentiveUpdatedAt()
	if lastUpdatedAt < exitTime {
		poolResolver.IncentivesResolver().IterateIncentiveIdsByTime(lastUpdatedAt, exitTime, func(incentiveId string) bool {
			deposit.AddExternalIncentiveId(incentiveId)
			return false
		})
		deposit.SetLastExternalIncentiveUpdatedAt(exitTime)
	}

	tier, tierRatio, tierCount, err := s.getPoolTier().tierContextOf(poolPath)
	if err != nil {
		panic(err)
	}

	lowerTick := poolResolver.GetOrNewTick(deposit.TickLower())
	upperTick := poolResolver.GetOrNewTick(deposit.TickUpper())

	position := sr.NewUnstakedPosition(
		deposit,
		exitTime,
		poolResolver.CurrentTick(exitTime),
		lowerTick,
		upperTick,
		NewTickResolver(lowerTick).CurrentOutsideAccumulation(exitTime).ToString(),
		NewTickResolver(upperTick).CurrentOutsideAccumulation(exitTime).ToString(),
		tier,
		tierRatio,
		tierCount,
		s.GetUnstakingFee(),
		deposit.GetExternalIncentiveIdList(),
	)

	s.getUnstakedPositions().set(positionId, position)

	for _, incentiveId := range deposit.GetExternalIncentiveIdList() {
		s.addUncollectedIncentiveCount(incentiveId, 1)
	}
}

// dropUnstakedPositionIfCollected removes the checkpoint once every reward source is collected.
func (s *stakerV1) dropUnstakedPositionIfCollected(target *collectTarget) {
	if target.checkpoint.FullyCollected() {
		s.getUnstakedPositions().remove(target.positionId)
	}
}

// HasUnstakedPosition reports whether a position has uncollected rewards from a past stake.
func (s *stakerV1) HasUnstakedPosition(positionId uint64) bool {
	return s.getUnstakedPositions().Has(positionId)
}

// GetUnstakedPositionExitTime returns when an unstaked position stopped accruing rewards.
func (s *stakerV1) GetUnstakedPositionExitTime(positionId uint64) (int64, error) {
	position := s.getUnstakedPositions().get(positionId)
	if position == nil {
		return 0, ufmt.Errorf("%v: positionId(%d) has no uncollected reward", errDataNotFound, positionId)
	}

	return position.ExitTime(), nil
}
