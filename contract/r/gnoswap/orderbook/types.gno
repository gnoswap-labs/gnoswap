package orderbook

import (
	"time"

	"gno.land/p/nt/avl"

	u256 "gno.land/p/gnoswap/uint256"
)

type OrderDirection int

const (
	OrderDirectionBid OrderDirection = iota // Buy baseToken with quoteToken
	OrderDirectionAsk                       // Sell baseToken for quoteToken
)

func (d OrderDirection) String() string {
	switch d {
	case OrderDirectionBid:
		return "bid"
	case OrderDirectionAsk:
		return "ask"
	default:
		return "unknown"
	}
}

type LimitOrder struct {
	tickId           int64
	orderId          uint64
	orderDirection   OrderDirection
	owner            string
	quantity         *u256.Uint
	etas             *u256.Uint
	claimBounty      uint64 // basis points (0-100 = 0-1%)
	placedQuantity   *u256.Uint
	placedAt         time.Time
}

func (o *LimitOrder) TickId() int64                    { return o.tickId }
func (o *LimitOrder) OrderId() uint64                  { return o.orderId }
func (o *LimitOrder) OrderDirection() OrderDirection   { return o.orderDirection }
func (o *LimitOrder) Owner() string                    { return o.owner }
func (o *LimitOrder) Quantity() *u256.Uint             { return o.quantity }
func (o *LimitOrder) Etas() *u256.Uint                 { return o.etas }
func (o *LimitOrder) ClaimBounty() uint64              { return o.claimBounty }
func (o *LimitOrder) PlacedQuantity() *u256.Uint       { return o.placedQuantity }
func (o *LimitOrder) PlacedAt() time.Time              { return o.placedAt }

func (o *LimitOrder) SetQuantity(quantity *u256.Uint)  { o.quantity = quantity }
func (o *LimitOrder) SetEtas(etas *u256.Uint)          { o.etas = etas }

func NewLimitOrder(
	tickId int64,
	orderId uint64,
	orderDirection OrderDirection,
	owner string,
	quantity *u256.Uint,
	etas *u256.Uint,
	claimBounty uint64,
	placedAt time.Time,
) *LimitOrder {
	return &LimitOrder{
		tickId:          tickId,
		orderId:         orderId,
		orderDirection:  orderDirection,
		owner:           owner,
		quantity:        quantity.Clone(),
		etas:            etas.Clone(),
		claimBounty:     claimBounty,
		placedQuantity:  quantity.Clone(),
		placedAt:        placedAt,
	}
}

type TickValues struct {
	totalAmountOfLiquidity       *u256.Uint
	cumulativeTotalValue         *u256.Uint
	effectiveTotalAmountSwapped  *u256.Uint
}

func (tv *TickValues) TAL() *u256.Uint  { return tv.totalAmountOfLiquidity }
func (tv *TickValues) CTV() *u256.Uint  { return tv.cumulativeTotalValue }
func (tv *TickValues) ETAS() *u256.Uint { return tv.effectiveTotalAmountSwapped }

func (tv *TickValues) SetTAL(tal *u256.Uint)   { tv.totalAmountOfLiquidity = tal }
func (tv *TickValues) SetCTV(ctv *u256.Uint)   { tv.cumulativeTotalValue = ctv }
func (tv *TickValues) SetETAS(etas *u256.Uint) { tv.effectiveTotalAmountSwapped = etas }

func NewTickValues() *TickValues {
	return &TickValues{
		totalAmountOfLiquidity:       u256.Zero(),
		cumulativeTotalValue:         u256.Zero(),
		effectiveTotalAmountSwapped:  u256.Zero(),
	}
}

type TickState struct {
	askValues *TickValues
	bidValues *TickValues
}

func (ts *TickState) AskValues() *TickValues { return ts.askValues }
func (ts *TickState) BidValues() *TickValues { return ts.bidValues }

func (ts *TickState) GetValues(direction OrderDirection) *TickValues {
	if direction == OrderDirectionAsk {
		return ts.askValues
	}
	return ts.bidValues
}

func NewTickState() *TickState {
	return &TickState{
		askValues: NewTickValues(),
		bidValues: NewTickValues(),
	}
}

type Orderbook struct {
	quoteDenom   string
	baseDenom    string
	nextBidTick  int64
	nextAskTick  int64
	active       bool

	tickStates   *avl.Tree // key: tickId(int64) -> value: *TickState
	orders       *avl.Tree // key: (tickId, orderId) -> value: *LimitOrder
	ordersByOwner *avl.Tree // key: owner -> value: []orderKey

	nextOrderId  uint64
}

func (ob *Orderbook) QuoteDenom() string     { return ob.quoteDenom }
func (ob *Orderbook) BaseDenom() string      { return ob.baseDenom }
func (ob *Orderbook) NextBidTick() int64     { return ob.nextBidTick }
func (ob *Orderbook) NextAskTick() int64     { return ob.nextAskTick }
func (ob *Orderbook) Active() bool           { return ob.active }
func (ob *Orderbook) TickStates() *avl.Tree  { return ob.tickStates }
func (ob *Orderbook) Orders() *avl.Tree      { return ob.orders }
func (ob *Orderbook) NextOrderId() uint64    { return ob.nextOrderId }

func (ob *Orderbook) SetNextBidTick(tick int64) { ob.nextBidTick = tick }
func (ob *Orderbook) SetNextAskTick(tick int64) { ob.nextAskTick = tick }
func (ob *Orderbook) SetActive(active bool)     { ob.active = active }
func (ob *Orderbook) IncrementOrderId() uint64 {
	ob.nextOrderId++
	return ob.nextOrderId - 1
}

func NewOrderbook(quoteDenom, baseDenom string) *Orderbook {
	return &Orderbook{
		quoteDenom:    quoteDenom,
		baseDenom:     baseDenom,
		nextBidTick:   MIN_TICK,
		nextAskTick:   MAX_TICK,
		active:        true,
		tickStates:    avl.NewTree(),
		orders:        avl.NewTree(),
		ordersByOwner: avl.NewTree(),
		nextOrderId:   0,
	}
}
