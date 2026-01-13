package orderbook

import (
	"chain"
	"chain/runtime"
	"strconv"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/common"

	u256 "gno.land/p/gnoswap/uint256"
)

var (
	orderbooks *avl.Tree // key: orderbookKey(quote,base) -> value: *Orderbook
)

func init() {
	orderbooks = avl.NewTree()
}

func makeOrderbookKey(quoteDenom, baseDenom string) string {
	return quoteDenom + ":" + baseDenom
}

func makeOrderKey(tickId int64, orderId uint64) string {
	return strconv.FormatInt(tickId, 10) + ":" + strconv.FormatUint(orderId, 10)
}

// CreateOrderbook creates a new orderbook for a token pair
func CreateOrderbook(cur realm, quoteDenom, baseDenom string) {
	if quoteDenom == "" || baseDenom == "" {
		panic(ErrInvalidTokenPair)
	}

	key := makeOrderbookKey(quoteDenom, baseDenom)
	if orderbooks.Has(key) {
		panic(ErrOrderbookAlreadyExists)
	}

	ob := NewOrderbook(quoteDenom, baseDenom)
	orderbooks.Set(key, ob)

	chain.Emit(
		"CreateOrderbook",
		"quoteDenom", quoteDenom,
		"baseDenom", baseDenom,
	)
}

// SetOrderbookActive enables or disables an orderbook
func SetOrderbookActive(cur realm, quoteDenom, baseDenom string, active bool) {
	ob := getOrderbook(quoteDenom, baseDenom)
	ob.SetActive(active)

	chain.Emit(
		"SetOrderbookActive",
		"quoteDenom", quoteDenom,
		"baseDenom", baseDenom,
		"active", strconv.FormatBool(active),
	)
}

func getOrderbook(quoteDenom, baseDenom string) *Orderbook {
	key := makeOrderbookKey(quoteDenom, baseDenom)
	value, exists := orderbooks.Get(key)
	if !exists {
		panic(ErrOrderbookNotFound)
	}
	return value.(*Orderbook)
}

func getTickState(ob *Orderbook, tickId int64) *TickState {
	tickKey := strconv.FormatInt(tickId, 10)
	value, exists := ob.tickStates.Get(tickKey)
	if !exists {
		ts := NewTickState()
		ob.tickStates.Set(tickKey, ts)
		return ts
	}
	return value.(*TickState)
}

func getOrder(ob *Orderbook, tickId int64, orderId uint64) (*LimitOrder, bool) {
	orderKey := makeOrderKey(tickId, orderId)
	value, exists := ob.orders.Get(orderKey)
	if !exists {
		return nil, false
	}
	return value.(*LimitOrder), true
}

func setOrder(ob *Orderbook, order *LimitOrder) {
	orderKey := makeOrderKey(order.tickId, order.orderId)
	ob.orders.Set(orderKey, order)
}

func deleteOrder(ob *Orderbook, tickId int64, orderId uint64) {
	orderKey := makeOrderKey(tickId, orderId)
	ob.orders.Remove(orderKey)
}

// PlaceLimitOrder places a new limit order at specified tick
func PlaceLimitOrder(
	cur realm,
	quoteDenom, baseDenom string,
	tickId int64,
	orderDirection OrderDirection,
	quantity *u256.Uint,
	claimBountyBps uint64,
) uint64 {
	// Get caller
	prevRealm := runtime.PreviousRealm()
	caller := prevRealm.Address()

	// Validation
	if tickId < MIN_TICK || tickId > MAX_TICK {
		panic(ErrInvalidTickId)
	}
	if quantity.IsZero() {
		panic(ErrInvalidQuantity)
	}
	if claimBountyBps > MAX_CLAIM_BOUNTY_BPS {
		panic(ErrInvalidBounty)
	}
	if orderDirection != OrderDirectionBid && orderDirection != OrderDirectionAsk {
		panic(ErrInvalidOrderDirection)
	}

	ob := getOrderbook(quoteDenom, baseDenom)
	if !ob.active {
		panic(ErrInactiveOrderbook)
	}

	// Transfer tokens from caller to orderbook
	// Bid: caller sends quoteDenom tokens
	// Ask: caller sends baseDenom tokens
	tokenPath := quoteDenom
	if orderDirection == OrderDirectionAsk {
		tokenPath = baseDenom
	}

	common.SafeGRC20TransferFrom(cross, tokenPath, caller, runtime.CurrentRealm().Address(), quantity.Int64())

	// Get tick state
	tickState := getTickState(ob, tickId)
	tickValues := tickState.GetValues(orderDirection)

	// Generate order ID
	orderId := ob.IncrementOrderId()

	// Create order with current ETAS as placement snapshot
	order := NewLimitOrder(
		tickId,
		orderId,
		orderDirection,
		caller.String(),
		quantity,
		tickValues.ETAS().Clone(), // Capture current fill level
		claimBountyBps,
		time.Now(),
	)

	// Update tick state
	newCTV := new(u256.Uint).Add(tickValues.CTV(), quantity)
	newTAL := new(u256.Uint).Add(tickValues.TAL(), quantity)
	tickValues.SetCTV(newCTV)
	tickValues.SetTAL(newTAL)

	// Store order
	setOrder(ob, order)

	// Update best bid/ask pointers
	if orderDirection == OrderDirectionBid {
		if tickId > ob.nextBidTick || ob.nextBidTick == MIN_TICK {
			ob.SetNextBidTick(tickId)
		}
	} else {
		if tickId < ob.nextAskTick || ob.nextAskTick == MAX_TICK {
			ob.SetNextAskTick(tickId)
		}
	}

	chain.Emit(
		"PlaceLimitOrder",
		"caller", caller.String(),
		"orderbookKey", makeOrderbookKey(quoteDenom, baseDenom),
		"tickId", strconv.FormatInt(tickId, 10),
		"orderId", strconv.FormatUint(orderId, 10),
		"direction", orderDirection.String(),
		"quantity", quantity.ToString(),
	)

	return orderId
}

// CancelLimitOrder cancels an existing order and refunds remaining quantity
func CancelLimitOrder(
	cur realm,
	quoteDenom, baseDenom string,
	tickId int64,
	orderId uint64,
) {
	prevRealm := runtime.PreviousRealm()
	caller := prevRealm.Address()

	ob := getOrderbook(quoteDenom, baseDenom)
	order, exists := getOrder(ob, tickId, orderId)
	if !exists {
		panic(ErrOrderNotFound)
	}

	if order.owner != caller.String() {
		panic(ErrUnauthorized)
	}

	// Get tick state
	tickState := getTickState(ob, tickId)
	tickValues := tickState.GetValues(order.orderDirection)

	// Check if order is not fully filled
	if tickValues.ETAS().Gt(order.etas) {
		// Partially filled - calculate remaining
		filled := new(u256.Uint).Sub(tickValues.ETAS(), order.etas)
		if filled.Gte(order.quantity) {
			panic(ufmt.Errorf("order fully filled, use ClaimOrder instead"))
		}
	}

	remaining := order.quantity

	// Update tick state - decrease TAL
	newTAL := new(u256.Uint).Sub(tickValues.TAL(), remaining)
	tickValues.SetTAL(newTAL)

	// Delete order
	deleteOrder(ob, tickId, orderId)

	// Refund tokens to caller
	// Bid: refund quoteDenom tokens
	// Ask: refund baseDenom tokens
	tokenPath := quoteDenom
	if order.orderDirection == OrderDirectionAsk {
		tokenPath = baseDenom
	}

	common.SafeGRC20Transfer(cross, tokenPath, caller, remaining.Int64())

	chain.Emit(
		"CancelLimitOrder",
		"caller", caller.String(),
		"orderbookKey", makeOrderbookKey(quoteDenom, baseDenom),
		"tickId", strconv.FormatInt(tickId, 10),
		"orderId", strconv.FormatUint(orderId, 10),
		"refunded", remaining.ToString(),
	)
}

// ClaimOrder claims filled portion of an order
func ClaimOrder(
	cur realm,
	quoteDenom, baseDenom string,
	tickId int64,
	orderId uint64,
) *u256.Uint {
	prevRealm := runtime.PreviousRealm()
	caller := prevRealm.Address()

	ob := getOrderbook(quoteDenom, baseDenom)
	order, exists := getOrder(ob, tickId, orderId)
	if !exists {
		panic(ErrOrderNotFound)
	}

	// Get tick state
	tickState := getTickState(ob, tickId)
	tickValues := tickState.GetValues(order.orderDirection)

	// Calculate filled amount
	currentETAS := tickValues.ETAS()
	orderETAS := order.etas

	if currentETAS.Lte(orderETAS) {
		panic(ErrZeroClaim)
	}

	filledSinceLastClaim := new(u256.Uint).Sub(currentETAS, orderETAS)

	// Cap at remaining quantity
	if filledSinceLastClaim.Gt(order.quantity) {
		filledSinceLastClaim = order.quantity.Clone()
	}

	// Calculate output value using tick price
	outputValue := amountToValue(filledSinceLastClaim, tickId)

	// Deduct bounty if caller is not owner
	var bountyAmount *u256.Uint = u256.Zero()
	var ownerOutput *u256.Uint = outputValue.Clone()

	if caller.String() != order.owner && order.claimBounty > 0 {
		bountyAmount = new(u256.Uint).Mul(outputValue, u256.NewUint(order.claimBounty))
		bountyAmount = new(u256.Uint).Div(bountyAmount, u256.NewUint(10000)) // Convert bps
		ownerOutput = new(u256.Uint).Sub(outputValue, bountyAmount)
	}

	// Update order state
	newQuantity := new(u256.Uint).Sub(order.quantity, filledSinceLastClaim)
	order.SetQuantity(newQuantity)
	order.SetEtas(currentETAS.Clone())

	// If fully claimed, delete order
	if newQuantity.IsZero() {
		deleteOrder(ob, tickId, orderId)
	}

	// Transfer tokens
	// Bid order: filled with baseToken, output is baseToken
	// Ask order: filled with quoteToken, output is quoteToken
	outputTokenPath := baseDenom
	if order.orderDirection == OrderDirectionBid {
		outputTokenPath = baseDenom
	} else {
		outputTokenPath = quoteDenom
	}

	// Transfer to owner
	if !ownerOutput.IsZero() {
		ownerAddr := parseAddress(order.owner)
		common.SafeGRC20Transfer(cross, outputTokenPath, ownerAddr, ownerOutput.Int64())
	}

	// Transfer bounty to claimer if applicable
	if !bountyAmount.IsZero() && caller.String() != order.owner {
		common.SafeGRC20Transfer(cross, outputTokenPath, caller, bountyAmount.Int64())
	}

	chain.Emit(
		"ClaimOrder",
		"caller", caller.String(),
		"owner", order.owner,
		"orderbookKey", makeOrderbookKey(quoteDenom, baseDenom),
		"tickId", strconv.FormatInt(tickId, 10),
		"orderId", strconv.FormatUint(orderId, 10),
		"filled", filledSinceLastClaim.ToString(),
		"output", outputValue.ToString(),
		"bounty", bountyAmount.ToString(),
	)

	return outputValue
}

func parseAddress(addr string) address {
	return address(addr)
}
