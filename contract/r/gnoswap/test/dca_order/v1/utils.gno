package dca_order

import (
	"gno.land/p/gnoswap/gnsmath/v1"
	u256 "gno.land/p/gnoswap/uint256/v1"
	"gno.land/p/gnoswap/utils/v1"
	ufmt "gno.land/p/nt/ufmt/v0"

	dca "gno.land/r/gnoswap/test/dca_order"
)

// makeGroupID builds the group key: poolPath:direction:interval, where
// direction is 1 for zeroForOne and 0 otherwise.
func makeGroupID(poolPath string, zeroForOne bool, interval int64) string {
	direction := "0"
	if zeroForOne {
		direction = "1"
	}

	return poolPath + ":" + direction + ":" + utils.FormatInt(interval)
}

func orderKey(orderID uint64) string {
	return utils.EncodeUint64(orderID)
}

// ownerOrderKey sorts an owner's orders by ID under a shared prefix.
func ownerOrderKey(owner address, orderID uint64) string {
	return ownerOrderPrefix(owner) + utils.EncodeUint64(orderID)
}

func ownerOrderPrefix(owner address) string {
	return owner.String() + "/"
}

// prefixEnd is an exclusive upper bound for keys made of prefix plus an
// 8-byte encoded ID: nine 0xff bytes sort after every 8-byte suffix.
func prefixEnd(prefix string) string {
	return prefix + "\xff\xff\xff\xff\xff\xff\xff\xff\xff"
}

func isAllowedInterval(interval int64) bool {
	for _, allowed := range allowedIntervals {
		if allowed == interval {
			return true
		}
	}

	return false
}

// nextExecutionAfter returns the first scheduled slot strictly after now.
// Rounds keep a fixed cadence anchored at the first slot; a late execution
// skips missed slots instead of running them back to back.
func nextExecutionAfter(scheduledAt int64, now int64, interval int64) int64 {
	if now < scheduledAt {
		return scheduledAt + interval
	}

	missed := (now - scheduledAt) / interval

	return scheduledAt + (missed+1)*interval
}

// owedOutputU256 returns rate * (endAcc - debt) / 2^128, rounded down.
func owedOutputU256(rate int64, endAccX128 *u256.Uint, debtX128 *u256.Uint) *u256.Uint {
	if endAccX128.Lt(debtX128) {
		panic(makeErrorWithDetails(errInvalidState, "accumulator moved backwards"))
	}

	delta := u256.Zero().Sub(endAccX128, debtX128)
	if delta.IsZero() || rate == 0 {
		return u256.Zero()
	}

	return u256.MulDiv(delta, u256.NewUint(uint64(rate)), q128)
}

// owedOutput is owedOutputU256 for amounts known to fit int64.
func owedOutput(rate int64, endAccX128 *u256.Uint, debtX128 *u256.Uint) int64 {
	return gnsmath.SafeConvertToInt64(owedOutputU256(rate, endAccX128, debtX128))
}

// settleable returns the payout for one transfer (at most MaxInt64), the debt
// to store after paying it, and whether the order is fully settled up to
// endAcc. A larger balance is paid over several claims: the debt advances by
// ceil(payout * 2^128 / rate), so rounding never pays out more than accrued.
func settleable(rate int64, endAccX128 *u256.Uint, debtX128 *u256.Uint) (int64, *u256.Uint, bool) {
	owed := owedOutputU256(rate, endAccX128, debtX128)
	if owed.Lte(maxInt64U256) {
		return int64(owed.Uint64()), endAccX128, true
	}

	debtDelta := u256.MulDivRoundingUp(maxInt64U256, q128, u256.NewUint(uint64(rate)))
	newDebt, overflow := u256.Zero().AddOverflow(debtX128, debtDelta)
	// debt <= endAcc and endAcc is overflow-checked, so clamping covers both
	// a wrapped sum and a delta that rounds past endAcc.
	if overflow || newDebt.Gt(endAccX128) {
		newDebt = endAccX128
	}

	return int64(maxInt64U256.Uint64()), newDebt, false
}

// scheduleKey orders groups by next execution time, then ID.
func scheduleKey(group *dca.Group) string {
	return utils.EncodeUint64(uint64(group.NextExecutionAt())) + group.ID()
}

// reschedule sets a group's rate and next execution time and keeps the
// schedule index in sync with one tree lookup: only groups with a positive
// rate are indexed, keyed by (nextExecutionAt, groupID).
func (d *dcaOrderV1) reschedule(group *dca.Group, rate int64, next int64) {
	if rate < 0 {
		panic(makeErrorWithDetails(errInvalidState, ufmt.Sprintf("negative rate for group %s", group.ID())))
	}

	schedule := d.store.GetScheduledGroups()
	if group.Rate() > 0 {
		schedule.Remove(scheduleKey(group))
	}

	group.SetRate(rate)
	group.SetNextExecutionAt(next)

	if rate > 0 {
		schedule.Set(scheduleKey(group), group.ID())
	}
}

// assertNotExecuting rejects re-entry from the swap path into any
// state-changing entry point. The flag lives in the proxy store, which
// UpgradeImpl also checks.
func (d *dcaOrderV1) assertNotExecuting() {
	if d.store.IsExecuting() {
		panic(makeErrorWithDetails(errReentrant, "group execution in progress"))
	}
}

func (d *dcaOrderV1) lockExecution(_ int, rlm realm) {
	mustStore(d.store.SetExecuting(0, rlm, true))
}

func (d *dcaOrderV1) unlockExecution(_ int, rlm realm) {
	mustStore(d.store.SetExecuting(0, rlm, false))
}

func mustStore(err error) {
	if err != nil {
		panic(err)
	}
}

func (d *dcaOrderV1) getOrder(orderID uint64) *dca.Order {
	value := d.store.GetOrders().Get(orderKey(orderID))
	if value == nil {
		return nil
	}

	return value.(*dca.Order)
}

func (d *dcaOrderV1) mustGetOrder(orderID uint64) *dca.Order {
	order := d.getOrder(orderID)
	if order == nil {
		panic(makeErrorWithDetails(errOrderNotFound, ufmt.Sprintf("orderId(%d)", orderID)))
	}

	return order
}

func (d *dcaOrderV1) getGroup(groupID string) *dca.Group {
	value := d.store.GetGroups().Get(groupID)
	if value == nil {
		return nil
	}

	return value.(*dca.Group)
}

func (d *dcaOrderV1) mustGetGroup(groupID string) *dca.Group {
	group := d.getGroup(groupID)
	if group == nil {
		panic(makeErrorWithDetails(errGroupNotFound, ufmt.Sprintf("groupId(%s)", groupID)))
	}

	return group
}

func (d *dcaOrderV1) pendingFee(tokenPath string) int64 {
	value := d.store.GetPendingFees().Get(tokenPath)
	if value == nil {
		return 0
	}

	return value.(int64)
}

// settlementAcc returns the accumulator an order settles against and whether
// all of its rounds have executed.
func settlementAcc(order *dca.Order, group *dca.Group) (*u256.Uint, bool) {
	if group.Round() < order.EndRound() {
		return group.AccX128(), false
	}

	mark := group.GetRoundMark(order.EndRound())
	if mark == nil || !mark.IsExecuted() {
		panic(makeErrorWithDetails(errInvalidState, ufmt.Sprintf("missing snapshot for round %d", order.EndRound())))
	}

	return mark.AccX128(), true
}

// executedRounds returns how many rounds the order took part in. A cancelled
// order stops counting at its cancellation round.
func executedRounds(order *dca.Order, group *dca.Group) uint64 {
	round := group.Round()
	if order.Status() == dca.OrderStatusCancelled && order.CancelRound() < round {
		round = order.CancelRound()
	}

	if round > order.EndRound() {
		round = order.EndRound()
	}

	if round < order.StartRound() {
		return 0
	}

	return round - order.StartRound()
}

// releaseRoundMark drops one order reference from its end-round mark.
func releaseRoundMark(group *dca.Group, round uint64) {
	mark := group.GetRoundMark(round)
	if mark == nil {
		panic(makeErrorWithDetails(errInvalidState, ufmt.Sprintf("missing mark for round %d", round)))
	}

	refCount := mark.RefCount() - 1
	if refCount < 0 {
		panic(makeErrorWithDetails(errInvalidState, ufmt.Sprintf("negative refCount for round %d", round)))
	}

	if refCount > 0 {
		mark.SetRefCount(refCount)
		return
	}

	if !mark.IsExecuted() && mark.EndingRate() != 0 {
		panic(makeErrorWithDetails(errInvalidState, ufmt.Sprintf("unexecuted mark %d still has ending rate", round)))
	}

	group.RemoveRoundMark(round)
}
