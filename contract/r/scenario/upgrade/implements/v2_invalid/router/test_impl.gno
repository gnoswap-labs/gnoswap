// Simplified test implementation for router contract upgrade testing
package v2_invalid

import (
	router "gno.land/r/gnoswap/router"
	v1 "gno.land/r/gnoswap/router/v1"
)

func NewV2InvalidRouter(store router.IRouterStore) router.IRouter {
	instance := v1.NewRouterV1(store)

	return &TestRouter{
		instance:      instance,
		activeMethods: make(map[string]bool),
	}
}

func init(cur realm) {
	router.RegisterInitializer(cross(cur), func(_ int, rlm realm, store router.IRouterStore) router.IRouter {
		return NewV2InvalidRouter(store)
	})
}

// TestRouter is a minimal test implementation that delegates to v1 only when method is activated
type TestRouter struct {
	instance      router.IRouter
	activeMethods map[string]bool
}

func (t *TestRouter) SetActiveMethod(fnName string, activated bool) {
	t.activeMethods[fnName] = activated
}

func (t *TestRouter) isActive(fnName string) bool {
	active, ok := t.activeMethods[fnName]
	return ok && active
}

func (t *TestRouter) ExactInSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string) {
	if !t.isActive("ExactInSwapRoute") {
		panic("test implementation: ExactInSwapRoute not supported")
	}
	return t.instance.ExactInSwapRoute(0, rlm, inputToken, outputToken, amountIn, routeArr, quoteArr, amountOutMin, deadline, referrer)
}

func (t *TestRouter) ExactInSingleSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountIn string, routeArr string, amountOutMin string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	if !t.isActive("ExactInSingleSwapRoute") {
		panic("test implementation: ExactInSingleSwapRoute not supported")
	}
	return t.instance.ExactInSingleSwapRoute(0, rlm, inputToken, outputToken, amountIn, routeArr, amountOutMin, sqrtPriceLimitX96, deadline, referrer)
}

func (t *TestRouter) ExactOutSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountOut string, routeArr string, quoteArr string, amountInMax string, deadline int64, referrer string) (string, string) {
	if !t.isActive("ExactOutSwapRoute") {
		panic("test implementation: ExactOutSwapRoute not supported")
	}
	return t.instance.ExactOutSwapRoute(0, rlm, inputToken, outputToken, amountOut, routeArr, quoteArr, amountInMax, deadline, referrer)
}

func (t *TestRouter) ExactOutSingleSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	if !t.isActive("ExactOutSingleSwapRoute") {
		panic("test implementation: ExactOutSingleSwapRoute not supported")
	}
	return t.instance.ExactOutSingleSwapRoute(0, rlm, inputToken, outputToken, amountOut, routeArr, amountInMax, sqrtPriceLimitX96, deadline, referrer)
}

func (t *TestRouter) DrySwapRoute(_ int, rlm realm, inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit string) (string, string, bool) {
	if !t.isActive("DrySwapRoute") {
		panic("test implementation: DrySwapRoute not supported")
	}
	return t.instance.DrySwapRoute(0, rlm, inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit)
}

func (t *TestRouter) SwapCallback(_ int, rlm realm, token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, payer address) error {
	if !t.isActive("SwapCallback") {
		panic("test implementation: SwapCallback not supported")
	}
	return t.instance.SwapCallback(0, rlm, token0Path, token1Path, amount0Delta, amount1Delta, payer)
}

func (t *TestRouter) GetSwapFee() uint64 {
	if !t.isActive("GetSwapFee") {
		panic("test implementation: GetSwapFee not supported")
	}
	return t.instance.GetSwapFee()
}

func (t *TestRouter) SetSwapFee(_ int, rlm realm, fee uint64) {
	if !t.isActive("SetSwapFee") {
		panic("test implementation: SetSwapFee not supported")
	}
	t.instance.SetSwapFee(0, rlm, fee)
}
