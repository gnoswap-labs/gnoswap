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

	// Outside accumulations of the two boundary ticks at exitTime, as decimal strings. Entries
	// before exitTime can no longer change, but the one at exitTime can be overwritten by a tick
	// cross later in the same block, so it is pinned rather than read back.
	lowerOutsideAcc string
	upperOutsideAcc string

	tier      uint64
	tierRatio uint64
	tierCount uint64

	// unstakingFee is the staking-reward fee rate in force at exitTime. The window closed under
	// it, so a later rate change must not apply retroactively at collect time.
	unstakingFee uint64

	emissionCollected   bool
	pendingIncentiveIds map[string]bool
}

// NewUnstakedPosition creates an exit checkpoint owing every reward source of the deposit.
//
// Parameters:
//   - deposit: Deposit state captured when the position leaves the pool.
//   - exitTime: Unix timestamp when staking ended and this checkpoint's reward window stopped.
//   - exitTick: Pool tick observed at exitTime for reconstructing in-range rewards.
//   - lowerTick: Snapshot of the position's lower boundary tick, retained if the live pool prunes it.
//   - upperTick: Snapshot of the position's upper boundary tick, retained if the live pool prunes it.
//   - lowerOutsideAcc: Decimal-encoded outside reward-ratio accumulation of the lower tick at exitTime.
//   - upperOutsideAcc: Decimal-encoded outside reward-ratio accumulation of the upper tick at exitTime.
//   - tier: Pool emission tier at exitTime; zero denotes that the pool was not tiered.
//   - tierRatio: Tier reward-share ratio, in its stored scaled form, at exitTime.
//   - tierCount: Number of pools sharing the tier at exitTime for dividing tier rewards.
//   - unstakingFee: Staking-reward fee rate in basis points at exitTime (0-1,000; 100 = 1%).
//   - pendingIncentiveIds: External incentive IDs whose rewards are still owed by the position.
//
// Returns:
//   - position: New exit checkpoint retaining the deposit and exit-time reward context; emission is initially uncollected and every supplied incentive is pending.
func NewUnstakedPosition(
	deposit *Deposit,
	exitTime int64,
	exitTick int32,
	lowerTick *Tick,
	upperTick *Tick,
	lowerOutsideAcc string,
	upperOutsideAcc string,
	tier uint64,
	tierRatio uint64,
	tierCount uint64,
	unstakingFee uint64,
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
		lowerOutsideAcc:     lowerOutsideAcc,
		upperOutsideAcc:     upperOutsideAcc,
		tier:                tier,
		tierRatio:           tierRatio,
		tierCount:           tierCount,
		unstakingFee:        unstakingFee,
		pendingIncentiveIds: pending,
	}
}

// Deposit returns the deposit snapshot captured when this position was unstaked.
//
// Returns:
//   - deposit: Stored deposit state, including its owner, pool, liquidity, ticks, warmups, and collected reward fields.
func (u *UnstakedPosition) Deposit() *Deposit { return u.deposit }

// ExitTime returns the timestamp at which the position stopped accruing rewards.
//
// Returns:
//   - exitTime: Unix timestamp pinned as the end of this position's reward-accrual window.
func (u *UnstakedPosition) ExitTime() int64 { return u.exitTime }

// ExitTick returns the pool tick observed at ExitTime.
//
// Returns:
//   - exitTick: Tick value used to determine the position's in-range status at the exit checkpoint.
func (u *UnstakedPosition) ExitTick() int32 { return u.exitTick }

// LowerTick returns the position's lower boundary tick snapshot.
//
// Returns:
//   - lowerTick: Stored lower boundary tick used when calculating rewards for this exit checkpoint.
func (u *UnstakedPosition) LowerTick() *Tick { return u.lowerTick }

// UpperTick returns the position's upper boundary tick snapshot.
//
// Returns:
//   - upperTick: Stored upper boundary tick used when calculating rewards for this exit checkpoint.
func (u *UnstakedPosition) UpperTick() *Tick { return u.upperTick }

// LowerOutsideAcc returns the lower boundary tick's outside accumulation at ExitTime.
//
// Returns:
//   - lowerOutsideAcc: Decimal-encoded reward-ratio accumulation outside the lower boundary at exit.
func (u *UnstakedPosition) LowerOutsideAcc() string { return u.lowerOutsideAcc }

// UpperOutsideAcc returns the upper boundary tick's outside accumulation at ExitTime.
//
// Returns:
//   - upperOutsideAcc: Decimal-encoded reward-ratio accumulation outside the upper boundary at exit.
func (u *UnstakedPosition) UpperOutsideAcc() string { return u.upperOutsideAcc }

// Tier returns the pool's emission tier at ExitTime, or 0 when it was not tiered.
//
// Returns:
//   - tier: Tier identifier pinned at exit; zero means no emission tier applied.
func (u *UnstakedPosition) Tier() uint64 { return u.tier }

// TierRatio returns the tier's emission ratio at ExitTime.
//
// Returns:
//   - tierRatio: Stored scaled reward-share ratio for the pinned tier at exit.
func (u *UnstakedPosition) TierRatio() uint64 { return u.tierRatio }

// TierCount returns how many pools shared the tier at ExitTime.
//
// Returns:
//   - tierCount: Number of pools in the pinned tier when the position exited.
func (u *UnstakedPosition) TierCount() uint64 { return u.tierCount }

// UnstakingFee returns the staking-reward fee rate in force at ExitTime.
//
// Returns:
//   - unstakingFee: Fee rate pinned for this exit in basis points (0-1,000; 100 = 1%).
func (u *UnstakedPosition) UnstakingFee() uint64 { return u.unstakingFee }

// EmissionCollected reports whether the emission reward has been collected.
//
// Returns:
//   - collected: True after MarkEmissionCollected has been called; false while the internal reward remains pending.
func (u *UnstakedPosition) EmissionCollected() bool { return u.emissionCollected }

// MarkEmissionCollected records that the emission reward has been collected.
func (u *UnstakedPosition) MarkEmissionCollected() { u.emissionCollected = true }

// HasPendingIncentiveId reports whether the incentive is still to be collected.
//
// Parameters:
//   - incentiveId: External incentive identifier to look up in this checkpoint's pending set.
//
// Returns:
//   - pending: True when incentiveId is currently pending; false when it is absent or the pending set is nil.
func (u *UnstakedPosition) HasPendingIncentiveId(incentiveId string) bool {
	if u.pendingIncentiveIds == nil {
		return false
	}

	return u.pendingIncentiveIds[incentiveId]
}

// PendingIncentiveIdList returns the incentives still to be collected.
//
// Returns:
//   - incentiveIds: IDs currently present in the pending set; iteration order is unspecified.
func (u *UnstakedPosition) PendingIncentiveIdList() []string {
	incentiveIds := make([]string, 0, len(u.pendingIncentiveIds))
	for incentiveId := range u.pendingIncentiveIds {
		incentiveIds = append(incentiveIds, incentiveId)
	}

	return incentiveIds
}

// PendingIncentiveCount returns how many incentives are still to be collected.
//
// Returns:
//   - count: Number of external incentive IDs currently pending in the checkpoint.
func (u *UnstakedPosition) PendingIncentiveCount() int {
	return len(u.pendingIncentiveIds)
}

// HasPendingIncentives reports whether any incentive is still to be collected.
//
// Returns:
//   - pending: True when at least one external incentive ID remains pending; false otherwise.
func (u *UnstakedPosition) HasPendingIncentives() bool {
	return len(u.pendingIncentiveIds) > 0
}

// MarkIncentiveCollected records that the incentive has been collected.
//
// Parameters:
//   - incentiveId: External incentive identifier to remove from the pending set.
func (u *UnstakedPosition) MarkIncentiveCollected(incentiveId string) {
	if u.pendingIncentiveIds == nil {
		return
	}

	delete(u.pendingIncentiveIds, incentiveId)
}

// FullyCollected reports whether every reward source has been collected.
//
// Returns:
//   - collected: True only when the internal emission flag is set and no external incentive IDs remain pending.
func (u *UnstakedPosition) FullyCollected() bool {
	return u.emissionCollected && !u.HasPendingIncentives()
}
