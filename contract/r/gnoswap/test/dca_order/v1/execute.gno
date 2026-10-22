package dca_order

import (
	"time"

	"gno.land/p/gnoswap/gnsmath/v1"
	prbac "gno.land/p/gnoswap/rbac/v1"
	u256 "gno.land/p/gnoswap/uint256/v1"
	"gno.land/p/gnoswap/utils/v1"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/common"
	dca "gno.land/r/gnoswap/test/dca_order"
	"gno.land/r/gnoswap/halt/v1"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/router"
)

// ExecuteGroup sells one round of a group through the router and credits the
// output to the group accumulator. It is permissionless; the schedule and the
// swap result are validated on-chain, and a failing swap reverts so the round
// can be retried.
//
// Checks-effects-interactions: the round, schedule, and next rate are
// persisted before the router call, and an execution lock rejects re-entry
// into any state-changing entry point while the swap runs. Only the
// accumulator, which depends on the swap output, is written afterwards.
func (d *dcaOrderV1) ExecuteGroup(_ int, rlm realm, groupID string, expectedAmountIn int64, amountOutMin int64) (int64, int64) {
	access.AssertIsRlmCurrent(0, rlm)
	common.AssertIsNotHandleNativeCoin()
	halt.AssertIsNotHaltedRouter()
	halt.AssertIsNotHaltedPool()
	// While withdrawals are halted owners cannot cancel, so do not keep
	// selling their escrow either.
	halt.AssertIsNotHaltedWithdraw()
	d.assertNotExecuting()

	if amountOutMin < 0 || expectedAmountIn < 0 {
		panic(makeErrorWithDetails(
			errInvalidAmount,
			ufmt.Sprintf("expectedAmountIn(%d) amountOutMin(%d)", expectedAmountIn, amountOutMin),
		))
	}

	prev := rlm.Previous()
	group := d.mustGetGroup(groupID)
	now := time.Now().Unix()

	amountIn := group.Rate()
	if amountIn <= 0 {
		panic(makeErrorWithDetails(errGroupNotExecutable, ufmt.Sprintf("groupId(%s) has no active rate", groupID)))
	}

	// Schedule first: a round already run by someone else must report
	// "not executable", not "rate changed".
	scheduledAt := group.NextExecutionAt()
	if now < scheduledAt {
		panic(makeErrorWithDetails(
			errGroupNotExecutable,
			ufmt.Sprintf("groupId(%s) next execution at %d, now %d", groupID, scheduledAt, now),
		))
	}

	// Orders may join or leave between the executor's quote and inclusion.
	// Keep the quoted minimum price by scaling the floor to the actual input
	// (rounded up) instead of reverting the round.
	if amountOutMin > 0 && expectedAmountIn > 0 && expectedAmountIn != amountIn {
		amountOutMin = gnsmath.SafeConvertToInt64(u256.MulDivRoundingUp(
			u256.NewUint(uint64(amountOutMin)),
			u256.NewUint(uint64(amountIn)),
			u256.NewUint(uint64(expectedAmountIn)),
		))
	}

	// Effects that do not depend on the swap result.
	round := group.Round() + 1
	group.SetRound(round)
	group.SetLastExecutedAt(now)

	// Orders whose last round is this one stop selling from the next round.
	mark := group.GetRoundMark(round)
	endedRate := int64(0)
	if mark != nil {
		endedRate = mark.EndingRate()
	}

	// Move the group to its next slot with the ending rate removed; a group
	// with no orders left drops out of the schedule index.
	d.reschedule(group, gnsmath.SafeSubInt64(amountIn, endedRate), nextExecutionAfter(scheduledAt, now, group.Interval()))

	d.lockExecution(0, rlm)
	amountOut := swapExactIn(0, rlm, group, amountIn, amountOutMin, now)
	d.unlockExecution(0, rlm)

	accDelta := u256.MulDiv(u256.NewUint(uint64(amountOut)), q128, u256.NewUint(uint64(amountIn)))
	newAcc, overflow := u256.Zero().AddOverflow(group.AccX128(), accDelta)
	if overflow {
		panic(makeErrorWithDetails(errOverflow, "accumulator overflow"))
	}

	group.SetAccX128(newAcc)
	if mark != nil {
		mark.SnapshotAccX128(newAcc)
	}

	// Lifetime statistics use 256-bit counters so they can never block execution.
	group.SetTotalAmountIn(u256.Zero().Add(group.TotalAmountIn(), u256.NewUint(uint64(amountIn))))
	group.SetTotalAmountOut(u256.Zero().Add(group.TotalAmountOut(), u256.NewUint(uint64(amountOut))))

	emitGroupExecuted(prev.Address(), prev.PkgPath(), group, scheduledAt, amountIn, amountOut, endedRate)

	return amountIn, amountOut
}

// swapExactIn sells amountIn of the group's input through the router's
// single-hop route on the group's pool and returns the output received.
// It verifies the realm's balance deltas against the router result.
func swapExactIn(_ int, rlm realm, group *dca.Group, amountIn int64, amountOutMin int64, now int64) int64 {
	self := rlm.Address()
	tokenIn := group.TokenIn()
	tokenOut := group.TokenOut()

	fee, err := pool.GetFee(group.PoolPath())
	if err != nil {
		panic(makeErrorWithDetails(errInvalidPool, err.Error()))
	}
	route := tokenIn + ":" + tokenOut + ":" + utils.FormatUint(uint64(fee))

	routerAddr := access.MustGetAddress(prbac.ROLE_ROUTER.String())

	inBefore := common.BalanceOf(tokenIn, self)
	outBefore := common.BalanceOf(tokenOut, self)

	common.SafeGRC20Approve(0, rlm, tokenIn, routerAddr, amountIn)

	resultIn, resultOut := router.ExactInSingleSwapRoute(
		cross(rlm),
		tokenIn,
		tokenOut,
		utils.FormatInt(amountIn),
		route,
		utils.FormatInt(amountOutMin), // enforced by the router after its fee
		"0",                           // no price limit: the router then requires the full input to be consumed
		now,
		"",
	)

	// Never leave a standing router allowance on escrowed funds.
	common.SafeGRC20Approve(0, rlm, tokenIn, routerAddr, 0)

	spent := inBefore - common.BalanceOf(tokenIn, self)
	received := common.BalanceOf(tokenOut, self) - outBefore

	if spent != amountIn || utils.SafeParseInt64(resultIn) != amountIn {
		panic(makeErrorWithDetails(
			errSwapMismatch,
			ufmt.Sprintf("input spent(%d) router(%s) expected(%d)", spent, resultIn, amountIn),
		))
	}

	if received < 0 || utils.SafeParseInt64(resultOut) != received {
		panic(makeErrorWithDetails(
			errSwapMismatch,
			ufmt.Sprintf("output received(%d) router(%s)", received, resultOut),
		))
	}

	return received
}
