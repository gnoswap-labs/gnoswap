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
// Rounding favours the collector: the fee is truncated. The two results always
// sum back to amount, so a caller that debits amount and pays out
// amountAfterFee never leaves the pool short.
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
func (i *poolV1) GetPendingProtocolFees() map[string]int64 {
	return i.store.GetPendingProtocolFees()
}

func (i *poolV1) addPendingProtocolFee(_ int, rlm realm, tokenPath string, amount int64) {
	if amount <= 0 {
		return
	}

	// The stored map is readonly tainted here, so it is copied before being updated.
	existingProtocolFees := i.store.GetPendingProtocolFees()
	pendingProtocolFees := make(map[string]int64)
	for pendingTokenPath, pendingAmount := range existingProtocolFees {
		pendingProtocolFees[pendingTokenPath] = pendingAmount
	}

	pendingProtocolFees[tokenPath] = gnsmath.SafeAddInt64(pendingProtocolFees[tokenPath], amount)
	if err := i.store.SetPendingProtocolFees(0, rlm, pendingProtocolFees); err != nil {
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
func (i *poolV1) settleProtocolFee(_ int, rlm realm, tokenPath string, amount int64) {
	if halt.IsHaltedProtocolFee() {
		i.addPendingProtocolFee(0, rlm, tokenPath, amount)
		return
	}

	pendingProtocolFees := i.store.GetPendingProtocolFees()
	pendingAmount, hasPending := pendingProtocolFees[tokenPath]
	totalAmount := gnsmath.SafeAddInt64(pendingAmount, amount)

	if totalAmount > 0 {
		protocolFeeAddr := access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
		common.SafeGRC20Approve(0, rlm, tokenPath, protocolFeeAddr, totalAmount)

		// AddToProtocolFee only reports an error for a halted realm, which is handled
		// above. The branch keeps the amount pending should that ever change, and
		// withdraws the approval so no unspent allowance outlives the call.
		if err := pf.AddToProtocolFee(cross(rlm), tokenPath, totalAmount); err != nil {
			common.SafeGRC20Approve(cross(rlm), tokenPath, protocolFeeAddr, 0)
			i.addPendingProtocolFee(0, rlm, tokenPath, amount)
			return
		}
	}

	if !hasPending {
		return
	}

	remainingProtocolFees := make(map[string]int64)
	for pendingTokenPath, pending := range pendingProtocolFees {
		if pendingTokenPath == tokenPath {
			continue
		}

		remainingProtocolFees[pendingTokenPath] = pending
	}

	if err := i.store.SetPendingProtocolFees(0, rlm, remainingProtocolFees); err != nil {
		panic(err)
	}
}

// SetPoolCreationFee sets the poolCreationFee.
// Only admin or governance can call this function.
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

// calculateAmountWithFee calculates the fee amount and the amount after the fee
//
// Inputs:
// - amount: the amount before the fee
// - fee: the fee in BPS
//
// Outputs:
// - the fee amount
// - the amount after the fee applied
func calculateAmountWithFee(amount, fee *u256.Uint) (feeAmount, afterAmount *u256.Uint) {
	feeAmount, overflow := u256.Zero().MulOverflow(amount, fee)
	if overflow {
		panic(errors.New(errOverflow))
	}
	feeAmount = u256.Zero().Div(feeAmount, u256.NewUint(10_000))
	afterAmount = u256.Zero().Sub(amount, feeAmount)
	return feeAmount, afterAmount
}

// setPoolCreationFee this function is internal function called by SetPoolCreationFee
// And SetPoolCreationFee
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

// setWithdrawalFee this function is internal function called by SetWithdrawalFee
// function and SetWithdrawalFee function
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
