package dca_order

import (
	"chain/runtime"
	"time"

	"gno.land/p/gnoswap/gnsmath/v1"
	u256 "gno.land/p/gnoswap/uint256/v1"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/common"
	dca "gno.land/r/gnoswap/test/dca_order"
	"gno.land/r/gnoswap/halt/v1"
	"gno.land/r/gnoswap/pool"
)

// CreateOrder escrows the order input plus the prepaid creation fee and adds
// the order's per-round amount to its group.
//
// The order joins at the group's current round; it takes part in the next
// totalExecutions rounds and never shares output from earlier rounds.
func (d *dcaOrderV1) CreateOrder(
	_ int,
	rlm realm,
	poolPath string,
	tokenIn string,
	interval int64,
	amountPerExecution int64,
	totalExecutions int64,
	maxFeeBps int64,
) uint64 {
	access.AssertIsRlmCurrent(0, rlm)
	common.AssertIsNotHandleNativeCoin()
	// Do not escrow funds that can neither execute nor be withdrawn.
	halt.AssertIsNotHaltedRouter()
	halt.AssertIsNotHaltedPool()
	halt.AssertIsNotHaltedWithdraw()
	d.assertNotExecuting()

	prev := rlm.Previous()
	caller := prev.Address()
	access.AssertIsValidAddress(caller)

	tokenOut, zeroForOne := validatePoolToken(poolPath, tokenIn)

	if !isAllowedInterval(interval) {
		panic(makeErrorWithDetails(errInvalidInterval, ufmt.Sprintf("interval(%d)", interval)))
	}

	config := d.store.GetConfig()
	if config.CreationFeeBps() > maxFeeBps {
		panic(makeErrorWithDetails(
			errFeeTooHigh,
			ufmt.Sprintf("creationFeeBps(%d) > maxFeeBps(%d)", config.CreationFeeBps(), maxFeeBps),
		))
	}

	if amountPerExecution < config.MinAmountPerExecution() {
		panic(makeErrorWithDetails(
			errInvalidAmount,
			ufmt.Sprintf("amountPerExecution(%d) must be >= %d", amountPerExecution, config.MinAmountPerExecution()),
		))
	}

	if totalExecutions <= 0 || totalExecutions > config.MaxTotalExecutions() {
		panic(makeErrorWithDetails(
			errInvalidExecutions,
			ufmt.Sprintf("totalExecutions(%d) must be in [1, %d]", totalExecutions, config.MaxTotalExecutions()),
		))
	}

	totalAmount := gnsmath.SafeMulInt64(amountPerExecution, totalExecutions)
	// The prepaid fee rounds up in favor of the protocol.
	feeAmount := gnsmath.SafeConvertToInt64(u256.MulDivRoundingUp(
		u256.NewUint(uint64(totalAmount)),
		u256.NewUint(uint64(config.CreationFeeBps())),
		u256.NewUint(uint64(bpsDenominator)),
	))
	depositAmount := gnsmath.SafeAddInt64(totalAmount, feeAmount)

	now := time.Now().Unix()
	groups := d.store.GetGroups()
	groupID := makeGroupID(poolPath, zeroForOne, interval)

	var group *dca.Group
	isNewGroup := false
	if value := groups.Get(groupID); value != nil {
		group = value.(*dca.Group)
	} else {
		// A new group can run its first round immediately.
		group = dca.NewGroup(groupID, poolPath, tokenIn, tokenOut, zeroForOne, interval, now)
		groups.Set(groupID, group)
		isNewGroup = true
	}

	// An idle group has no participants left, so its first new round can run
	// now instead of waiting for a stale or future slot.
	next := group.NextExecutionAt()
	if group.Rate() == 0 {
		next = now
	}

	orderID := d.store.GetNextOrderID()
	mustStore(d.store.SetNextOrderID(0, rlm, orderID+1))

	order := dca.NewOrder(
		orderID,
		caller,
		group,
		amountPerExecution,
		totalExecutions,
		feeAmount,
		now,
		runtime.ChainHeight(),
	)

	mark := group.GetOrCreateRoundMark(order.EndRound())
	mark.SetEndingRate(gnsmath.SafeAddInt64(mark.EndingRate(), amountPerExecution))
	mark.SetRefCount(mark.RefCount() + 1)

	d.reschedule(group, gnsmath.SafeAddInt64(group.Rate(), amountPerExecution), next)
	group.SetActiveOrders(group.ActiveOrders() + 1)

	d.store.GetOrders().Set(orderKey(orderID), order)
	d.store.GetOrdersByOwner().Set(ownerOrderKey(caller, orderID), orderID)

	if feeAmount > 0 {
		fees := d.store.GetPendingFees()
		pending := int64(0)
		if value := fees.Get(tokenIn); value != nil {
			pending = value.(int64)
		}
		fees.Set(tokenIn, gnsmath.SafeAddInt64(pending, feeAmount))
	}

	// Pull funds last: every accounting write above is reverted if it fails.
	common.SafeGRC20TransferFrom(0, rlm, tokenIn, caller, rlm.Address(), depositAmount)

	if isNewGroup {
		emitGroupCreated(caller, prev.PkgPath(), group)
	}
	emitOrderCreated(caller, prev.PkgPath(), order, group, depositAmount)

	return orderID
}

// CancelOrder settles accrued output, refunds the input of unexecuted rounds,
// and closes the order. An order whose rounds already all executed is
// completed instead and refunds nothing.
func (d *dcaOrderV1) CancelOrder(_ int, rlm realm, orderID uint64) (int64, int64) {
	access.AssertIsRlmCurrent(0, rlm)
	common.AssertIsNotHandleNativeCoin()
	halt.AssertIsNotHaltedWithdraw()
	d.assertNotExecuting()

	prev := rlm.Previous()
	caller := prev.Address()

	order := d.mustGetOrder(orderID)
	if order.Owner() != caller {
		panic(makeErrorWithDetails(errNotOrderOwner, ufmt.Sprintf("orderId(%d)", orderID)))
	}

	if !order.IsActive() {
		panic(makeErrorWithDetails(errOrderNotActive, ufmt.Sprintf("orderId(%d) status(%s)", orderID, order.Status())))
	}

	group := d.mustGetGroup(order.GroupID())
	endAcc, finished := settlementAcc(order, group)
	claimed, _, fullySettled := settleable(order.AmountPerExecution(), endAcc, order.AccDebtX128())
	if !fullySettled {
		// Closing the order must pay everything accrued in one transfer.
		panic(makeErrorWithDetails(errClaimFirst, ufmt.Sprintf("orderId(%d)", orderID)))
	}

	refund := int64(0)
	status := dca.OrderStatusCompleted
	if !finished {
		remainingRounds := order.EndRound() - group.Round()
		refund = gnsmath.SafeMulInt64(order.AmountPerExecution(), int64(remainingRounds))
		status = dca.OrderStatusCancelled
		order.SetCancelRound(group.Round())

		d.reschedule(group, gnsmath.SafeSubInt64(group.Rate(), order.AmountPerExecution()), group.NextExecutionAt())

		mark := group.GetRoundMark(order.EndRound())
		if mark == nil {
			panic(makeErrorWithDetails(errInvalidState, ufmt.Sprintf("missing mark for round %d", order.EndRound())))
		}
		mark.SetEndingRate(gnsmath.SafeSubInt64(mark.EndingRate(), order.AmountPerExecution()))
	}

	order.SetAccDebtX128(endAcc)
	order.SetClaimedOut(u256.Zero().Add(order.ClaimedOut(), u256.NewUint(uint64(claimed))))
	order.SetRefundedIn(refund)
	order.SetStatus(status)
	order.SetFinalizedAt(time.Now().Unix())

	releaseRoundMark(group, order.EndRound())
	group.SetActiveOrders(group.ActiveOrders() - 1)

	if claimed > 0 {
		common.SafeGRC20Transfer(0, rlm, group.TokenOut(), order.Owner(), claimed)
	}

	if refund > 0 {
		common.SafeGRC20Transfer(0, rlm, group.TokenIn(), order.Owner(), refund)
	}

	if finished {
		// All rounds already executed: this is a completion, not a cancellation.
		emitOrderClaimed(caller, prev.PkgPath(), order, group, claimed)
	} else {
		emitOrderCancelled(caller, prev.PkgPath(), order, group, claimed)
	}

	return refund, claimed
}

// Claim transfers the order's accrued output to its owner. Anyone may call
// it; once every round has executed the order is marked completed.
func (d *dcaOrderV1) Claim(_ int, rlm realm, orderID uint64) int64 {
	access.AssertIsRlmCurrent(0, rlm)
	common.AssertIsNotHandleNativeCoin()
	halt.AssertIsNotHaltedWithdraw()
	d.assertNotExecuting()

	prev := rlm.Previous()

	order := d.mustGetOrder(orderID)
	if !order.IsActive() {
		panic(makeErrorWithDetails(errOrderNotActive, ufmt.Sprintf("orderId(%d) status(%s)", orderID, order.Status())))
	}

	group := d.mustGetGroup(order.GroupID())
	endAcc, finished := settlementAcc(order, group)
	claimed, newDebt, fullySettled := settleable(order.AmountPerExecution(), endAcc, order.AccDebtX128())

	// Nothing accrued and nothing to finalize: no writes and no event, so a
	// permissionless caller cannot spam the owner's event history.
	if claimed == 0 && !finished {
		return 0
	}

	order.SetAccDebtX128(newDebt)
	order.SetClaimedOut(u256.Zero().Add(order.ClaimedOut(), u256.NewUint(uint64(claimed))))

	// An order completes only once its last round ran and every unit is paid;
	// an output above one transfer is paid over several claims.
	if finished && fullySettled {
		order.SetStatus(dca.OrderStatusCompleted)
		order.SetFinalizedAt(time.Now().Unix())
		releaseRoundMark(group, order.EndRound())
		group.SetActiveOrders(group.ActiveOrders() - 1)
	}

	if claimed > 0 {
		common.SafeGRC20Transfer(0, rlm, group.TokenOut(), order.Owner(), claimed)
	}

	emitOrderClaimed(prev.Address(), prev.PkgPath(), order, group, claimed)

	return claimed
}

// validatePoolToken checks the pool exists and tokenIn belongs to it.
// It returns the output token and whether the order sells token0.
func validatePoolToken(poolPath string, tokenIn string) (string, bool) {
	if !pool.ExistsPoolPath(poolPath) {
		panic(makeErrorWithDetails(errInvalidPool, ufmt.Sprintf("poolPath(%s)", poolPath)))
	}

	token0, err := pool.GetToken0Path(poolPath)
	if err != nil {
		panic(makeErrorWithDetails(errInvalidPool, err.Error()))
	}

	token1, err := pool.GetToken1Path(poolPath)
	if err != nil {
		panic(makeErrorWithDetails(errInvalidPool, err.Error()))
	}

	switch tokenIn {
	case token0:
		return token1, true
	case token1:
		return token0, false
	default:
		panic(makeErrorWithDetails(errInvalidToken, ufmt.Sprintf("tokenIn(%s) not in pool(%s)", tokenIn, poolPath)))
	}
}
