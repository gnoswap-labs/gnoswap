// Simplified test implementation for router contract upgrade testing
package test

import (
	"gno.land/r/gnoswap/router"
)

func init() {
	router.RegisterInitializer(cross, func(store router.IRouterStore) router.IRouter {
		return &TestRouter{}
	})
}

// TestRouter is a minimal test implementation that panics on all methods
type TestRouter struct{}

func (t *TestRouter) ExactInSwapRoute(inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string) {
	panic("test implementation: ExactInSwapRoute not supported")
}

func (t *TestRouter) ExactInSingleSwapRoute(inputToken string, outputToken string, amountIn string, routeArr string, amountOutMin string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	panic("test implementation: ExactInSingleSwapRoute not supported")
}

func (t *TestRouter) ExactOutSwapRoute(inputToken string, outputToken string, amountOut string, routeArr string, quoteArr string, amountInMax string, deadline int64, referrer string) (string, string) {
	panic("test implementation: ExactOutSwapRoute not supported")
}

func (t *TestRouter) ExactOutSingleSwapRoute(inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	panic("test implementation: ExactOutSingleSwapRoute not supported")
}

func (t *TestRouter) DrySwapRoute(inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit string) (string, string, bool) {
	panic("test implementation: DrySwapRoute not supported")
}

func (t *TestRouter) SwapCallback(token0Path string, token1Path string, amount0Delta string, amount1Delta string, payer address) error {
	panic("test implementation: SwapCallback not supported")
}

func (t *TestRouter) GetSwapFee() uint64 {
	panic("test implementation: GetSwapFee not supported")
}

func (t *TestRouter) SetSwapFee(fee uint64) {
	panic("test implementation: SetSwapFee not supported")
}
