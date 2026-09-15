package router

import (
	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/access"
)

// singleSwap executes a swap within a single pool using the provided parameters.
// It processes two assets using one fee tier and sends output to the router recipient.
//
// Parameters:
//   - _: leading call discriminator; callers pass 0
//   - rlm: propagated current realm context used for pool interaction and callback
//   - p: single-pool token, fee, amount, and price-limit parameters
//
// Returns:
//   - amountIn: input amount received by the pool
//   - amountOut: output amount sent by the pool
func (r *routerV1) singleSwap(_ int, rlm realm, p *SingleSwapParams) (int64, int64) {
	assertSingleSwap(p)

	caller := rlm.Previous().Address()
	recipient := access.MustGetAddress(prbac.ROLE_ROUTER.String())

	return r.swapInner(
		0,
		rlm,
		p.amountSpecified,
		recipient,
		p.SqrtPriceLimitX96(),
		newSwapCallbackData(p, caller),
	)
}

// singleDrySwap simulates a single-pool swap without executing transfers or changing state.
//
// Parameters:
//   - p: single-pool token, fee, and signed amount parameters to simulate
//
// Returns:
//   - amountIn: input amount the pool would receive
//   - amountOut: output amount the pool would send
func (r *routerV1) singleDrySwap(p *SingleSwapParams) (int64, int64) {
	assertSingleSwap(p)

	return r.swapDryInner(
		p.amountSpecified,
		u256.Zero(),
		newDrySwapCallbackData(p),
	)
}
