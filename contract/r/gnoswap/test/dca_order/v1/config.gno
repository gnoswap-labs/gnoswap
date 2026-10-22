package dca_order

import (
	"gno.land/p/gnoswap/gnsmath/v1"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt/v1"
)

// SetCreationFeeBps sets the fee prepaid at order creation, in bps of the
// order's total input. Admin or governance only.
func (d *dcaOrderV1) SetCreationFeeBps(_ int, rlm realm, feeBps int64) {
	access.AssertIsRlmCurrent(0, rlm)
	common.AssertIsNotHandleNativeCoin()
	d.assertNotExecuting()
	prev := rlm.Previous()
	access.AssertIsAdminOrGovernance(prev.Address())

	if feeBps < 0 || feeBps > maxCreationFeeBps {
		panic(makeErrorWithDetails(errInvalidConfig, ufmt.Sprintf("feeBps(%d) must be in [0, %d]", feeBps, maxCreationFeeBps)))
	}

	config := d.store.GetConfig()
	prevValue := config.CreationFeeBps()
	config.SetCreationFeeBps(feeBps)

	emitConfigUpdated(prev.Address(), prev.PkgPath(), "creationFeeBps", prevValue, feeBps)
}

// SetOrderLimits sets the minimum input per round and the maximum number of
// rounds per order. Existing orders are unaffected. Admin or governance only.
func (d *dcaOrderV1) SetOrderLimits(_ int, rlm realm, minAmountPerExecution int64, maxTotalExecutions int64) {
	access.AssertIsRlmCurrent(0, rlm)
	common.AssertIsNotHandleNativeCoin()
	d.assertNotExecuting()
	prev := rlm.Previous()
	access.AssertIsAdminOrGovernance(prev.Address())

	if minAmountPerExecution <= 0 {
		panic(makeErrorWithDetails(errInvalidConfig, ufmt.Sprintf("minAmountPerExecution(%d) must be positive", minAmountPerExecution)))
	}

	if maxTotalExecutions <= 0 || maxTotalExecutions > hardMaxTotalExecutions {
		panic(makeErrorWithDetails(
			errInvalidConfig,
			ufmt.Sprintf("maxTotalExecutions(%d) must be in [1, %d]", maxTotalExecutions, hardMaxTotalExecutions),
		))
	}

	config := d.store.GetConfig()
	prevMin := config.MinAmountPerExecution()
	prevMax := config.MaxTotalExecutions()
	config.SetMinAmountPerExecution(minAmountPerExecution)
	config.SetMaxTotalExecutions(maxTotalExecutions)

	emitConfigUpdated(prev.Address(), prev.PkgPath(), "minAmountPerExecution", prevMin, minAmountPerExecution)
	emitConfigUpdated(prev.Address(), prev.PkgPath(), "maxTotalExecutions", prevMax, maxTotalExecutions)
}

// WithdrawFee transfers prepaid creation fees to a recipient. Fees are kept
// apart from order escrow, so a withdrawal never touches order funds.
// Admin or governance only.
//
// Fees are not routed through protocol_fee.AddToProtocolFee because that
// entry point only accepts pool, position, router, and staker callers; until
// protocol_fee whitelists this realm, admin/governance withdraws them here.
func (d *dcaOrderV1) WithdrawFee(_ int, rlm realm, tokenPath string, recipient address, amount int64) {
	access.AssertIsRlmCurrent(0, rlm)
	common.AssertIsNotHandleNativeCoin()
	halt.AssertIsNotHaltedWithdraw()
	d.assertNotExecuting()
	prev := rlm.Previous()
	access.AssertIsAdminOrGovernance(prev.Address())

	if !recipient.IsValid() || recipient == rlm.Address() {
		// Sending to this realm would strand the fee outside every ledger.
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("recipient(%s)", recipient.String())))
	}

	if amount <= 0 {
		panic(makeErrorWithDetails(errInvalidAmount, ufmt.Sprintf("amount(%d) must be positive", amount)))
	}

	pending := d.pendingFee(tokenPath)
	if amount > pending {
		panic(makeErrorWithDetails(errInsufficientFee, ufmt.Sprintf("amount(%d) > pending(%d)", amount, pending)))
	}

	remaining := gnsmath.SafeSubInt64(pending, amount)
	fees := d.store.GetPendingFees()
	if remaining == 0 {
		fees.Remove(tokenPath)
	} else {
		fees.Set(tokenPath, remaining)
	}

	common.SafeGRC20Transfer(0, rlm, tokenPath, recipient, amount)

	emitFeeWithdrawn(prev.Address(), prev.PkgPath(), tokenPath, recipient, amount, remaining)
}
