package v3

import (
	"chain/runtime"
)

// SwapDirection represents the direction of swap execution in multi-hop swaps.
// It determines whether swaps are processed in forward order (first to last pool)
// or backward order (last to first pool).
type SwapDirection int

const (
	_ SwapDirection = iota
	// Forward indicates a swap processing direction from the first pool to the last pool.
	// Used primarily for exactIn swaps where the input amount is known.
	Forward

	// Backward indicates a swap processing direction from the last pool to the first pool.
	// Used primarily for exactOut swaps where the output amount is known and input amounts
	// Need to be calculated in reverse order.
	Backward
)

// MultiSwapExecutor defines the interface for multi-hop swap operation execution.
type MultiSwapExecutor interface {
	// Run performs the swap operation and returns pool received and pool output amounts.
	Run(p SwapParams, data SwapCallbackData, recipient address) (int64, int64)
}

// DryMultiSwapExecutor implements MultiSwapExecutor for dry run simulations.
type DryMultiSwapExecutor struct {
	router *routerV1
}

// Run performs a dry swap operation without changing state.
func (e *DryMultiSwapExecutor) Run(p SwapParams, data SwapCallbackData, _ address) (int64, int64) {
	return e.router.swapDryInner(p.amountSpecified, zero, data)
}

// RealMultiSwapExecutor implements MultiSwapExecutor for actual swap operations.
type RealMultiSwapExecutor struct {
	router *routerV1
}

// Run performs a real swap operation with state changes.
func (e *RealMultiSwapExecutor) Run(p SwapParams, data SwapCallbackData, recipient address) (int64, int64) {
	return e.router.swapInner(p.amountSpecified, recipient, zero, data)
}

// MultiSwapProcessor handles the execution flow for multi-hop swaps.
type MultiSwapProcessor struct {
	executor   MultiSwapExecutor
	direction  SwapDirection
	router     *routerV1
	isSimulate bool
}

var (
	_ MultiSwapExecutor = (*DryMultiSwapExecutor)(nil)
	_ MultiSwapExecutor = (*RealMultiSwapExecutor)(nil)
)

// NewMultiSwapProcessor creates a new MultiSwapProcessor with the specified configuration.
func NewMultiSwapProcessor(r *routerV1, isSimulate bool, direction SwapDirection) *MultiSwapProcessor {
	var executor MultiSwapExecutor
	if isSimulate {
		executor = &DryMultiSwapExecutor{router: r}
	} else {
		executor = &RealMultiSwapExecutor{router: r}
	}

	return &MultiSwapProcessor{
		executor:   executor,
		direction:  direction,
		router:     r,
		isSimulate: isSimulate,
	}
}

// processForwardSwap handles forward direction swaps (exactIn).
func (p *MultiSwapProcessor) processForwardSwap(sp SwapParams, numPools int, swapPath string) (int64, int64, error) {
	payer := runtime.PreviousRealm().Address() // Initial payer is the user

	firstAmountIn := int64(0)
	currentPoolIndex := 0

	for {
		currentPoolIndex++

		// Execute the swap operation
		callbackData := newSwapCallbackData(sp, payer)
		amountIn, amountOut := p.executor.Run(sp, callbackData, sp.recipient)

		// Record the first hop's input amount
		if currentPoolIndex == 1 {
			firstAmountIn = amountIn
		}

		// Check if we've processed all hops
		if currentPoolIndex >= numPools {
			return firstAmountIn, amountOut, nil
		}

		// Update parameters for the next hop
		payer = routerAddr
		nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex)
		sp.tokenIn = nextInput
		sp.tokenOut = nextOutput
		sp.fee = nextFee
		sp.amountSpecified = amountOut
	}
}

// processBackwardSwap handles backward direction swaps (exactOut).
func (p *MultiSwapProcessor) processBackwardSwap(sp SwapParams, numPools int, swapPath string) (int64, int64, error) {
	if !p.isSimulate {
		return p.processBackwardRealSwap(sp, numPools, swapPath)
	}
	return p.processBackwardDrySwap(sp, numPools, swapPath)
}

// processBackwardDrySwap handles backward simulated swaps.
func (p *MultiSwapProcessor) processBackwardDrySwap(sp SwapParams, numPools int, swapPath string) (int64, int64, error) {
	firstAmountIn := int64(0)
	currentPoolIndex := numPools - 1
	payer := routerAddr

	for {
		callbackData := newSwapCallbackData(sp, payer)
		amountIn, amountOut := p.executor.Run(sp, callbackData, sp.recipient)

		if currentPoolIndex == 0 {
			firstAmountIn = amountIn
		}

		currentPoolIndex--

		if currentPoolIndex == -1 {
			return firstAmountIn, amountOut, nil
		}

		// Update parameters for the next hop
		nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex)

		sp.amountSpecified = -amountIn
		sp.tokenIn = nextInput
		sp.tokenOut = nextOutput
		sp.fee = nextFee
	}
}

// processBackwardRealSwap handles backward real swaps.
func (p *MultiSwapProcessor) processBackwardRealSwap(sp SwapParams, numPools int, swapPath string) (int64, int64, error) {
	// First collect all swap information by simulating backward
	swapInfo := p.collectBackwardSwapInfo(sp, numPools, swapPath)

	// Then execute swaps in forward order
	return p.executeCollectedSwaps(swapInfo, sp.recipient, sp.withUnwrap)
}

// collectBackwardSwapInfo simulates swaps backward to collect parameters.
func (p *MultiSwapProcessor) collectBackwardSwapInfo(sp SwapParams, numPools int, swapPath string) []SingleSwapParams {
	currentPoolIndex := numPools - 1
	swapInfo := make([]SingleSwapParams, 0, currentPoolIndex)

	for currentPoolIndex >= 0 {
		thisSwap := SingleSwapParams{
			tokenIn:         sp.tokenIn,
			tokenOut:        sp.tokenOut,
			fee:             sp.fee,
			amountSpecified: sp.amountSpecified,
		}

		// dry simulation to calculate input amount
		amountIn, _ := p.router.singleDrySwap(&thisSwap)
		swapInfo = append(swapInfo, thisSwap)

		if currentPoolIndex == 0 {
			break
		}
		currentPoolIndex--

		// Update parameters for the next simulation
		nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex)

		sp.tokenIn = nextInput
		sp.tokenOut = nextOutput
		sp.fee = nextFee
		sp.amountSpecified = -amountIn
	}

	return swapInfo
}

// executeCollectedSwaps performs the collected swaps in forward order.
func (p *MultiSwapProcessor) executeCollectedSwaps(swapInfo []SingleSwapParams, recipient address, withUnwrap bool) (int64, int64, error) {
	firstAmountIn := int64(0)
	currentPoolIndex := len(swapInfo) - 1
	payer := runtime.PreviousRealm().Address() // Initial payer is the user

	for currentPoolIndex >= 0 {
		// Execute the swap
		callbackData := newSwapCallbackData(
			swapInfo[currentPoolIndex],
			payer,
		)

		amountIn, amountOut := p.router.swapInner(
			swapInfo[currentPoolIndex].amountSpecified,
			recipient,
			zero,
			callbackData,
		)

		// Record the first hop's input amount
		if currentPoolIndex == len(swapInfo)-1 {
			firstAmountIn = amountIn
		}

		if currentPoolIndex == 0 {
			return firstAmountIn, amountOut, nil
		}

		// Update parameters for the next swap
		swapInfo[currentPoolIndex-1].amountSpecified = amountOut
		payer = routerAddr
		currentPoolIndex--
	}

	return firstAmountIn, 0, nil
}

// multiSwap performs a multi-hop swap in forward direction.
func (r *routerV1) multiSwap(p SwapParams, numPools int, swapPath string) (int64, int64) {
	result, output, err := NewMultiSwapProcessor(r, false, Forward).
		processForwardSwap(p, numPools, swapPath)
	if err != nil {
		panic(err)
	}
	return result, output
}

// multiSwapNegative performs a multi-hop swap in backward direction.
func (r *routerV1) multiSwapNegative(p SwapParams, numPools int, swapPath string) (int64, int64) {
	result, output, err := NewMultiSwapProcessor(r, false, Backward).
		processBackwardSwap(p, numPools, swapPath)
	if err != nil {
		panic(err)
	}
	return result, output
}

// multiDrySwap simulates a multi-hop swap in forward direction.
func (r *routerV1) multiDrySwap(p SwapParams, numPool int, swapPath string) (int64, int64, error) {
	return NewMultiSwapProcessor(r, true, Forward).
		processForwardSwap(p, numPool, swapPath)
}

// multiDrySwapNegative simulates a multi-hop swap in backward direction.
func (r *routerV1) multiDrySwapNegative(p SwapParams, numPool int, swapPath string) (int64, int64, error) {
	return NewMultiSwapProcessor(r, true, Backward).
		processBackwardSwap(p, numPool, swapPath)
}
