package orderbook

import (
	"chain"
	"chain/runtime"
	"strconv"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/common"

	u256 "gno.land/p/gnoswap/uint256"
)

// ExecuteMarketOrder executes a market order by consuming liquidity across ticks
// Returns output amount received
func ExecuteMarketOrder(
	cur realm,
	quoteDenom, baseDenom string,
	orderDirection OrderDirection,
	quantity *u256.Uint,
	maxSlippageBps uint64, // basis points, e.g., 100 = 1%
) *u256.Uint {
	prevRealm := runtime.PreviousRealm()
	caller := prevRealm.Address()

	if quantity.IsZero() {
		panic(ErrInvalidQuantity)
	}

	ob := getOrderbook(quoteDenom, baseDenom)
	if !ob.active {
		panic(ErrInactiveOrderbook)
	}

	// Transfer input tokens from caller
	// Bid: caller sends quoteToken to buy baseToken
	// Ask: caller sends baseToken to sell for quoteToken
	inputTokenPath := quoteDenom
	if orderDirection == OrderDirectionAsk {
		inputTokenPath = baseDenom
	}

	common.SafeGRC20TransferFrom(cross, inputTokenPath, caller, runtime.CurrentRealm().Address(), quantity.Int64())

	remaining := quantity.Clone()
	totalOutput := u256.Zero()

	var currentTick int64
	var endTick int64
	var tickStep int64

	if orderDirection == OrderDirectionBid {
		// Buying base token - consume ask liquidity from lowest ask tick upward
		currentTick = ob.nextAskTick
		endTick = MAX_TICK
		tickStep = 1
	} else {
		// Selling base token - consume bid liquidity from highest bid tick downward
		currentTick = ob.nextBidTick
		endTick = MIN_TICK
		tickStep = -1
	}

	// Track ticks for updating next bid/ask
	var lastFilledTick int64 = currentTick

	// Iterate through ticks until order is filled
	for !remaining.IsZero() && currentTick != endTick {
		tickKey := strconv.FormatInt(currentTick, 10)
		tickStateValue, exists := ob.tickStates.Get(tickKey)

		if !exists {
			currentTick += tickStep
			continue
		}

		tickState := tickStateValue.(*TickState)
		var tickValues *TickValues

		// Get opposite side liquidity (ask for bid order, bid for ask order)
		if orderDirection == OrderDirectionBid {
			tickValues = tickState.AskValues()
		} else {
			tickValues = tickState.BidValues()
		}

		currentTAL := tickValues.TAL()
		if currentTAL.IsZero() {
			currentTick += tickStep
			continue
		}

		// Determine how much we can fill at this tick
		var fillAmount *u256.Uint
		if remaining.Gte(currentTAL) {
			// Consume entire tick
			fillAmount = currentTAL.Clone()
			remaining = new(u256.Uint).Sub(remaining, fillAmount)
		} else {
			// Partially consume tick
			fillAmount = remaining.Clone()
			remaining = u256.Zero()
		}

		// Calculate output value
		outputAtTick := amountToValue(fillAmount, currentTick)
		totalOutput = new(u256.Uint).Add(totalOutput, outputAtTick)

		// Update tick state
		newTAL := new(u256.Uint).Sub(currentTAL, fillAmount)
		newETAS := new(u256.Uint).Add(tickValues.ETAS(), fillAmount)
		tickValues.SetTAL(newTAL)
		tickValues.SetETAS(newETAS)

		lastFilledTick = currentTick

		// Move to next tick if this one exhausted
		if newTAL.IsZero() {
			currentTick += tickStep
		} else {
			break
		}
	}

	if !remaining.IsZero() {
		panic(ufmt.Errorf("insufficient liquidity: %s remaining", remaining.ToString()))
	}

	// Update next bid/ask pointers
	if orderDirection == OrderDirectionBid {
		ob.SetNextAskTick(lastFilledTick)
	} else {
		ob.SetNextBidTick(lastFilledTick)
	}

	// Check slippage
	if maxSlippageBps > 0 {
		expectedOutput := quantity.Clone() // Simplified - should use price calculation
		minOutput := new(u256.Uint).Mul(expectedOutput, u256.NewUint(10000-maxSlippageBps))
		minOutput = new(u256.Uint).Div(minOutput, u256.NewUint(10000))

		if totalOutput.Lt(minOutput) {
			panic(ErrSlippageExceeded)
		}
	}

	// Transfer output tokens to caller
	// Bid: output is baseToken
	// Ask: output is quoteToken
	outputTokenPath := baseDenom
	if orderDirection == OrderDirectionAsk {
		outputTokenPath = quoteDenom
	}

	if !totalOutput.IsZero() {
		common.SafeGRC20Transfer(cross, outputTokenPath, caller, totalOutput.Int64())
	}

	chain.Emit(
		"ExecuteMarketOrder",
		"caller", caller.String(),
		"orderbookKey", makeOrderbookKey(quoteDenom, baseDenom),
		"direction", orderDirection.String(),
		"quantity", quantity.ToString(),
		"output", totalOutput.ToString(),
	)

	return totalOutput
}
