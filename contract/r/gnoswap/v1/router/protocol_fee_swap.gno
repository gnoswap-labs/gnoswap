package router

import (
	"std"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	pf "gno.land/r/gnoswap/v1/protocol_fee"
)

const (
	defaultSwapFeeBPS = uint64(15) // 0.15%
)

var swapFee = defaultSwapFeeBPS

// GetSwapFee returns current rate of swap fee
// ref: https://docs.gnoswap.io/contracts/router/protocol_fee_swap.gno#getswapfee
func GetSwapFee() uint64 {
	return swapFee
}

// SetSwapFee modifies the swap fee
// Only governance contract can execute this function via proposal
// ref: https://docs.gnoswap.io/contracts/router/protocol_fee_swap.gno#setswapfee
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

// handleSwapFee deducts the protocol fee from the amount and sends it to the protocol_fee contract
// and returns the amount after deducting the protocol fee
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
		common.Transfer(cross, outputToken, protocolFeeAddr, feeAmountInt64)
	} else {
		common.TransferFrom(cross, outputToken, poolAddr, protocolFeeAddr, feeAmountInt64)
	}

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
		toUserAfterProtocol = u256.Zero()
	}
	
	return toUserAfterProtocol
}
