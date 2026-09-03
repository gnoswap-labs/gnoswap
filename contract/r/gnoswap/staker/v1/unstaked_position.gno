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

// unsettledIncentiveCountOf returns how many checkpoints of poolPath still owe an incentive.
func (s *stakerV1) unsettledIncentiveCountOf(poolPath string) int64 {
	return s.store.GetUnsettledIncentiveCounts()[poolPath]
}

// addUnsettledIncentiveCount moves poolPath's count by delta, dropping the entry at zero.
func (s *stakerV1) addUnsettledIncentiveCount(_ int, rlm realm, poolPath string, delta int64) {
	next := gnsmath.SafeAddInt64(s.unsettledIncentiveCountOf(poolPath), delta)
	if next < 0 {
		panic(makeErrorWithDetails(
			errCalculationError,
			ufmt.Sprintf("unsettled incentive count of pool(%s) went negative", poolPath),
		))
	}

	var err error
	if next == 0 {
		err = s.store.RemoveUnsettledIncentiveCountItem(0, rlm, poolPath)
	} else {
		err = s.store.SetUnsettledIncentiveCountItem(0, rlm, poolPath, next)
	}

	if err != nil {
		panic(err)
	}
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
		deposit.GetExternalIncentiveIdList(),
	)

	s.getUnstakedPositions().set(positionId, position)

	if position.HasPendingIncentives() {
		s.addUnsettledIncentiveCount(0, rlm, poolPath, 1)
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
