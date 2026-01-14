package v3

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/common"
)

var zero = u256.Zero()

// SwapExecutor defines the interface for executing swaps.
type SwapExecutor interface {
	// execute performs the swap operation.
	execute(p *SingleSwapParams) (int64, int64)
}

// executeSwap is the common logic for both real and dry swaps.
func (r *routerV1) executeSwap(executor SwapExecutor, p *SingleSwapParams) (int64, int64) {
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
func (r *routerV1) singleSwap(p *SingleSwapParams) (int64, int64) {
	return r.executeSwap(&RealSwapExecutor{router: r}, p)
}

// singleDrySwap simulates a single-token swap operation without executing it.
// It performs a dry run simulation and does not alter the state.
func (r *routerV1) singleDrySwap(p *SingleSwapParams) (int64, int64) {
	return r.executeSwap(&DrySwapExecutor{router: r}, p)
}
