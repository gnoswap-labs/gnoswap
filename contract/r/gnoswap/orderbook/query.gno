package orderbook

import (
	"strconv"

	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// GetOrderbookInfo returns orderbook metadata
func GetOrderbookInfo(quoteDenom, baseDenom string) string {
	ob := getOrderbook(quoteDenom, baseDenom)

	return ufmt.Sprintf(
		"Orderbook(%s/%s): active=%s, nextBid=%d, nextAsk=%d, nextOrderId=%d",
		ob.quoteDenom,
		ob.baseDenom,
		strconv.FormatBool(ob.active),
		ob.nextBidTick,
		ob.nextAskTick,
		ob.nextOrderId,
	)
}

// GetOrder returns order details
func GetOrder(quoteDenom, baseDenom string, tickId int64, orderId uint64) string {
	ob := getOrderbook(quoteDenom, baseDenom)
	order, exists := getOrder(ob, tickId, orderId)
	if !exists {
		return "Order not found"
	}

	return ufmt.Sprintf(
		"Order[%d:%d]: owner=%s, dir=%s, qty=%s, etas=%s, bounty=%dbps, placed=%s",
		order.tickId,
		order.orderId,
		order.owner,
		order.orderDirection.String(),
		order.quantity.ToString(),
		order.etas.ToString(),
		order.claimBounty,
		order.placedAt.Format("2006-01-02 15:04:05"),
	)
}

// GetTickState returns tick liquidity info
func GetTickState(quoteDenom, baseDenom string, tickId int64) string {
	ob := getOrderbook(quoteDenom, baseDenom)
	tickState := getTickState(ob, tickId)

	askVals := tickState.AskValues()
	bidVals := tickState.BidValues()

	return ufmt.Sprintf(
		"Tick[%d]: Ask(TAL=%s,CTV=%s,ETAS=%s) Bid(TAL=%s,CTV=%s,ETAS=%s)",
		tickId,
		askVals.TAL().ToString(),
		askVals.CTV().ToString(),
		askVals.ETAS().ToString(),
		bidVals.TAL().ToString(),
		bidVals.CTV().ToString(),
		bidVals.ETAS().ToString(),
	)
}

// GetTickPrice returns the price at a tick
func GetTickPrice(tickId int64) *u256.Uint {
	return tickToPrice(tickId)
}

// GetBestBidAsk returns best bid and ask ticks with their prices
func GetBestBidAsk(quoteDenom, baseDenom string) (int64, *u256.Uint, int64, *u256.Uint) {
	ob := getOrderbook(quoteDenom, baseDenom)

	bestBid := ob.nextBidTick
	bestAsk := ob.nextAskTick

	var bidPrice, askPrice *u256.Uint
	if bestBid != MIN_TICK {
		bidPrice = tickToPrice(bestBid)
	} else {
		bidPrice = u256.Zero()
	}

	if bestAsk != MAX_TICK {
		askPrice = tickToPrice(bestAsk)
	} else {
		askPrice = u256.Zero()
	}

	return bestBid, bidPrice, bestAsk, askPrice
}
