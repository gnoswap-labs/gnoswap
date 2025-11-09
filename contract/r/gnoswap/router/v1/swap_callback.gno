package v1

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/common"
)

// swapCallback implements the pool's SwapCallback interface.
// This is called by the pool after it has sent output tokens to the recipient.
// The router must transfer the required input tokens to the pool.
//
// This callback pattern enables:
// 1. Flash swaps (receive tokens before paying)
// 2. Just-in-time token transfers
// 3. Complex multi-hop swaps without intermediate transfers
func (r *routerV1) SwapCallback(
	token0Path, token1Path string,
	amount0Delta, amount1Delta string,
	payer address,
) error {
	var tokenToPay string

	amountToPay := i256.Zero()

	amount0DeltaI256 := i256.MustFromDecimal(amount0Delta)
	amount1DeltaI256 := i256.MustFromDecimal(amount1Delta)

	// amount0Delta > 0 means pool wants token0
	// amount1Delta > 0 means pool wants token1
	if amount0DeltaI256.Gt(i256.Zero()) {
		amountToPay = amount0DeltaI256
		tokenToPay = token0Path
		// Token0 is needed - this will be determined from context
	} else if amount1DeltaI256.Gt(i256.Zero()) {
		amountToPay = amount1DeltaI256
		tokenToPay = token1Path
	} else {
		return nil
	}

	// Transfer tokens from router to pool
	// The router should already have the tokens from the user
	r.transferToPool(tokenToPay, amountToPay.Abs(), payer)

	return nil
}

// transferToPool transfers tokens from router to pool
func (r *routerV1) transferToPool(token string, amount *u256.Uint, payer address) {
	isTransferByRouter := payer == routerAddr

	balance := common.BalanceOf(token, payer)

	if u256.NewUintFromInt64(balance).Lt(amount) {
		panic("insufficient balance in router for callback")
	}

	if isTransferByRouter {
		common.SafeGRC20Transfer(cross, token, poolAddr, amount.Int64())
	} else {
		common.SafeGRC20TransferFrom(cross, token, payer, poolAddr, amount.Int64())
	}
}
