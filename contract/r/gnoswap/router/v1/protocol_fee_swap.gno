package router

import (
	"chain"

	ufmt "gno.land/p/nt/ufmt/v0"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/gnoswap/utils"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"

	pf "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
)

// GetSwapFee returns the current swap fee rate in basis points.
func (r *routerV1) GetSwapFee() uint64 {
	return r.store.GetSwapFee()
}

// SetSwapFee sets the protocol swap fee rate.
//
// Fee is deducted from swap output and sent to protocol fee contract.
// Only callable by admin or governance.
//
// Parameters:
//   - fee: Fee rate in basis points (0-1000 = 0%-10%)
//
// Access:
//   - Requires: Admin or Governance role
//   - Halt check: Router and ProtocolFee must not be halted
//
// Events:
//   - SetSwapFee: Emits previous and new fee values
//
// Reverts if:
//   - Caller is not admin/governance
//   - Fee > 1000 bps (10%)
//   - Router or ProtocolFee is halted
func (r *routerV1) SetSwapFee(_ int, rlm realm, fee uint64) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedRouter()
	halt.AssertIsNotHaltedProtocolFee()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	// max swap fee is 1000 (bps)
	if fee > 1000 {
		panic(ufmt.Errorf(
			"%s: fee must be in range 0 to 1000 (10%). got %d",
			errInvalidSwapFee, fee,
		))
	}

	prevSwapFee := r.store.GetSwapFee()
	if err := r.store.SetSwapFee(0, rlm, fee); err != nil {
		panic(err)
	}

	chain.Emit(
		"SetSwapFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"newFee", utils.FormatUint(fee),
		"prevFee", utils.FormatUint(prevSwapFee),
	)
}

// handleSwapFee deducts the protocol fee from the swap amount and transfers it to the protocol fee contract.
func (r *routerV1) handleSwapFee(
	_ int,
	rlm realm,
	outputToken string,
	amount int64,
) int64 {
	currentTokenPath := outputToken

	swapFee := r.store.GetSwapFee()
	if swapFee <= 0 {
		r.settleProtocolFee(0, rlm, currentTokenPath, 0)
		return amount
	}

	feeAmountInt64 := calculateRouterFee(amount, swapFee)
	r.settleProtocolFee(0, rlm, currentTokenPath, feeAmountInt64)

	previousRealm := rlm.Previous()
	chain.Emit(
		"SwapRouteFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"tokenPath", currentTokenPath,
		"amount", utils.FormatInt(feeAmountInt64),
	)

	return gnsmath.SafeSubInt64(amount, feeAmountInt64)
}

// GetPendingProtocolFees returns the pending protocol fee amount per token path.
func (r *routerV1) GetPendingProtocolFees() map[string]int64 {
	return r.store.GetPendingProtocolFees()
}

func (r *routerV1) addPendingProtocolFee(_ int, rlm realm, tokenPath string, amount int64) {
	if amount <= 0 {
		return
	}

	// The stored map is readonly tainted here, so it is copied before being updated.
	existingProtocolFees := r.store.GetPendingProtocolFees()
	pendingProtocolFees := make(map[string]int64)
	for pendingTokenPath, pendingAmount := range existingProtocolFees {
		pendingProtocolFees[pendingTokenPath] = pendingAmount
	}
	pendingProtocolFees[tokenPath] = gnsmath.SafeAddInt64(pendingProtocolFees[tokenPath], amount)
	if err := r.store.SetPendingProtocolFees(0, rlm, pendingProtocolFees); err != nil {
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
func (r *routerV1) settleProtocolFee(_ int, rlm realm, tokenPath string, amount int64) {
	if halt.IsHaltedProtocolFee() {
		r.addPendingProtocolFee(0, rlm, tokenPath, amount)
		return
	}

	pendingProtocolFees := r.store.GetPendingProtocolFees()
	pendingAmount, hasPending := pendingProtocolFees[tokenPath]
	totalAmount := gnsmath.SafeAddInt64(pendingAmount, amount)

	if totalAmount > 0 {
		protocolFeeAddr := access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
		common.SafeGRC20Approve(cross(rlm), tokenPath, protocolFeeAddr, totalAmount)

		// AddToProtocolFee only reports an error for a halted realm, which is handled
		// above. The branch keeps the amount pending should that ever change, and
		// withdraws the approval so no unspent allowance outlives the call.
		if err := pf.AddToProtocolFee(cross(rlm), tokenPath, totalAmount); err != nil {
			common.SafeGRC20Approve(cross(rlm), tokenPath, protocolFeeAddr, 0)
			r.addPendingProtocolFee(0, rlm, tokenPath, amount)
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

	if err := r.store.SetPendingProtocolFees(0, rlm, remainingProtocolFees); err != nil {
		panic(err)
	}
}

func calculateRouterFee(amount int64, swapFee uint64) int64 {
	if swapFee <= 0 {
		return 0
	}

	feeAmount := u256.MulDiv(u256.NewUintFromInt64(amount), u256.NewUint(swapFee), u256.NewUint(10000))
	return gnsmath.SafeConvertToInt64(feeAmount)
}

// calculate amount to fetch from pool including router fee
// poolAmount = userAmount / (1 - feeRate)
// = userAmount * 10000 / (10000 - swapFeeBPS)
func calculateExactOutWithRouterFee(amount int64, swapFee uint64) int64 {
	if amount == 0 {
		return amount
	}

	if swapFee > 0 {
		// Use MulDiv to prevent overflow and maintain precision
		poolAmount := u256.MulDiv(
			u256.NewUintFromInt64(amount),
			u256.NewUint(10000),
			u256.NewUint(10000-swapFee),
		)

		return gnsmath.SafeConvertToInt64(poolAmount)
	}

	return amount
}
