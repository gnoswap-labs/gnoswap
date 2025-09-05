package router

import (
	"std"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	pf "gno.land/r/gnoswap/v1/protocol_fee"
)

const (
	defaultSwapFeeBPS = uint64(15) // 0.15%
)

// swapFee is the fee charged on each swap transaction.
// This parameter can be modified through governance.
var swapFee = defaultSwapFeeBPS

// GetSwapFee returns the current swap fee rate in basis points.
func GetSwapFee() uint64 {
	return swapFee
}

// SetSwapFee sets the swap fee rate in basis points.
// Only admin or governance can call this function.
func SetSwapFee(cur realm, fee uint64) {
	halt.AssertIsNotHaltedRouter()
	halt.AssertIsNotHaltedProtocolFee()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	prevSwapFee := swapFee
	if err := setSwapFee(fee); err != nil {
		panic(err)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetSwapFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"newFee", formatUint(fee),
		"prevFee", formatUint(prevSwapFee),
	)
}

// setSwapFee validates and updates the swap fee rate.
func setSwapFee(fee uint64) error {
	// 10000 (bps) = 100%
	if fee > 10000 {
		return ufmt.Errorf(
			"%s: fee must be in range 0 to 10000. got %d",
			errInvalidSwapFee.Error(), fee,
		)
	}

	swapFee = fee
	return nil
}

// handleSwapFee deducts the protocol fee from the swap amount and transfers it to the protocol fee contract.
func handleSwapFee(
	outputToken string,
	amount *u256.Uint,
) *u256.Uint {
	if swapFee <= 0 {
		return amount
	}

	feeAmount := u256.Zero().Mul(amount, u256.NewUint(swapFee))
	feeAmount = u256.Zero().Div(feeAmount, u256.NewUint(10000))
	feeAmountInt64 := safeConvertToInt64(feeAmount)

	if outputToken == gnot {
		outputToken = wugnotPath
	}

	common.Transfer(cross, outputToken, protocolFeeAddr, feeAmountInt64)

	pf.AddToProtocolFee(cross, outputToken, feeAmountInt64)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SwapRouteFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"tokenPath", outputToken,
		"amount", formatInt64(feeAmountInt64),
	)

	toUserAfterProtocol, underflow := u256.Zero().SubOverflow(amount, feeAmount)
	if underflow {
		panic(errProtocolFeeOverflow)
	}

	return toUserAfterProtocol
}
