package router

import (
	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/access"
)

// multiSwap performs a multi-hop exact-input swap in forward order.
func (r *routerV1) multiSwap(_ int, rlm realm, sp SwapParams, numPools int, swapPath string) (int64, int64) {
	payer := rlm.Previous().Address()
	routerAddr := access.MustGetAddress(prbac.ROLE_ROUTER.String())
	firstAmountIn := int64(0)

	for currentPoolIndex := 0; ; currentPoolIndex++ {
		callbackData := newSwapCallbackData(sp, payer)
		amountIn, amountOut := r.swapInner(
			0,
			rlm,
			sp.amountSpecified,
			sp.recipient,
			u256.Zero(),
			callbackData,
		)

		if currentPoolIndex == 0 {
			firstAmountIn = amountIn
		}

		if currentPoolIndex+1 >= numPools {
			return firstAmountIn, amountOut
		}

		payer = routerAddr
		nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex+1)
		sp.tokenIn = nextInput
		sp.tokenOut = nextOutput
		sp.fee = nextFee
		sp.amountSpecified = amountOut
	}
}

// multiSwapNegative performs a multi-hop exact-output swap. It first quotes
// every hop backward, then executes the collected swaps forward.
func (r *routerV1) multiSwapNegative(_ int, rlm realm, sp SwapParams, numPools int, swapPath string) (int64, int64) {
	swapInfo := r.collectBackwardDrySwapInfo(rlm.Previous().Address(), sp.SingleSwapParams, numPools, swapPath)
	return r.executeCollectedSwaps(0, rlm, swapInfo, sp.recipient)
}

// multiDrySwap simulates a multi-hop exact-input swap in forward order.
func (r *routerV1) multiDrySwap(payer address, sp SingleSwapParams, numPools int, swapPath string) (int64, int64, error) {
	routerAddr := access.MustGetAddress(prbac.ROLE_ROUTER.String())
	firstAmountIn := int64(0)

	for currentPoolIndex := 0; ; currentPoolIndex++ {
		amountIn, amountOut := r.swapDryInner(
			sp.amountSpecified,
			u256.Zero(),
			newSwapCallbackData(sp, payer),
		)

		if currentPoolIndex == 0 {
			firstAmountIn = amountIn
		}

		if currentPoolIndex+1 >= numPools {
			return firstAmountIn, amountOut, nil
		}

		payer = routerAddr
		nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex+1)
		sp.tokenIn = nextInput
		sp.tokenOut = nextOutput
		sp.fee = nextFee
		sp.amountSpecified = amountOut
	}
}

// multiDrySwapNegative simulates a multi-hop exact-output swap in backward order.
func (r *routerV1) multiDrySwapNegative(sp SingleSwapParams, numPools int, swapPath string) (int64, int64, error) {
	firstAmountIn := int64(0)
	payer := access.MustGetAddress(prbac.ROLE_ROUTER.String())

	for currentPoolIndex := numPools - 1; ; currentPoolIndex-- {
		amountIn, amountOut := r.swapDryInner(
			sp.amountSpecified,
			u256.Zero(),
			newSwapCallbackData(sp, payer),
		)

		if currentPoolIndex == 0 {
			firstAmountIn = amountIn
		}

		if currentPoolIndex == 0 {
			return firstAmountIn, amountOut, nil
		}

		nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex-1)
		sp.amountSpecified = -amountIn
		sp.tokenIn = nextInput
		sp.tokenOut = nextOutput
		sp.fee = nextFee
	}
}

// collectBackwardDrySwapInfo quotes an exact-output route backward before real execution.
func (r *routerV1) collectBackwardDrySwapInfo(payer address, sp SingleSwapParams, numPools int, swapPath string) []SingleSwapParams {
	swapInfo := make([]SingleSwapParams, 0, numPools)

	for currentPoolIndex := numPools - 1; currentPoolIndex >= 0; currentPoolIndex-- {
		amountIn, _ := r.singleDrySwap(payer, &sp)
		swapInfo = append(swapInfo, sp)

		if currentPoolIndex == 0 {
			break
		}

		nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex-1)
		sp.tokenIn = nextInput
		sp.tokenOut = nextOutput
		sp.fee = nextFee
		sp.amountSpecified = -amountIn
	}

	return swapInfo
}

// executeCollectedSwaps executes the backward-quoted exact-output swaps in forward order.
func (r *routerV1) executeCollectedSwaps(_ int, rlm realm, swapInfo []SingleSwapParams, recipient address) (int64, int64) {
	payer := rlm.Previous().Address()
	routerAddr := access.MustGetAddress(prbac.ROLE_ROUTER.String())
	firstAmountIn := int64(0)

	for currentPoolIndex := len(swapInfo) - 1; currentPoolIndex >= 0; currentPoolIndex-- {
		amountIn, amountOut := r.swapInner(
			0,
			rlm,
			swapInfo[currentPoolIndex].amountSpecified,
			recipient,
			u256.Zero(),
			newSwapCallbackData(swapInfo[currentPoolIndex], payer),
		)

		if currentPoolIndex == len(swapInfo)-1 {
			firstAmountIn = amountIn
		}

		if currentPoolIndex == 0 {
			return firstAmountIn, amountOut
		}

		swapInfo[currentPoolIndex-1].amountSpecified = amountOut
		payer = routerAddr
	}

	return firstAmountIn, 0
}
