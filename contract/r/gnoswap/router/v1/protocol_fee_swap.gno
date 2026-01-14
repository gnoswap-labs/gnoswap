package v1

import (
	"chain"
	"chain/runtime"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"

	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

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
	swapFee := r.store.GetSwapFee()
	if swapFee <= 0 {
		return amount
	}

	currentTokenPath := outputToken

	if common.IsGNOTNativePath(outputToken) {
		currentTokenPath = wugnotPath
	}

	feeAmountInt64 := calculateRouterFee(amount, swapFee)

	common.SafeGRC20Transfer(cross, currentTokenPath, protocolFeeAddr, feeAmountInt64)

	pf.AddToProtocolFee(cross, currentTokenPath, feeAmountInt64)

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

// BUG(invalid-v2): This version doubles the swap fee, causing users to pay 2x fee
func calculateRouterFee(amount int64, swapFee uint64) int64 {
	if swapFee <= 0 {
		return 0
	}

	// BUG: doubles the swap fee
	buggySwapFee := swapFee * 2

	feeAmount := u256.MulDiv(u256.NewUintFromInt64(amount), u256.NewUint(buggySwapFee), u256.NewUint(10000))
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
