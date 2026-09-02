package router

import (
	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/access"
)

// singleSwap executes a swap within a single pool using the provided parameters.
// It processes a token swap within two assets using a specific fee tier and
// automatically sets the recipient to the caller's address.
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

// singleDrySwap simulates a single-token swap operation without executing it.
func (r *routerV1) singleDrySwap(p *SingleSwapParams) (int64, int64) {
	assertSingleSwap(p)

	return r.swapDryInner(
		p.amountSpecified,
		u256.Zero(),
		newDrySwapCallbackData(p),
	)
}
