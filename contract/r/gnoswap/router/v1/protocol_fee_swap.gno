package v1

import (
	"chain"
	"chain/runtime"

	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

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
func (r *routerV1) SetSwapFee(fee uint64) {
	halt.AssertIsNotHaltedRouter()
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	// max swap fee is 1000 (bps)
	if fee > 1000 {
		panic(ufmt.Errorf(
			"%s: fee must be in range 0 to 1000 (10%). got %d",
			errInvalidSwapFee.Error(), fee,
		))
	}

	prevSwapFee := r.store.GetSwapFee()
	if err := r.store.SetSwapFee(fee); err != nil {
		panic(err)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"SetSwapFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"newFee", formatUint(fee),
		"prevFee", formatUint(prevSwapFee),
	)
}

// handleSwapFee deducts the protocol fee from the swap amount and transfers it to the protocol fee contract.
func (r *routerV1) handleSwapFee(
	outputToken string,
	amount int64,
) int64 {
	r.tryCollectPendingProtocolFees()

	swapFee := r.store.GetSwapFee()
	if swapFee <= 0 {
		return amount
	}

	currentTokenPath := outputToken

	feeAmountInt64 := calculateRouterFee(amount, swapFee)
	r.addPendingProtocolFee(currentTokenPath, feeAmountInt64)
	r.tryCollectPendingProtocolFees()

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"SwapRouteFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"tokenPath", currentTokenPath,
		"amount", formatInt64(feeAmountInt64),
	)

	return safeSubInt64(amount, feeAmountInt64)
}

func (r *routerV1) addPendingProtocolFee(tokenPath string, amount int64) {
	if amount <= 0 {
		return
	}

	pendingProtocolFees := clonePendingProtocolFees(r.store.GetPendingProtocolFees())
	pendingProtocolFees[tokenPath] = safeAddInt64(pendingProtocolFees[tokenPath], amount)
	if err := r.store.SetPendingProtocolFees(pendingProtocolFees); err != nil {
		panic(err)
	}
}

func (r *routerV1) tryCollectPendingProtocolFees() {
	pendingProtocolFees := clonePendingProtocolFees(r.store.GetPendingProtocolFees())
	if len(pendingProtocolFees) == 0 || halt.IsHaltedProtocolFee() {
		return
	}

	protocolFeeAddr := access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	for tokenPath, amount := range pendingProtocolFees {
		if amount <= 0 {
			delete(pendingProtocolFees, tokenPath)
			continue
		}

		common.SafeGRC20Approve(cross, tokenPath, protocolFeeAddr, amount)
		if err := pf.AddToProtocolFee(cross, tokenPath, amount); err != nil {
			return
		}
		delete(pendingProtocolFees, tokenPath)
	}

	if err := r.store.SetPendingProtocolFees(pendingProtocolFees); err != nil {
		panic(err)
	}
}

func clonePendingProtocolFees(src map[string]int64) map[string]int64 {
	clone := make(map[string]int64, len(src))
	for key, value := range src {
		clone[key] = value
	}
	return clone
}

func calculateRouterFee(amount int64, swapFee uint64) int64 {
	if swapFee <= 0 {
		return 0
	}

	feeAmount := u256.MulDiv(u256.NewUintFromInt64(amount), u256.NewUint(swapFee), u256.NewUint(10000))
	return safeConvertToInt64(feeAmount)
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

		return safeConvertToInt64(poolAmount)
	}

	return amount
}
