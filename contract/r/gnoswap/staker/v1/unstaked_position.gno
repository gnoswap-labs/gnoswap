package staker

import (
	"time"

	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/p/gnoswap/gnsmath"
	"gno.land/p/gnoswap/utils"

	sr "gno.land/r/gnoswap/staker"
)

// exitPin overrides the pool reads a checkpoint collect would otherwise take from live state:
// CurrentTick at and after time, GetOrNewTick for the boundary ticks, and the tier context of
// the internal reward-rate schedule.
type exitPin struct {
	time      int64
	tick      int32
	lowerTick *sr.Tick
	upperTick *sr.Tick
	tier      uint64
	tierRatio uint64
	tierCount uint64
}

func newExitPin(position *sr.UnstakedPosition) *exitPin {
	return &exitPin{
		time:      position.ExitTime(),
		tick:      position.ExitTick(),
		lowerTick: position.LowerTick(),
		upperTick: position.UpperTick(),
		tier:      position.Tier(),
		tierRatio: position.TierRatio(),
		tierCount: position.TierCount(),
	}
}

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

	position := sr.NewUnstakedPosition(
		deposit,
		exitTime,
		poolResolver.CurrentTick(exitTime),
		poolResolver.GetOrNewTick(deposit.TickLower()),
		poolResolver.GetOrNewTick(deposit.TickUpper()),
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

// dropUnstakedPositionIfCollected releases the pool's incentive hold once the last incentive
// is collected, and removes the checkpoint once every source is.
func (s *stakerV1) dropUnstakedPositionIfCollected(_ int, rlm realm, positionId uint64, position *sr.UnstakedPosition, hadPendingIncentives bool) {
	if hadPendingIncentives && !position.HasPendingIncentives() {
		s.addUnsettledIncentiveCount(0, rlm, position.Deposit().TargetPoolPath(), -1)
	}

	if position.FullyCollected() {
		s.getUnstakedPositions().remove(positionId)
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

// persistDeposit writes the deposit back, unless it belongs to a checkpoint and is not there.
func (self *collectContext) persistDeposit(s *stakerV1) {
	if self.checkpoint != nil {
		return
	}

	s.getDeposits().set(self.positionId, self.deposit)
}

// markEmissionCollected records the emission collect on the checkpoint.
func (s *stakerV1) markEmissionCollected(_ int, rlm realm, target *collectTarget) {
	if !target.isCheckpoint() {
		return
	}

	hadPendingIncentives := target.checkpoint.HasPendingIncentives()
	target.checkpoint.MarkEmissionCollected()
	s.dropUnstakedPositionIfCollected(0, rlm, target.positionId, target.checkpoint, hadPendingIncentives)
}

// markIncentiveCollected records the incentive collect on the checkpoint. An incentive that
// could not be funded stays pending, the same way it stays collectible while staked; delivery
// reports that as an empty reward token against a non-zero amount.
func (s *stakerV1) markIncentiveCollected(_ int, rlm realm, target *collectTarget, incentiveId string, rewardAmount int64, rewardToken string) {
	if !target.isCheckpoint() {
		return
	}

	if rewardToken == "" && rewardAmount > 0 {
		return
	}

	hadPendingIncentives := target.checkpoint.HasPendingIncentives()
	target.checkpoint.MarkIncentiveCollected(incentiveId)
	s.dropUnstakedPositionIfCollected(0, rlm, target.positionId, target.checkpoint, hadPendingIncentives)
}

// collectTarget is the record a collect runs against: the live deposit while staked, or the
// exit checkpoint an unstake left behind.
type collectTarget struct {
	positionId uint64
	deposit    *sr.Deposit
	// currentTime is now while staked, and the exit time for a checkpoint.
	currentTime int64
	exit        *exitPin
	checkpoint  *sr.UnstakedPosition
}

// checkpointDeposit returns the deposit to calculate against when it is not in the tree.
func (self *collectTarget) checkpointDeposit() *sr.Deposit {
	if self.checkpoint == nil {
		return nil
	}

	return self.deposit
}

// isCheckpoint reports whether the collect runs against an exit checkpoint.
func (self *collectTarget) isCheckpoint() bool {
	return self.checkpoint != nil
}

// resolveCollectTarget resolves what a collect runs against and asserts the caller may.
func (s *stakerV1) resolveCollectTarget(positionId uint64, caller address) *collectTarget {
	position := s.getUnstakedPositions().get(positionId)
	if position == nil {
		assertIsDepositor(s, caller, positionId)

		return &collectTarget{
			positionId:  positionId,
			deposit:     s.getDeposits().get(positionId),
			currentTime: time.Now().Unix(),
		}
	}

	// A checkpoint collect is permissionless: it can only ever deliver to the position's owner,
	// and an open entry point is what lets anyone clear the checkpoints that hold up
	// EndExternalIncentive on the pool.
	return &collectTarget{
		positionId:  positionId,
		deposit:     position.Deposit(),
		currentTime: position.ExitTime(),
		exit:        newExitPin(position),
		checkpoint:  position,
	}
}
