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

func init() {
	router.RegisterInitializer(cross, func(store router.IRouterStore) router.IRouter {
		return NewV3ValidRouter(store)
	})
}

// TestRouter is a minimal test implementation that delegates to v1
type TestRouter struct {
	instance router.IRouter
}

func (t *TestRouter) ExactInSwapRoute(inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string) {
	return t.instance.ExactInSwapRoute(inputToken, outputToken, amountIn, routeArr, quoteArr, amountOutMin, deadline, referrer)
}

func (t *TestRouter) ExactInSingleSwapRoute(inputToken string, outputToken string, amountIn string, routeArr string, amountOutMin string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	return t.instance.ExactInSingleSwapRoute(inputToken, outputToken, amountIn, routeArr, amountOutMin, sqrtPriceLimitX96, deadline, referrer)
}

func (t *TestRouter) ExactOutSwapRoute(inputToken string, outputToken string, amountOut string, routeArr string, quoteArr string, amountInMax string, deadline int64, referrer string) (string, string) {
	return t.instance.ExactOutSwapRoute(inputToken, outputToken, amountOut, routeArr, quoteArr, amountInMax, deadline, referrer)
}

func (t *TestRouter) ExactOutSingleSwapRoute(inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	return t.instance.ExactOutSingleSwapRoute(inputToken, outputToken, amountOut, routeArr, amountInMax, sqrtPriceLimitX96, deadline, referrer)
}

func (t *TestRouter) DrySwapRoute(inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit string) (string, string, bool) {
	return t.instance.DrySwapRoute(inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit)
}

func (t *TestRouter) SwapCallback(token0Path string, token1Path string, amount0Delta string, amount1Delta string, payer address) error {
	return t.instance.SwapCallback(token0Path, token1Path, amount0Delta, amount1Delta, payer)
}

func (t *TestRouter) GetSwapFee() uint64 {
	return t.instance.GetSwapFee()
}

func (t *TestRouter) SetSwapFee(fee uint64) {
	t.instance.SetSwapFee(fee)
}
