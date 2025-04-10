package router

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/common"
)

var zero = u256.Zero()

// SwapExecutor defines the interface for executing swaps
type SwapExecutor interface {
	execute(params SingleSwapParams) (amountIn, amountOut *u256.Uint)
}

// executeSwap is the common logic for both real and dry swaps
func executeSwap(executor SwapExecutor, params SingleSwapParams) (amountIn *u256.Uint, amountOut *u256.Uint) {
	if params.tokenIn == params.tokenOut {
		panic(errSameTokenSwap.Error())
	}

	common.MustRegistered(params.tokenIn, params.tokenOut)

	return executor.execute(params)
}

var (
	_ SwapExecutor = (*RealSwapExecutor)(nil)
	_ SwapExecutor = (*DrySwapExecutor)(nil)
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
func singleSwap(params SingleSwapParams) (amountIn *u256.Uint, amountOut *u256.Uint) {
	return executeSwap(&RealSwapExecutor{}, params)
}

// singleDrySwap simulates a single-token swap operation without executing it,
// returning the calculated input and output token amounts.
//
// Parameters:
// - params: A `SingleSwapParams` structure containing the following fields:
//   - `tokenIn`: The address of the input token.
//   - `tokenOut`: The address of the output token.
//   - `amountSpecified`: The amount specified for the swap (input or output amount depending on the swap direction).
//   - `fee`: The fee rate applied to the swap.
//
// Returns:
// - *u256.Uint: The calculated amount of the input token required for the swap (`amountIn`).
// - *u256.Uint: The calculated amount of the output token received from the swap (`amountOut`).
//
// Notes:
// - This function performs a simulation and does not alter the state or execute the actual swap.
func singleDrySwap(params SingleSwapParams) (amountIn *u256.Uint, amountOut *u256.Uint) {
	return executeSwap(&DrySwapExecutor{}, params)
}
