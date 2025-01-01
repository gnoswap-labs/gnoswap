package router

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
)

// singleSwap execute a swap within a single pool using the provided parameters.
// It processes a token swap within two assets using a specific fee tier and
// automatically sets the recipient to the caller's address.
//
// Parameters:
//   - params: `SingleSwapParams` containing the swap configuration
//   - tokenIn: Address of the token being spent
//   - tokenOut: Address of the token being received
//   - fee: Fee tier of the pool in basis points
//   - amountSpecified: Amount specified for the swap (positive for exact input, negative for exact output)
//
// Returns:
//   - *u256.Uint: Total amount of input tokens used
//   - *u256.Uint: Total amount of output tokens received
//
// The function uses swapInner for the core swap logic and sets the proce limit to 0,
// allowing the swap to execute at any price point within slippage bounds.
func singleSwap(params SingleSwapParams) (*u256.Uint, *u256.Uint) { // amountIn, amountOut
	amountIn, amountOut := swapInner(
		params.amountSpecified,
		std.PrevRealm().Addr(), // if single swap => user will recieve
		u256.Zero(),            // sqrtPriceLimitX96
		SwapCallbackData{
			params.tokenIn,
			params.tokenOut,
			params.fee,
			std.PrevRealm().Addr(), // payer ==> msg.sender,
		},
	)

	return amountIn, amountOut
}
