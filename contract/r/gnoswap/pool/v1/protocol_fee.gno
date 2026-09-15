package pool

import (
	"chain"
	"errors"

	"gno.land/p/gnoswap/gnsmath"
	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/gnoswap/utils"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
	pf "gno.land/r/gnoswap/protocol_fee"
)

const (
	MaxBpsValue = uint64(1000) // 10%
	ZeroBps     = uint64(0)
)

// deductWithdrawalFee splits amount into the fee withheld for the protocol and
// the remainder paid out to the collector.
//
// Parameters:
//   - amount: Amount available for collection, in token base units; non-positive
//     values bypass fee calculation and produce no fee.
//   - withdrawalFeeBPS: Withdrawal fee rate in basis points, applied as
//     amount*withdrawalFeeBPS/10,000 with truncation.
//
// Returns:
//   - feeAmount: Truncated withdrawal fee withheld for the protocol, in token
//     base units.
//   - amountAfterFee: Amount left for the collector after fee deduction, in
//     token base units.
func deductWithdrawalFee(amount int64, withdrawalFeeBPS uint64) (feeAmount, amountAfterFee int64) {
	if amount <= 0 || withdrawalFeeBPS == ZeroBps {
		return 0, amount
	}

	fee, afterFee := calculateAmountWithFee(
		u256.NewUint(uint64(amount)),
		u256.NewUint(withdrawalFeeBPS),
	)

	return gnsmath.SafeConvertToInt64(fee), gnsmath.SafeConvertToInt64(afterFee)
}

// GetPendingProtocolFees returns the pending protocol fee amount per token path.
//
// Returns:
//   - map[string]int64: Pending protocol fee amounts keyed by token contract
//     path, with values in token base units.
func (i *poolV1) GetPendingProtocolFees() map[string]int64 {
	return i.store.GetPendingProtocolFees()
}

// addPendingProtocolFee adds a positive amount to the pending balance for one
// token path when immediate settlement cannot occur.
//
// Parameters:
//   - _: Leading integer discriminator for the forwarded realm call; callers
//     pass 0.
//   - rlm: Propagated realm context used for the pending-balance store write;
//     the store validates that it is current.
//   - tokenPath: Token contract path whose pending protocol fee is increased.
//   - amount: Fee amount to add in token base units; non-positive values are
//     ignored.
func (i *poolV1) addPendingProtocolFee(_ int, rlm realm, tokenPath string, amount int64) {
	if amount <= 0 {
		return
	}

	pendingAmount := gnsmath.SafeAddInt64(i.store.GetPendingProtocolFee(tokenPath), amount)
	if err := i.store.SetPendingProtocolFee(0, rlm, tokenPath, pendingAmount); err != nil {
		panic(err)
	}
}

// settleProtocolFee forwards amount, plus anything already pending for tokenPath, to
// the protocol fee realm. When collection is halted or the transfer fails, the amount
// is recorded as pending instead and settled by a later call for the same token, which
// every fee path makes even when the fee is zero.
//
// Only tokenPath is touched, so an unrelated token can never block settlement. The
// pending entry is written only when the fee cannot be forwarded, so the common path
// performs no store write at all.
// Parameters:
//   - _: Leading integer discriminator for the forwarded realm call; callers
//     pass 0.
//   - rlm: Propagated realm context used for token approval, cross-realm
//     settlement, and pending-balance writes.
//   - tokenPath: Token contract path whose pending amount and protocol fee are
//     settled.
//   - amount: Newly accrued protocol fee in token base units; it is combined
//     with any pending amount for tokenPath.
func (i *poolV1) settleProtocolFee(_ int, rlm realm, tokenPath string, amount int64) {
	if halt.IsHaltedProtocolFee() {
		i.addPendingProtocolFee(0, rlm, tokenPath, amount)
		return
	}

	pendingAmount := i.store.GetPendingProtocolFee(tokenPath)
	totalAmount := gnsmath.SafeAddInt64(pendingAmount, amount)

	if totalAmount > 0 {
		protocolFeeAddr := access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
		common.SafeGRC20Approve(0, rlm, tokenPath, protocolFeeAddr, totalAmount)

		// AddToProtocolFee only reports an error for a halted realm, which is handled
		// above. The branch keeps the amount pending should that ever change, and
		// withdraws the approval so no unspent allowance outlives the call.
		if err := pf.AddToProtocolFee(cross(rlm), tokenPath, totalAmount); err != nil {
			common.SafeGRC20Approve(0, rlm, tokenPath, protocolFeeAddr, 0)
			i.addPendingProtocolFee(0, rlm, tokenPath, amount)
			return
		}
	}

	if err := i.store.RemovePendingProtocolFee(0, rlm, tokenPath); err != nil {
		panic(err)
	}
}

// SetPoolCreationFee sets the poolCreationFee.
// Only admin or governance can call this function.
//
// Parameters:
//   - _: Leading integer discriminator for the forwarded realm call; callers
//     pass 0.
//   - rlm: Propagated realm context validated as current before the fee is
//     written.
//   - fee: New non-negative pool creation fee in configured native-token base
//     units.
func (i *poolV1) SetPoolCreationFee(_ int, rlm realm, fee int64) {
	access.AssertIsRlmCurrent(0, rlm)

	i.assertPoolUnlocked()
	halt.AssertIsNotHaltedPool()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	i.lockPool(0, rlm)
	defer i.unlockPool(0, rlm)

	prevPoolCreationFee := i.store.GetPoolCreationFee()
	err := i.setPoolCreationFee(0, rlm, fee)
	if err != nil {
		panic(err)
	}

	chain.Emit(
		"SetPoolCreationFee",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", utils.FormatInt(prevPoolCreationFee),
		"newFee", utils.FormatInt(fee),
	)
}

// SetWithdrawalFee sets the withdrawal fee.
// Only admin or governance can call this function.
//
// Parameters:
//   - _: Leading integer discriminator for the forwarded realm call; callers
//     pass 0.
//   - rlm: Propagated realm context validated as current before the fee is
//     written.
//   - fee: New withdrawal fee in basis points; the setter accepts 0 through
//     1,000 (10%) inclusive.
func (i *poolV1) SetWithdrawalFee(_ int, rlm realm, fee uint64) {
	access.AssertIsRlmCurrent(0, rlm)

	i.assertPoolUnlocked()
	halt.AssertIsNotHaltedPool()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	i.lockPool(0, rlm)
	defer i.unlockPool(0, rlm)

	prevWithdrawalFee := i.store.GetWithdrawalFeeBPS()

	err := i.setWithdrawalFee(0, rlm, fee)
	if err != nil {
		panic(err)
	}

	chain.Emit(
		"SetWithdrawalFee",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", utils.FormatUint(prevWithdrawalFee),
		"newFee", utils.FormatUint(fee),
	)
}

// calculateAmountWithFee calculates the fee amount and the amount after the fee.
//
// Parameters:
//   - amount: Unsigned amount before the fee is applied, in token base units.
//   - fee: Fee denominator expressed in basis points; the calculation divides
//     amount*fee by 10,000 and truncates the result.
//
// Returns:
//   - feeAmount: Truncated fee amount in the same base units as amount.
//   - afterAmount: amount minus feeAmount, preserving the original units.
func calculateAmountWithFee(amount, fee *u256.Uint) (feeAmount, afterAmount *u256.Uint) {
	feeAmount, overflow := u256.Zero().MulOverflow(amount, fee)
	if overflow {
		panic(errors.New(errOverflow))
	}
	feeAmount = u256.Zero().Div(feeAmount, u256.NewUint(10_000))
	afterAmount = u256.Zero().Sub(amount, feeAmount)
	return feeAmount, afterAmount
}

// setPoolCreationFee validates and stores the pool creation fee for the active
// implementation.
//
// Parameters:
//   - _: Leading integer discriminator for the forwarded realm call; callers
//     pass 0.
//   - rlm: Propagated realm context passed to the store write; the store checks
//     that it is current.
//   - fee: New pool creation fee in native-token base units; negative values are
//     rejected.
//
// Returns:
//   - error: Nil when the fee is stored; non-nil when fee is negative or the
//     underlying store write fails.
func (i *poolV1) setPoolCreationFee(_ int, rlm realm, fee int64) error {
	if fee < 0 {
		return makeErrorWithDetails(
			errInvalidInput,
			"pool creation fee cannot be negative",
		)
	}

	// update pool creation fee
	err := i.store.SetPoolCreationFee(0, rlm, fee)
	if err != nil {
		return err
	}

	return nil
}

// setWithdrawalFee validates and stores the withdrawal fee for the active
// implementation.
//
// Parameters:
//   - _: Leading integer discriminator for the forwarded realm call; callers
//     pass 0.
//   - rlm: Propagated realm context passed to the store write; the store checks
//     that it is current.
//   - fee: New withdrawal fee in basis points; values above 1,000 (10%) are
//     rejected.
//
// Returns:
//   - error: Nil when the fee is stored; non-nil when fee exceeds the allowed
//     maximum or the underlying store write fails.
func (i *poolV1) setWithdrawalFee(_ int, rlm realm, fee uint64) error {
	if fee > MaxBpsValue {
		return makeErrorWithDetails(
			errInvalidWithdrawalFeePct,
			ufmt.Sprintf("fee(%d) must be in range 0 ~ %d", fee, MaxBpsValue),
		)
	}

	err := i.store.SetWithdrawalFeeBPS(0, rlm, fee)
	if err != nil {
		return err
	}

	return nil
}
