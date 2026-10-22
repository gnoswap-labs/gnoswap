package dca_order

import (
	u256 "gno.land/p/gnoswap/uint256/v1"
	"gno.land/p/gnoswap/utils/v1"
	bptree "gno.land/p/nt/bptree/v0"
)

// DefaultBPTreeFanout is the fanout of every B+tree in this realm.
const DefaultBPTreeFanout = 16

// OrderStatus is the lifecycle state of a DCA order.
type OrderStatus string

const (
	// OrderStatusActive marks an order that still sells input or holds unclaimed output.
	OrderStatusActive OrderStatus = "ACTIVE"
	// OrderStatusCompleted marks an order whose rounds all executed and whose output was claimed.
	OrderStatusCompleted OrderStatus = "COMPLETED"
	// OrderStatusCancelled marks an order cancelled by its owner; unsold input was refunded.
	OrderStatusCancelled OrderStatus = "CANCELLED"
)

// String returns the textual status.
func (s OrderStatus) String() string {
	return string(s)
}

// NewBPTreeN allocates a B+tree owned by the dca_order realm.
// /r/-declared storage must be allocated in its owning realm, so
// implementation realms create trees through this constructor.
//
// Parameters:
//   - fanout: B+tree node fanout.
//
// Returns:
//   - tree: empty B+tree allocated in this realm.
func NewBPTreeN(fanout int) *bptree.BPTree {
	return bptree.NewBPTreeN(fanout)
}

// u256 setters below take ownership of the value passed in; callers must pass
// a fresh value (getters return copies) and never share one value between two
// persisted fields.

// Order is a single user's DCA order. It sells amountPerExecution of tokenIn
// in each of totalExecutions consecutive rounds of its group.
//
// The order participates in group rounds (startRound, endRound]. Output is
// accounted by the group accumulator: claimable output equals
// amountPerExecution * (acc(min(round, endRound)) - accDebtX128) / 2^128.
type Order struct {
	id    uint64
	owner address

	groupID string // pool, tokens, direction, and interval live on the group

	amountPerExecution int64
	startRound         uint64
	endRound           uint64

	accDebtX128 *u256.Uint // group accumulator at the last settlement
	claimedOut  *u256.Uint // lifetime output transferred to the owner (256-bit so it never blocks settlement)
	refundedIn  int64      // unsold input refunded on cancel
	feePaid     int64      // prepaid creation fee (input token)

	status      OrderStatus
	cancelRound uint64 // group round at cancellation; 0 unless cancelled
	createdAt   int64
	createdAtH  int64
	finalizedAt int64 // completion or cancellation time, 0 while active
}

// NewOrder allocates an order in the dca_order realm.
//
// Parameters:
//   - id: unique order identifier.
//   - owner: address that owns the order and receives output and refunds.
//   - group: group the order joins; its current round becomes the start round.
//   - amountPerExecution: input sold per round.
//   - totalExecutions: number of rounds the order participates in.
//   - feePaid: prepaid creation fee charged in the input token.
//   - createdAt: creation unix timestamp.
//   - createdAtHeight: creation block height.
//
// Returns:
//   - order: new active order whose debt equals the group's current accumulator.
func NewOrder(
	id uint64,
	owner address,
	group *Group,
	amountPerExecution int64,
	totalExecutions int64,
	feePaid int64,
	createdAt int64,
	createdAtHeight int64,
) *Order {
	return &Order{
		id:                 id,
		owner:              owner,
		groupID:            group.ID(),
		amountPerExecution: amountPerExecution,
		startRound:         group.Round(),
		endRound:           group.Round() + uint64(totalExecutions),
		accDebtX128:        group.AccX128(), // getter already returns a copy
		claimedOut:         u256.Zero(),
		refundedIn:         0,
		feePaid:            feePaid,
		status:             OrderStatusActive,
		createdAt:          createdAt,
		createdAtH:         createdAtHeight,
		finalizedAt:        0,
	}
}

func (o *Order) ID() uint64                  { return o.id }
func (o *Order) Owner() address              { return o.owner }
func (o *Order) GroupID() string             { return o.groupID }
func (o *Order) AmountPerExecution() int64   { return o.amountPerExecution }
func (o *Order) TotalExecutions() int64      { return int64(o.endRound - o.startRound) }
func (o *Order) StartRound() uint64          { return o.startRound }
func (o *Order) EndRound() uint64            { return o.endRound }
func (o *Order) AccDebtX128() *u256.Uint     { return o.accDebtX128.Clone() }
func (o *Order) ClaimedOut() *u256.Uint      { return o.claimedOut.Clone() }
func (o *Order) RefundedIn() int64           { return o.refundedIn }
func (o *Order) FeePaid() int64              { return o.feePaid }
func (o *Order) Status() OrderStatus         { return o.status }
func (o *Order) CreatedAt() int64            { return o.createdAt }
func (o *Order) CreatedAtHeight() int64      { return o.createdAtH }
func (o *Order) FinalizedAt() int64          { return o.finalizedAt }
func (o *Order) CancelRound() uint64         { return o.cancelRound }
func (o *Order) SetCancelRound(v uint64)     { o.cancelRound = v }
func (o *Order) IsActive() bool              { return o.status == OrderStatusActive }
func (o *Order) SetAccDebtX128(v *u256.Uint) { o.accDebtX128 = v }
func (o *Order) SetClaimedOut(v *u256.Uint)  { o.claimedOut = v }
func (o *Order) SetRefundedIn(v int64)       { o.refundedIn = v }
func (o *Order) SetStatus(v OrderStatus)     { o.status = v }
func (o *Order) SetFinalizedAt(v int64)      { o.finalizedAt = v }

// Group aggregates every order that sells the same token in the same pool at
// the same interval. A round sells the sum of the active orders'
// amountPerExecution in one router swap and adds the output per unit of
// input to accX128.
type Group struct {
	id         string
	poolPath   string
	tokenIn    string
	tokenOut   string
	zeroForOne bool
	interval   int64

	round           uint64     // number of executed rounds
	rate            int64      // input sold in the next round
	accX128         *u256.Uint // cumulative output per unit input, Q128
	nextExecutionAt int64      // earliest unix time of the next round
	lastExecutedAt  int64      // unix time of the last executed round, 0 if none

	activeOrders   int64
	totalAmountIn  *u256.Uint // cumulative input sold (statistics only)
	totalAmountOut *u256.Uint // cumulative output received (statistics only)

	roundMarks *bptree.BPTree // EncodeUint64(round) -> *RoundMark
}

// NewGroup allocates a group in the dca_order realm.
//
// Parameters:
//   - id: group identifier (poolPath:direction:interval).
//   - poolPath: pool used for every round.
//   - tokenIn: token sold by the group.
//   - tokenOut: token bought by the group.
//   - zeroForOne: true when tokenIn is the pool's token0.
//   - interval: seconds between rounds.
//   - nextExecutionAt: earliest unix time of the first round.
//
// Returns:
//   - group: empty group with a zero accumulator.
func NewGroup(
	id string,
	poolPath string,
	tokenIn string,
	tokenOut string,
	zeroForOne bool,
	interval int64,
	nextExecutionAt int64,
) *Group {
	return &Group{
		id:              id,
		poolPath:        poolPath,
		tokenIn:         tokenIn,
		tokenOut:        tokenOut,
		zeroForOne:      zeroForOne,
		interval:        interval,
		round:           0,
		rate:            0,
		accX128:         u256.Zero(),
		nextExecutionAt: nextExecutionAt,
		lastExecutedAt:  0,
		totalAmountIn:   u256.Zero(),
		totalAmountOut:  u256.Zero(),
		roundMarks:      bptree.NewBPTreeN(DefaultBPTreeFanout),
	}
}

func (g *Group) ID() string                     { return g.id }
func (g *Group) PoolPath() string               { return g.poolPath }
func (g *Group) TokenIn() string                { return g.tokenIn }
func (g *Group) TokenOut() string               { return g.tokenOut }
func (g *Group) ZeroForOne() bool               { return g.zeroForOne }
func (g *Group) Interval() int64                { return g.interval }
func (g *Group) Round() uint64                  { return g.round }
func (g *Group) Rate() int64                    { return g.rate }
func (g *Group) AccX128() *u256.Uint            { return g.accX128.Clone() }
func (g *Group) NextExecutionAt() int64         { return g.nextExecutionAt }
func (g *Group) LastExecutedAt() int64          { return g.lastExecutedAt }
func (g *Group) ActiveOrders() int64            { return g.activeOrders }
func (g *Group) TotalAmountIn() *u256.Uint      { return g.totalAmountIn.Clone() }
func (g *Group) TotalAmountOut() *u256.Uint     { return g.totalAmountOut.Clone() }
func (g *Group) SetRound(v uint64)              { g.round = v }
func (g *Group) SetRate(v int64)                { g.rate = v }
func (g *Group) SetAccX128(v *u256.Uint)        { g.accX128 = v }
func (g *Group) SetNextExecutionAt(v int64)     { g.nextExecutionAt = v }
func (g *Group) SetLastExecutedAt(v int64)      { g.lastExecutedAt = v }
func (g *Group) SetActiveOrders(v int64)        { g.activeOrders = v }
func (g *Group) SetTotalAmountIn(v *u256.Uint)  { g.totalAmountIn = v }
func (g *Group) SetTotalAmountOut(v *u256.Uint) { g.totalAmountOut = v }
func (g *Group) RoundMarkCount() int            { return g.roundMarks.Size() }

// GetRoundMark returns the mark of a round, or nil when no order ends there.
func (g *Group) GetRoundMark(round uint64) *RoundMark {
	value := g.roundMarks.Get(roundKey(round))
	if value == nil {
		return nil
	}

	return value.(*RoundMark)
}

// GetOrCreateRoundMark returns the mark of a round, creating an empty one.
func (g *Group) GetOrCreateRoundMark(round uint64) *RoundMark {
	mark := g.GetRoundMark(round)
	if mark != nil {
		return mark
	}

	// The snapshot slot is allocated here, when the first order ending at this
	// round is created, so its storage deposit is paid by that order's creator
	// rather than by whoever later executes the round.
	mark = &RoundMark{endingRate: 0, refCount: 0, executed: false, accX128: u256.Zero()}
	g.roundMarks.Set(roundKey(round), mark)

	return mark
}

// RemoveRoundMark deletes the mark of a round.
func (g *Group) RemoveRoundMark(round uint64) {
	g.roundMarks.Remove(roundKey(round))
}

// RoundMark records the orders whose last round is the mark's round (its key).
//
// endingRate is removed from the group rate right after the round executes,
// and accX128 snapshots the accumulator at that moment so finished orders can
// settle without per-round history. The mark is released once every order
// ending at the round is finalized (refCount reaches zero).
type RoundMark struct {
	endingRate int64
	refCount   int64
	executed   bool
	accX128    *u256.Uint // valid once executed; allocated at mark creation
}

func (m *RoundMark) EndingRate() int64     { return m.endingRate }
func (m *RoundMark) RefCount() int64       { return m.refCount }
func (m *RoundMark) IsExecuted() bool      { return m.executed }
func (m *RoundMark) SetEndingRate(v int64) { m.endingRate = v }
func (m *RoundMark) SetRefCount(v int64)   { m.refCount = v }

// SnapshotAccX128 records the accumulator right after the round executes. It
// writes into the slot allocated at mark creation, so no new object is stored.
func (m *RoundMark) SnapshotAccX128(v *u256.Uint) {
	m.accX128.Set(v)
	m.executed = true
}

// AccX128 returns the accumulator snapshot, or nil before the round executes.
func (m *RoundMark) AccX128() *u256.Uint {
	if !m.executed {
		return nil
	}

	return m.accX128.Clone()
}

// Config holds governance-controlled DCA parameters.
type Config struct {
	creationFeeBps        int64 // fee prepaid at creation, bps of the total input
	minAmountPerExecution int64 // minimum input per round
	maxTotalExecutions    int64 // maximum rounds per order
}

// NewConfig allocates a configuration in the dca_order realm.
func NewConfig(creationFeeBps, minAmountPerExecution, maxTotalExecutions int64) *Config {
	return &Config{
		creationFeeBps:        creationFeeBps,
		minAmountPerExecution: minAmountPerExecution,
		maxTotalExecutions:    maxTotalExecutions,
	}
}

func (c *Config) CreationFeeBps() int64            { return c.creationFeeBps }
func (c *Config) MinAmountPerExecution() int64     { return c.minAmountPerExecution }
func (c *Config) MaxTotalExecutions() int64        { return c.maxTotalExecutions }
func (c *Config) SetCreationFeeBps(v int64)        { c.creationFeeBps = v }
func (c *Config) SetMinAmountPerExecution(v int64) { c.minAmountPerExecution = v }
func (c *Config) SetMaxTotalExecutions(v int64)    { c.maxTotalExecutions = v }

// roundKey encodes a round as a fixed-width big-endian key so B+tree order
// matches numeric order.
func roundKey(round uint64) string {
	return utils.EncodeUint64(round)
}
