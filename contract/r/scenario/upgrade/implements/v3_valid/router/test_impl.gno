// Simplified test implementation for router contract upgrade testing
package v3_valid

import (
	"gno.land/r/gnoswap/router"
	v1 "gno.land/r/gnoswap/router/v1"
)

func NewV3ValidRouter(store router.IRouterStore) router.IRouter {
	return &TestRouter{
		instance: v1.NewRouterV1(store),
	}
}

func init(cur realm) {
	router.RegisterInitializer(cross(cur), func(_ int, rlm realm, store router.IRouterStore) router.IRouter {
		return NewV3ValidRouter(store)
	})
}

// TestRouter is a minimal test implementation that delegates to v1
type TestRouter struct {
	instance router.IRouter
}

func (t *TestRouter) ExactInSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string) {
	return t.instance.ExactInSwapRoute(0, rlm, inputToken, outputToken, amountIn, routeArr, quoteArr, amountOutMin, deadline, referrer)
}

func (t *TestRouter) ExactInSingleSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountIn string, routeArr string, amountOutMin string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	return t.instance.ExactInSingleSwapRoute(0, rlm, inputToken, outputToken, amountIn, routeArr, amountOutMin, sqrtPriceLimitX96, deadline, referrer)
}

func (t *TestRouter) ExactOutSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountOut string, routeArr string, quoteArr string, amountInMax string, deadline int64, referrer string) (string, string) {
	return t.instance.ExactOutSwapRoute(0, rlm, inputToken, outputToken, amountOut, routeArr, quoteArr, amountInMax, deadline, referrer)
}

func (t *TestRouter) ExactOutSingleSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	return t.instance.ExactOutSingleSwapRoute(0, rlm, inputToken, outputToken, amountOut, routeArr, amountInMax, sqrtPriceLimitX96, deadline, referrer)
}

func (t *TestRouter) DrySwapRoute(_ int, rlm realm, inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit string) (string, string, bool) {
	return t.instance.DrySwapRoute(0, rlm, inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit)
}

func (t *TestRouter) SwapCallback(_ int, rlm realm, token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, payer address) error {
	return t.instance.SwapCallback(0, rlm, token0Path, token1Path, amount0Delta, amount1Delta, payer)
}

func (t *TestRouter) GetSwapFee() uint64 {
	return t.instance.GetSwapFee()
}

func (t *TestRouter) SetSwapFee(_ int, rlm realm, fee uint64) {
	t.instance.SetSwapFee(0, rlm, fee)
}
