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

		// every hop of a forward multi-hop swap is exact-in
		assertHopFullyConsumed(currentPoolIndex, sp.amountSpecified, amountIn)

		if currentPoolIndex == 0 {
			firstAmountIn = amountIn
		}

		nextPoolIndex := currentPoolIndex + 1
		if nextPoolIndex >= numPools {
			return firstAmountIn, amountOut
		}

		payer = routerAddr
		nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, nextPoolIndex)
		sp.tokenIn = nextInput
		sp.tokenOut = nextOutput
		sp.fee = nextFee
		sp.amountSpecified = amountOut
	}
}

// multiSwapNegative performs a multi-hop exact-output swap. It first quotes
// every hop backward, then executes the collected swaps forward.
func (r *routerV1) multiSwapNegative(_ int, rlm realm, sp SwapParams, numPools int, swapPath string) (int64, int64) {
	swapInfo := r.collectBackwardDrySwapInfo(sp.SingleSwapParams, numPools, swapPath)
	return r.executeCollectedSwaps(0, rlm, swapInfo, sp.recipient)
}

// multiDrySwap simulates a multi-hop exact-input swap in forward order.
func (r *routerV1) multiDrySwap(sp SingleSwapParams, numPools int, swapPath string) (int64, int64, error) {
	firstAmountIn := int64(0)

	for currentPoolIndex := 0; ; currentPoolIndex++ {
		amountIn, amountOut := r.swapDryInner(
			sp.amountSpecified,
			u256.Zero(),
			newDrySwapCallbackData(sp),
		)

		// mirror the real-swap full-consumption guard so dry runs predict reverts
		assertHopFullyConsumed(currentPoolIndex, sp.amountSpecified, amountIn)

		if currentPoolIndex == 0 {
			firstAmountIn = amountIn
		}

		nextPoolIndex := currentPoolIndex + 1
		if nextPoolIndex >= numPools {
			return firstAmountIn, amountOut, nil
		}

		nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, nextPoolIndex)
		sp.tokenIn = nextInput
		sp.tokenOut = nextOutput
		sp.fee = nextFee
		sp.amountSpecified = amountOut
	}
}

// multiDrySwapNegative simulates a multi-hop exact-output swap.
// It first quotes every hop backward, then simulates the collected swaps forward.
func (r *routerV1) multiDrySwapNegative(sp SingleSwapParams, numPools int, swapPath string) (int64, int64, error) {
	swapInfo := r.collectBackwardDrySwapInfo(sp, numPools, swapPath)
	return r.executeCollectedDrySwaps(swapInfo)
}

// collectBackwardDrySwapInfo quotes an exact-output route backward before real execution.
func (r *routerV1) collectBackwardDrySwapInfo(sp SingleSwapParams, numPools int, swapPath string) []SingleSwapParams {
	swapInfo := make([]SingleSwapParams, 0, numPools)

	for currentPoolIndex := numPools - 1; currentPoolIndex >= 0; currentPoolIndex-- {
		amountIn, _ := r.singleDrySwap(&sp)
		swapInfo = append(swapInfo, sp)

		if currentPoolIndex == 0 {
			break
		}

		nextPoolIndex := currentPoolIndex - 1
		nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, nextPoolIndex)
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

		// hops re-specified from the previous hop's actual output run as exact-in
		// (positive amountSpecified) and must consume that amount entirely
		if spec := swapInfo[currentPoolIndex].amountSpecified; spec > 0 {
			assertHopFullyConsumed(currentPoolIndex, spec, amountIn)
		}

		if currentPoolIndex == len(swapInfo)-1 {
			firstAmountIn = amountIn
		}

		if currentPoolIndex == 0 {
			return firstAmountIn, amountOut
		}

		nextPoolIndex := currentPoolIndex - 1
		swapInfo[nextPoolIndex].amountSpecified = amountOut
		payer = routerAddr
	}

	return firstAmountIn, 0
}

func (r *routerV1) executeCollectedDrySwaps(swapInfo []SingleSwapParams) (int64, int64, error) {
	firstAmountIn := int64(0)

	for currentPoolIndex := len(swapInfo) - 1; currentPoolIndex >= 0; currentPoolIndex-- {
		amountIn, amountOut := r.swapDryInner(
			swapInfo[currentPoolIndex].amountSpecified,
			u256.Zero(),
			newDrySwapCallbackData(swapInfo[currentPoolIndex]),
		)

		// mirror the real-swap full-consumption guard so dry runs predict reverts
		if spec := swapInfo[currentPoolIndex].amountSpecified; spec > 0 {
			err := validateHopFullyConsumed(currentPoolIndex, spec, amountIn)
			if err != nil {
				return 0, 0, err
			}
		}

		if currentPoolIndex == len(swapInfo)-1 {
			firstAmountIn = amountIn
		}

		if currentPoolIndex == 0 {
			return firstAmountIn, amountOut, nil
		}

		nextPoolIndex := currentPoolIndex - 1
		swapInfo[nextPoolIndex].amountSpecified = amountOut
	}

	return firstAmountIn, 0, nil
}
