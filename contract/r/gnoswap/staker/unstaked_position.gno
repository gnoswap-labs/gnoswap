package staker

// UnstakedPosition is the exit checkpoint of a position that left the pool before collecting.
//
// It pins the pool state a later collect must reproduce the exit-time reward from: the tick
// observed at the exit, the two boundary ticks (which the unstake may prune from the pool),
// and the tier context (which a later tier change would otherwise re-rate the window with).
// Collection is per source, so the checkpoint tracks what is left and is dropped when nothing is.
type UnstakedPosition struct {
	deposit   *Deposit
	exitTime  int64
	exitTick  int32
	lowerTick *Tick
	upperTick *Tick

	tier      uint64
	tierRatio uint64
	tierCount uint64

	emissionCollected   bool
	pendingIncentiveIds map[string]bool
}

// NewUnstakedPosition creates an exit checkpoint owing every reward source of the deposit.
func NewUnstakedPosition(
	deposit *Deposit,
	exitTime int64,
	exitTick int32,
	lowerTick *Tick,
	upperTick *Tick,
	tier uint64,
	tierRatio uint64,
	tierCount uint64,
	pendingIncentiveIds []string,
) *UnstakedPosition {
	// Allocated here so this realm owns it; a map built by the caller is readonly tainted.
	pending := make(map[string]bool)
	for _, incentiveId := range pendingIncentiveIds {
		pending[incentiveId] = true
	}

	return &UnstakedPosition{
		deposit:             deposit,
		exitTime:            exitTime,
		exitTick:            exitTick,
		lowerTick:           lowerTick,
		upperTick:           upperTick,
		tier:                tier,
		tierRatio:           tierRatio,
		tierCount:           tierCount,
		pendingIncentiveIds: pending,
	}
}

// Deposit returns the deposit as it stood when the position was unstaked.
func (u *UnstakedPosition) Deposit() *Deposit { return u.deposit }

// ExitTime returns the timestamp at which the position stopped accruing rewards.
func (u *UnstakedPosition) ExitTime() int64 { return u.exitTime }

// ExitTick returns the pool tick observed at ExitTime.
func (u *UnstakedPosition) ExitTick() int32 { return u.exitTick }

// LowerTick returns the position's lower boundary tick.
func (u *UnstakedPosition) LowerTick() *Tick { return u.lowerTick }

// UpperTick returns the position's upper boundary tick.
func (u *UnstakedPosition) UpperTick() *Tick { return u.upperTick }

// Tier returns the pool's emission tier at ExitTime, or 0 when it was not tiered.
func (u *UnstakedPosition) Tier() uint64 { return u.tier }

// TierRatio returns the tier's emission ratio at ExitTime.
func (u *UnstakedPosition) TierRatio() uint64 { return u.tierRatio }

// TierCount returns how many pools shared the tier at ExitTime.
func (u *UnstakedPosition) TierCount() uint64 { return u.tierCount }

// EmissionCollected reports whether the emission reward has been collected.
func (u *UnstakedPosition) EmissionCollected() bool { return u.emissionCollected }

// MarkEmissionCollected records that the emission reward has been collected.
func (u *UnstakedPosition) MarkEmissionCollected() { u.emissionCollected = true }

// HasPendingIncentiveId reports whether the incentive is still to be collected.
func (u *UnstakedPosition) HasPendingIncentiveId(incentiveId string) bool {
	if u.pendingIncentiveIds == nil {
		return false
	}

	return u.pendingIncentiveIds[incentiveId]
}

// HasPendingIncentives reports whether any incentive is still to be collected.
func (u *UnstakedPosition) HasPendingIncentives() bool {
	return len(u.pendingIncentiveIds) > 0
}

// PendingIncentiveIdList returns the incentives still to be collected.
func (u *UnstakedPosition) PendingIncentiveIdList() []string {
	incentiveIds := make([]string, 0, len(u.pendingIncentiveIds))
	for incentiveId := range u.pendingIncentiveIds {
		incentiveIds = append(incentiveIds, incentiveId)
	}

	return incentiveIds
}

// MarkIncentiveCollected records that the incentive has been collected.
func (u *UnstakedPosition) MarkIncentiveCollected(incentiveId string) {
	if u.pendingIncentiveIds == nil {
		return
	}

	delete(u.pendingIncentiveIds, incentiveId)
}

// FullyCollected reports whether every reward source has been collected.
func (u *UnstakedPosition) FullyCollected() bool {
	return u.emissionCollected && !u.HasPendingIncentives()
}
