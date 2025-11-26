package v1

import (
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
//
// Parameters follow the Uniswap V3 convention:
//   - Positive delta: tokens the pool must receive (input token)
//   - Negative delta: tokens the pool has sent (output token)
func (r *routerV1) SwapCallback(
	token0Path, token1Path string,
	amount0Delta, amount1Delta int64,
	payer address,
) error {
	var tokenToPay string
	var amountToPay int64

	// amount0Delta > 0 means pool wants token0
	// amount1Delta > 0 means pool wants token1
	if amount0Delta > 0 {
		amountToPay = amount0Delta
		tokenToPay = token0Path
	} else if amount1Delta > 0 {
		amountToPay = amount1Delta
		tokenToPay = token1Path
	} else {
		return nil
	}

	// Transfer tokens from router to pool
	// The router should already have the tokens from the user
	r.transferToPool(tokenToPay, u256.NewUintFromInt64(amountToPay), payer)

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
