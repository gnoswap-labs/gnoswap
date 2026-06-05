// Simplified test implementation for router contract upgrade testing
package mock

import (
	router "gno.land/r/gnoswap/router"
	v1 "gno.land/r/gnoswap/router/v1"
)

func NewMockRouter(store router.IRouterStore) *TestRouter {
	instance := v1.NewRouterV1(store)

	return &TestRouter{
		instance: instance,
		mockFns:  make(map[string]func(args ...any) any),
	}
}

func init(cur realm) {
	router.RegisterInitializer(cross(cur), func(_ int, rlm realm, store router.IRouterStore) router.IRouter {
		return NewMockRouter(store)
	})
}

// TestRouter is a minimal test implementation that delegates to v1
type TestRouter struct {
	instance router.IRouter
	mockFns  map[string]func(args ...any) any
}

func (t *TestRouter) GetInstance() router.IRouter {
	return t.instance
}

func (t *TestRouter) SetMockFn(fnName string, fn func(args ...any) any) {
	t.mockFns[fnName] = fn
}

func (t *TestRouter) ExecuteFn(fnName string, actualFn func(args ...any) any, args ...any) any {
	fn, ok := t.mockFns[fnName]
	if !ok {
		return actualFn(args...)
	}

	return fn(args...)
}

func (t *TestRouter) ExactInSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string) {
	result := t.ExecuteFn(
		"ExactInSwapRoute",
		func(args ...any) any {
			r1, r2 := t.instance.ExactInSwapRoute(0, rlm, args[0].(string), args[1].(string), args[2].(string), args[3].(string), args[4].(string), args[5].(string), args[6].(int64), args[7].(string))
			return []any{r1, r2}
		},
		inputToken, outputToken, amountIn, routeArr, quoteArr, amountOutMin, deadline, referrer,
	).([]any)
	return result[0].(string), result[1].(string)
}

func (t *TestRouter) ExactInSingleSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountIn string, routeArr string, amountOutMin string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	result := t.ExecuteFn(
		"ExactInSingleSwapRoute",
		func(args ...any) any {
			r1, r2 := t.instance.ExactInSingleSwapRoute(0, rlm, args[0].(string), args[1].(string), args[2].(string), args[3].(string), args[4].(string), args[5].(string), args[6].(int64), args[7].(string))
			return []any{r1, r2}
		},
		inputToken, outputToken, amountIn, routeArr, amountOutMin, sqrtPriceLimitX96, deadline, referrer,
	).([]any)
	return result[0].(string), result[1].(string)
}

func (t *TestRouter) ExactOutSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountOut string, routeArr string, quoteArr string, amountInMax string, deadline int64, referrer string) (string, string) {
	result := t.ExecuteFn(
		"ExactOutSwapRoute",
		func(args ...any) any {
			r1, r2 := t.instance.ExactOutSwapRoute(0, rlm, args[0].(string), args[1].(string), args[2].(string), args[3].(string), args[4].(string), args[5].(string), args[6].(int64), args[7].(string))
			return []any{r1, r2}
		},
		inputToken, outputToken, amountOut, routeArr, quoteArr, amountInMax, deadline, referrer,
	).([]any)
	return result[0].(string), result[1].(string)
}

func (t *TestRouter) ExactOutSingleSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	result := t.ExecuteFn(
		"ExactOutSingleSwapRoute",
		func(args ...any) any {
			r1, r2 := t.instance.ExactOutSingleSwapRoute(0, rlm, args[0].(string), args[1].(string), args[2].(string), args[3].(string), args[4].(string), args[5].(string), args[6].(int64), args[7].(string))
			return []any{r1, r2}
		},
		inputToken, outputToken, amountOut, routeArr, amountInMax, sqrtPriceLimitX96, deadline, referrer,
	).([]any)
	return result[0].(string), result[1].(string)
}

func (t *TestRouter) DrySwapRoute(_ int, rlm realm, inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit string) (string, string, bool) {
	result := t.ExecuteFn(
		"DrySwapRoute",
		func(args ...any) any {
			r1, r2, r3 := t.instance.DrySwapRoute(0, rlm, args[0].(string), args[1].(string), args[2].(string), args[3].(string), args[4].(string), args[5].(string), args[6].(string))
			return []any{r1, r2, r3}
		},
		inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit,
	).([]any)
	return result[0].(string), result[1].(string), result[2].(bool)
}

func (t *TestRouter) SwapCallback(_ int, rlm realm, token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, payer address) error {
	result := t.ExecuteFn(
		"SwapCallback",
		func(args ...any) any {
			return t.instance.SwapCallback(0, rlm, args[0].(string), args[1].(string), args[2].(int64), args[3].(int64), args[4].(address))
		},
		token0Path, token1Path, amount0Delta, amount1Delta, payer,
	)
	if result == nil {
		return nil
	}
	return result.(error)
}

func (t *TestRouter) GetSwapFee() uint64 {
	return t.ExecuteFn(
		"GetSwapFee",
		func(args ...any) any { return t.instance.GetSwapFee() },
	).(uint64)
}

func (t *TestRouter) SetSwapFee(_ int, rlm realm, fee uint64) {
	t.ExecuteFn(
		"SetSwapFee",
		func(args ...any) any { t.instance.SetSwapFee(0, rlm, args[0].(uint64)); return nil },
		fee,
	)
}
