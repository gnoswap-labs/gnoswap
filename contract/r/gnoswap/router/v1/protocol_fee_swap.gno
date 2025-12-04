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

const (
	maxSwapFeeBPS = uint64(1000) // 10%
)

var (
	fullBPS = u256.NewUint(10000)
)

// GetSwapFee returns the current swap fee rate in basis points.
func (r *routerV1) GetSwapFee() uint64 {
	return r.store.GetSwapFee()
}

// SetSwapFee sets the swap fee rate in basis points.
// Only admin or governance can call this function.
func (r *routerV1) SetSwapFee(fee uint64) {
	halt.AssertIsNotHaltedRouter()
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	if fee > maxSwapFeeBPS {
		panic(ufmt.Errorf(
			"%s: fee must be in range 0 to %d. got %d",
			errInvalidSwapFee.Error(), maxSwapFeeBPS, fee,
		))
	}

	prevSwapFee := r.store.GetSwapFee()
	if err := r.setSwapFee(fee); err != nil {
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

// setSwapFee validates and updates the swap fee rate.
func (r *routerV1) setSwapFee(fee uint64) error {
	// 10000 (bps) = 100%
	if fee > 10000 {
		return ufmt.Errorf(
			"%s: fee must be in range 0 to 10000. got %d",
			errInvalidSwapFee.Error(), fee,
		)
	}

	return r.store.SetSwapFee(fee)
}

// handleSwapFee deducts the protocol fee from the swap amount and transfers it to the protocol fee contract.
func (r *routerV1) handleSwapFee(
	outputToken string,
	amount *u256.Uint,
) *u256.Uint {
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

	toUserAfterProtocol, underflow := u256.Zero().SubOverflow(
		amount,
		u256.NewUintFromInt64(feeAmountInt64),
	)
	if underflow {
		panic(errProtocolFeeOverflow)
	}

	return toUserAfterProtocol
}

func calculateRouterFee(amount *u256.Uint, swapFee uint64) int64 {
	if swapFee <= 0 {
		return 0
	}

	feeAmount := u256.MulDiv(amount, u256.NewUint(swapFee), fullBPS)
	return safeConvertToInt64(feeAmount)
}

// calculate amount to fetch from pool including router fee
// poolAmount = userAmount / (1 - feeRate)
// = userAmount * 10000 / (10000 - swapFeeBPS)
func calculateExactOutWithRouterFee(amount *u256.Uint, swapFee uint64) *u256.Uint {
	userAmount := amount.Clone()

	if swapFee > 0 {
		// Use MulDiv to prevent overflow and maintain precision
		return u256.MulDiv(
			userAmount,
			fullBPS,
			u256.NewUint(10000-swapFee),
		)
	}

	return userAmount
}
