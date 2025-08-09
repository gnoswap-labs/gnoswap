package router

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/common"
)

var zero = u256.Zero()

// SwapExecutor defines the interface for executing swaps.
type SwapExecutor interface {
	// execute performs the swap operation.
	execute(p *SingleSwapParams) (amountIn, amountOut *u256.Uint)
}

// executeSwap is the common logic for both real and dry swaps.
func executeSwap(executor SwapExecutor, p *SingleSwapParams) (amountIn, amountOut *u256.Uint) {
	if p.tokenIn == p.tokenOut {
		panic(errSameTokenSwap)
	}

	common.MustRegistered(p.tokenIn, p.tokenOut)

	return executor.execute(p)
}

var (
	_ SwapExecutor = (*RealSwapExecutor)(nil)
	_ SwapExecutor = (*DrySwapExecutor)(nil)
)

// singleSwap executes a swap within a single pool using the provided parameters.
// It processes a token swap within two assets using a specific fee tier and
// automatically sets the recipient to the caller's address.
func singleSwap(p *SingleSwapParams) (amountIn, amountOut *u256.Uint) {
	return executeSwap(&RealSwapExecutor{}, p)
}

// singleDrySwap simulates a single-token swap operation without executing it.
// It performs a dry run simulation and does not alter the state.
func singleDrySwap(p *SingleSwapParams) (amountIn, amountOut *u256.Uint) {
	return executeSwap(&DrySwapExecutor{}, p)
}
