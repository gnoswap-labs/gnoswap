package pool

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256/v1"
)

// Pool describes a single pool's state.
// A pool is identified with a unique key (token0, token1, fee), where token0 < token1.
type Pool struct {
	// token0/token1 path of the pool
	token0Path           string
	token1Path           string
	fee                  uint32 // fee tier of the pool
	tickSpacing          int32  // spacing between ticks
	slot0                Slot0
	balances             TokenPair // balances of the pool
	protocolFees         TokenPair
	feeGrowthGlobal0X128 *u256.Uint       // uint256
	feeGrowthGlobal1X128 *u256.Uint       // uint256
	liquidity            *u256.Uint       // total amount of active liquidity in the pool (within current tick range)
	ticks                *bptree.BPTree   // tick(int32) -> TickInfo
	tickBitmaps          map[int16]string // tick(wordPos)(int16) -> bitMap(tickWord ^ mask)(string)
	positions            *bptree.BPTree   // maps encoded lower/upper tick pairs to aggregate pool accounting
}

// Pool Getters methods
// PoolPath returns the canonical pool path derived from token0, token1, and the fee tier.
//
// Returns:
//   - string: pool identifier assembled from the pool's token paths and fee.
func (p *Pool) PoolPath() string { return GetPoolPath(p.token0Path, p.token1Path, p.fee) }

// Token0Path returns the path of the pool's token0 asset.
//
// Returns:
//   - string: token0 path stored in the pool.
func (p *Pool) Token0Path() string { return p.token0Path }

// Token1Path returns the path of the pool's token1 asset.
//
// Returns:
//   - string: token1 path stored in the pool.
func (p *Pool) Token1Path() string { return p.token1Path }

// Fee returns the pool's fee tier.
//
// Returns:
//   - uint32: fee tier used by swaps in this pool.
func (p *Pool) Fee() uint32 { return p.fee }

// Balances returns the pool's current token balances.
//
// Returns:
//   - TokenPair: token0 and token1 balances tracked by the pool.
func (p *Pool) Balances() TokenPair { return p.balances }

// BalanceToken0 returns the pool's current token0 balance.
//
// Returns:
//   - int64: token0 balance available in the pool.
func (p *Pool) BalanceToken0() int64 { return p.balances.token0 }

// BalanceToken1 returns the pool's current token1 balance.
//
// Returns:
//   - int64: token1 balance available in the pool.
func (p *Pool) BalanceToken1() int64 { return p.balances.token1 }

// TickSpacing returns the permitted spacing between initialized ticks.
//
// Returns:
//   - int32: tick spacing configured for the pool.
func (p *Pool) TickSpacing() int32 { return p.tickSpacing }

// Slot0 returns the pool's current price, tick, slot0 lock metadata, and oracle cursor state.
//
// Returns:
//   - Slot0: current slot0 state, including the price, slot0 lock metadata, and observation metadata.
func (p *Pool) Slot0() Slot0 { return p.slot0 }

// Slot0SqrtPriceX96 returns the current square-root price in Q96 fixed-point form.
//
// Returns:
//   - *u256.Uint: stored sqrt(token1/token0) price scaled by 2^96.
func (p *Pool) Slot0SqrtPriceX96() *u256.Uint { return p.slot0.sqrtPriceX96 }

// Slot0Tick returns the current pool tick.
//
// Returns:
//   - int32: tick corresponding to the current pool price.
func (p *Pool) Slot0Tick() int32 { return p.slot0.tick }

// Slot0FeeProtocol returns the packed protocol-fee denominators from slot0.
//
// Returns:
//   - uint8: packed token0/token1 protocol-fee denominator configuration.
func (p *Pool) Slot0FeeProtocol() uint8 { return p.slot0.feeProtocol }

// Slot0Unlocked reports the stored `Slot0.unlocked` metadata flag.
// It is separate from the pool-wide `Unlocked` KV-store guard used for live
// reentrancy protection and is not the live lock state.
//
// Returns:
//   - bool: stored `Slot0.unlocked` metadata value.
func (p *Pool) Slot0Unlocked() bool { return p.slot0.unlocked }

// FeeGrowthGlobal0X128 returns cumulative token0 fee growth per unit of liquidity.
//
// Returns:
//   - *u256.Uint: token0 fee-growth accumulator scaled by 2^128.
func (p *Pool) FeeGrowthGlobal0X128() *u256.Uint { return p.feeGrowthGlobal0X128 }

// FeeGrowthGlobal1X128 returns cumulative token1 fee growth per unit of liquidity.
//
// Returns:
//   - *u256.Uint: token1 fee-growth accumulator scaled by 2^128.
func (p *Pool) FeeGrowthGlobal1X128() *u256.Uint { return p.feeGrowthGlobal1X128 }

// ProtocolFees returns protocol fees accrued in both pool tokens.
//
// Returns:
//   - TokenPair: token0 and token1 protocol-fee balances.
func (p *Pool) ProtocolFees() TokenPair { return p.protocolFees }

// ProtocolFeesToken0 returns protocol fees accrued in token0.
//
// Returns:
//   - int64: token0 amount reserved as protocol fees.
func (p *Pool) ProtocolFeesToken0() int64 { return p.protocolFees.token0 }

// ProtocolFeesToken1 returns protocol fees accrued in token1.
//
// Returns:
//   - int64: token1 amount reserved as protocol fees.
func (p *Pool) ProtocolFeesToken1() int64 { return p.protocolFees.token1 }

// Liquidity returns the pool's active liquidity for the current tick range.
//
// Returns:
//   - *u256.Uint: active liquidity amount.
func (p *Pool) Liquidity() *u256.Uint { return p.liquidity }

// Ticks returns the tree containing tick state keyed by encoded tick.
//
// Returns:
//   - *bptree.BPTree: pool tick storage tree.
func (p *Pool) Ticks() *bptree.BPTree { return p.ticks }

// TickBitmaps returns the map of initialized-tick bitmap words.
//
// Returns:
//   - map[int16]string: bitmap words keyed by signed word position.
func (p *Pool) TickBitmaps() map[int16]string { return p.tickBitmaps }

// Positions returns the tree containing aggregate position state by range key.
//
// Returns:
//   - *bptree.BPTree: pool position storage tree.
func (p *Pool) Positions() *bptree.BPTree { return p.positions }

// GetPosition returns the position information for key.
//
// Parameters:
//   - key: encoded lower/upper tick-range key to look up.
//
// Returns:
//   - PositionInfo: stored aggregate position for the key.
//   - error: non-nil when the key is absent or contains a value of the wrong type.
func (p *Pool) GetPosition(key string) (PositionInfo, error) {
	iPositionInfo := p.positions.Get(key)
	if iPositionInfo == nil {
		return PositionInfo{}, ufmt.Errorf("position %s not found", key)
	}

	positionInfo, ok := iPositionInfo.(PositionInfo)
	if !ok {
		return PositionInfo{}, ufmt.Errorf("position %s has invalid type", key)
	}

	return positionInfo, nil
}

// Pool Setters methods
// SetToken0Path stores the path of the pool's token0 asset.
//
// Parameters:
//   - token0Path: token0 asset path to store.
func (p *Pool) SetToken0Path(token0Path string) {
	p.token0Path = token0Path
}

// SetToken1Path stores the path of the pool's token1 asset.
//
// Parameters:
//   - token1Path: token1 asset path to store.
func (p *Pool) SetToken1Path(token1Path string) {
	p.token1Path = token1Path
}

// SetFee stores the pool's fee tier.
//
// Parameters:
//   - fee: fee tier to use for swaps in this pool.
func (p *Pool) SetFee(fee uint32) {
	p.fee = fee
}

// SetBalances replaces the pool's tracked balances for both tokens.
//
// Parameters:
//   - balances: token0 and token1 balances to store.
func (p *Pool) SetBalances(balances TokenPair) {
	p.balances = balances
}

// SetBalanceToken0 updates the pool's tracked token0 balance.
//
// Parameters:
//   - token0: new token0 balance.
func (p *Pool) SetBalanceToken0(token0 int64) {
	p.balances.token0 = token0
}

// SetBalanceToken1 updates the pool's tracked token1 balance.
//
// Parameters:
//   - token1: new token1 balance.
func (p *Pool) SetBalanceToken1(token1 int64) {
	p.balances.token1 = token1
}

// SetTickSpacing stores the permitted spacing between initialized ticks.
//
// Parameters:
//   - tickSpacing: tick spacing to configure for the pool.
func (p *Pool) SetTickSpacing(tickSpacing int32) {
	p.tickSpacing = tickSpacing
}

// SetSlot0 replaces the pool's current price, tick, slot0 lock metadata, and oracle cursor state.
//
// Parameters:
//   - slot0: slot0 state to store.
func (p *Pool) SetSlot0(slot0 Slot0) {
	p.slot0 = slot0
}

// SetFeeGrowthGlobal0X128 stores the token0 fee-growth accumulator.
//
// Parameters:
//   - feeGrowthGlobal0X128: token0 fee growth per liquidity unit, scaled by 2^128.
func (p *Pool) SetFeeGrowthGlobal0X128(feeGrowthGlobal0X128 *u256.Uint) {
	p.feeGrowthGlobal0X128 = u256.Zero().Set(feeGrowthGlobal0X128)
}

// SetFeeGrowthGlobal1X128 stores the token1 fee-growth accumulator.
//
// Parameters:
//   - feeGrowthGlobal1X128: token1 fee growth per liquidity unit, scaled by 2^128.
func (p *Pool) SetFeeGrowthGlobal1X128(feeGrowthGlobal1X128 *u256.Uint) {
	p.feeGrowthGlobal1X128 = u256.Zero().Set(feeGrowthGlobal1X128)
}

// SetProtocolFees replaces the pool's accrued protocol fees for both tokens.
//
// Parameters:
//   - protocolFees: token0 and token1 protocol-fee balances to store.
func (p *Pool) SetProtocolFees(protocolFees TokenPair) {
	p.protocolFees = protocolFees
}

// SetProtocolFeesToken0 updates the pool's accrued token0 protocol fees.
//
// Parameters:
//   - token0: new token0 protocol-fee balance.
func (p *Pool) SetProtocolFeesToken0(token0 int64) {
	p.protocolFees.token0 = token0
}

// SetProtocolFeesToken1 updates the pool's accrued token1 protocol fees.
//
// Parameters:
//   - token1: new token1 protocol-fee balance.
func (p *Pool) SetProtocolFeesToken1(token1 int64) {
	p.protocolFees.token1 = token1
}

// SetLiquidity stores the pool's active liquidity for the current tick range.
//
// Parameters:
//   - liquidity: active liquidity amount to store.
func (p *Pool) SetLiquidity(liquidity *u256.Uint) {
	p.liquidity = u256.Zero().Set(liquidity)
}

// SetTicks replaces the tree containing pool tick state.
//
// Parameters:
//   - ticks: tick storage tree to use.
func (p *Pool) SetTicks(ticks *bptree.BPTree) {
	p.ticks = ticks
}

// SetTickBitmap stores one initialized-tick bitmap word.
//
// Parameters:
//   - wordPos: signed bitmap word position.
//   - tickBitmap: encoded bitmap bits for that word.
func (p *Pool) SetTickBitmap(wordPos int16, tickBitmap string) {
	p.tickBitmaps[wordPos] = tickBitmap
}

// DeleteTickBitmap deletes the tick bitmap for the given word position.
//
// Parameters:
//   - wordPos: signed bitmap word position to remove.
func (p *Pool) DeleteTickBitmap(wordPos int16) {
	delete(p.tickBitmaps, wordPos)
}

// SetTickBitmaps replaces the map of initialized-tick bitmap words.
//
// Parameters:
//   - tickBitmaps: bitmap words keyed by signed word position.
func (p *Pool) SetTickBitmaps(tickBitmaps map[int16]string) {
	p.tickBitmaps = tickBitmaps
}

// SetPositions replaces the tree containing aggregate position state.
//
// Parameters:
//   - positions: position storage tree to use.
func (p *Pool) SetPositions(positions *bptree.BPTree) {
	p.positions = positions
}

// SetPosition stores position information under an encoded range key.
//
// Parameters:
//   - posKey: encoded lower/upper tick-range key.
//   - positionInfo: aggregate position state to store.
func (p *Pool) SetPosition(posKey string, positionInfo PositionInfo) {
	p.positions.Set(posKey, positionInfo)
}

// HasTick reports whether a tick entry exists in the pool's tick tree.
//
// Parameters:
//   - tick: tick index to check.
//
// Returns:
//   - bool: true when the encoded tick is present; false otherwise.
func (p *Pool) HasTick(tick int32) bool {
	tickKey := EncodeTickKey(tick)
	return p.ticks.Has(tickKey)
}

// GetTick returns the state stored for a tick.
//
// Parameters:
//   - tick: tick index to look up.
//
// Returns:
//   - TickInfo: stored tick state.
//   - error: non-nil when the tick is absent; a present value of the wrong type causes a panic.
func (p *Pool) GetTick(tick int32) (TickInfo, error) {
	tickKey := EncodeTickKey(tick)

	iTickInfo := p.ticks.Get(tickKey)
	if iTickInfo == nil {
		return TickInfo{}, ufmt.Errorf("tick %d not found", tick)
	}

	tickInfo, ok := iTickInfo.(TickInfo)
	if !ok {
		panic(ufmt.Sprintf("failed to cast tickInfo to TickInfo: %T", iTickInfo))
	}

	return tickInfo, nil
}

// SetTick stores tick state under its encoded tick key.
//
// Parameters:
//   - tick: tick index to store.
//   - tickInfo: tick state associated with the index.
func (p *Pool) SetTick(tick int32, tickInfo TickInfo) {
	tickKey := EncodeTickKey(tick)
	p.ticks.Set(tickKey, tickInfo)
}

// DeleteTick removes the tick state for the given tick index.
//
// Parameters:
//   - tick: tick index to remove.
func (p *Pool) DeleteTick(tick int32) {
	tickKey := EncodeTickKey(tick)
	p.ticks.Remove(tickKey)
}

// IterateTicks visits pool ticks in the inclusive range [startTick, endTick].
// Iteration stops when the callback returns true.
//
// Parameters:
//   - startTick: first tick index in the inclusive range.
//   - endTick: last tick index in the inclusive range.
//   - fn: callback receiving each decoded tick and its state; return true to stop iteration.
func (p *Pool) IterateTicks(startTick int32, endTick int32, fn func(tick int32, tickInfo TickInfo) bool) {
	startTickKey := EncodeTickKey(startTick)
	endTickKey := EncodeTickKey(endTick + 1) // endTick inclusive

	p.ticks.Iterate(startTickKey, endTickKey, func(key string, value any) bool {
		tick := DecodeTickKey(key)

		tickInfo, ok := value.(TickInfo)
		if !ok {
			return false
		}

		return fn(tick, tickInfo)
	})
}

// Clone copies a pool's own fields and leaves its collections nil: ticks,
// tickBitmaps, and positions are not copied. Oracle observations are stored
// separately from Pool.
//
// The copy is shallow because the read-only pool view clones every entry a
// caller reads, so copying the collections would walk the whole tick tree for
// each entry on a page. Read them through their own lookups instead:
// GetTickInfo / GetInitializedTicksInRange for ticks, GetTickBitmaps for the
// bitmaps, GetPoolPositions for positions, and GetSlot0 / GetObservationAt for
// oracle metadata and entries. A caller that needs a working copy of a
// collection -- DrySwap is the only one -- assembles it from those getters.
//
// Returns:
//   - *Pool: shallow pool copy with scalar state and cloned numeric values; nil when the receiver is nil.
func (p *Pool) Clone() *Pool {
	if p == nil {
		return nil
	}

	return &Pool{
		token0Path:           p.token0Path,
		token1Path:           p.token1Path,
		fee:                  p.fee,
		tickSpacing:          p.tickSpacing,
		slot0:                p.slot0.Clone(),
		balances:             p.balances,
		protocolFees:         p.protocolFees,
		feeGrowthGlobal0X128: p.feeGrowthGlobal0X128.Clone(),
		feeGrowthGlobal1X128: p.feeGrowthGlobal1X128.Clone(),
		liquidity:            p.liquidity.Clone(),
		ticks:                nil,
		tickBitmaps:          nil,
		positions:            nil,
	}
}

// NewPool constructs a pool with the supplied token pair, fee, price, and tick configuration.
//
// Parameters:
//   - token0Path: path of the pool's token0 asset.
//   - token1Path: path of the pool's token1 asset.
//   - fee: fee tier used by swaps.
//   - sqrtPriceX96: initial sqrt(token1/token0) price scaled by 2^96.
//   - tickSpacing: spacing between initialized ticks.
//   - tick: initial current tick.
//   - slot0FeeProtocol: packed protocol-fee denominator configuration for slot0.
//
// Returns:
//   - *Pool: initialized pool with empty balances, fee growth, ticks, bitmaps, and positions.
func NewPool(
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 *u256.Uint,
	tickSpacing int32,
	tick int32,
	slot0FeeProtocol uint8,
) *Pool {
	slot0 := NewSlot0(sqrtPriceX96, tick, slot0FeeProtocol, true)

	return &Pool{
		token0Path:           token0Path,
		token1Path:           token1Path,
		balances:             NewTokenPair(),
		fee:                  fee,
		tickSpacing:          tickSpacing,
		slot0:                slot0,
		feeGrowthGlobal0X128: u256.Zero(),
		feeGrowthGlobal1X128: u256.Zero(),
		protocolFees:         NewTokenPair(),
		liquidity:            u256.Zero(),
		ticks:                bptree.NewBPTreeN(32),
		tickBitmaps:          make(map[int16]string),
		positions:            bptree.NewBPTreeN(16),
	}
}

// NewPoolsTree creates the BPTree used to store pools by pool path.
//
// Returns:
//   - *bptree.BPTree: empty pool storage tree with fanout 32.
func NewPoolsTree() *bptree.BPTree {
	return bptree.NewBPTreeN(32)
}

// NewPoolTicksTree creates a BPTree for storing pool tick info (fanout 32),
// owned by the pool domain realm so leaf-slot writes are not readonly tainted.
//
// Returns:
//   - *bptree.BPTree: empty tick storage tree with fanout 32.
func NewPoolTicksTree() *bptree.BPTree {
	return bptree.NewBPTreeN(32)
}

// NewPoolPositionsTree creates a BPTree for storing pool position info (fanout 16),
// owned by the pool domain realm so leaf-slot writes are not readonly tainted.
//
// Returns:
//   - *bptree.BPTree: empty position storage tree with fanout 16.
func NewPoolPositionsTree() *bptree.BPTree {
	return bptree.NewBPTreeN(16)
}

type TokenPair struct {
	token0, token1 int64
}

// NewTokenPair creates a token-pair balance value initialized to zero.
//
// Returns:
//   - TokenPair: zero token0 and token1 balances.
func NewTokenPair() TokenPair {
	return TokenPair{
		token0: 0,
		token1: 0,
	}
}

// Token0 returns the token0 amount in the pair.
//
// Returns:
//   - int64: stored token0 amount.
func (p *TokenPair) Token0() int64 { return p.token0 }

// Token1 returns the token1 amount in the pair.
//
// Returns:
//   - int64: stored token1 amount.
func (p *TokenPair) Token1() int64 { return p.token1 }

// SetToken0 updates the token0 amount in the pair.
//
// Parameters:
//   - token0: token0 amount to store.
func (p *TokenPair) SetToken0(token0 int64) { p.token0 = token0 }

// SetToken1 updates the token1 amount in the pair.
//
// Parameters:
//   - token1: token1 amount to store.
func (p *TokenPair) SetToken1(token1 int64) { p.token1 = token1 }

// Slot0 mirrors Uniswap V3's slot0(): current price/tick/protocol-fee/slot0
// lock metadata and the oracle cursor/capacity metadata. Its lock flag is
// separate from the pool-wide `Unlocked` KV-store guard.
type Slot0 struct {
	sqrtPriceX96               *u256.Uint // current price of the pool as a sqrt(token1/token0) Q96 value
	tick                       int32      // current tick of the pool, i.e according to the last tick transition that was run
	feeProtocol                uint8      // packed protocol-fee denominators: token0 low nibble, token1 high nibble
	unlocked                   bool       // slot0 lock metadata, not the pool-wide reentrancy guard
	observationIndex           uint16     // the index of the most-recently written observation
	observationCardinality     uint16     // the current maximum number of observations stored
	observationCardinalityNext uint16     // the next maximum number of observations to store
}

// SqrtPriceX96 returns a copy of the current sqrt price in Q96 fixed-point form.
//
// Returns:
//   - *u256.Uint: cloned sqrt(token1/token0) price scaled by 2^96.
func (s *Slot0) SqrtPriceX96() *u256.Uint { return s.sqrtPriceX96.Clone() }

// Tick returns the current pool tick recorded in slot0.
//
// Returns:
//   - int32: current tick.
func (s *Slot0) Tick() int32 { return s.tick }

// FeeProtocol returns the packed protocol-fee denominators in slot0.
//
// Returns:
//   - uint8: packed token0/token1 protocol-fee denominator configuration.
func (s *Slot0) FeeProtocol() uint8 { return s.feeProtocol }

// Unlocked reports the stored `Slot0.unlocked` metadata flag.
// It is separate from the pool-wide `Unlocked` KV-store guard used for live
// reentrancy protection.
//
// Returns:
//   - bool: stored `Slot0.unlocked` metadata value.
func (s *Slot0) Unlocked() bool { return s.unlocked }

// ObservationIndex returns the index of the most recently written observation.
//
// Returns:
//   - uint16: current observation ring-buffer index.
func (s *Slot0) ObservationIndex() uint16 { return s.observationIndex }

// ObservationCardinality returns the number of observation slots currently available.
//
// Returns:
//   - uint16: current observation capacity.
func (s *Slot0) ObservationCardinality() uint16 { return s.observationCardinality }

// ObservationCardinalityNext returns the requested future observation capacity.
//
// Returns:
//   - uint16: next observation capacity to use when the ring grows.
func (s *Slot0) ObservationCardinalityNext() uint16 { return s.observationCardinalityNext }

// Clone returns a value-type copy of Slot0 that shares no mutable state with
// the original, so callers cannot reach back into pool internals through the
// returned sqrtPriceX96 pointer.
//
// Returns:
//   - Slot0: value copy with a cloned sqrt-price pointer.
func (s *Slot0) Clone() Slot0 {
	return Slot0{
		sqrtPriceX96:               s.sqrtPriceX96.Clone(),
		tick:                       s.tick,
		feeProtocol:                s.feeProtocol,
		unlocked:                   s.unlocked,
		observationIndex:           s.observationIndex,
		observationCardinality:     s.observationCardinality,
		observationCardinalityNext: s.observationCardinalityNext,
	}
}

// SetSqrtPriceX96 updates the slot0 sqrt price.
//
// Parameters:
//   - sqrtPriceX96: sqrt(token1/token0) price scaled by 2^96; it is cloned before storage.
func (s *Slot0) SetSqrtPriceX96(sqrtPriceX96 *u256.Uint) { s.sqrtPriceX96 = sqrtPriceX96.Clone() }

// SetTick updates the current slot0 tick.
//
// Parameters:
//   - tick: current pool tick to store.
func (s *Slot0) SetTick(tick int32) { s.tick = tick }

// SetFeeProtocol updates the packed slot0 protocol-fee denominators.
//
// Parameters:
//   - feeProtocol: packed token0/token1 protocol-fee denominator configuration.
func (s *Slot0) SetFeeProtocol(feeProtocol uint8) { s.feeProtocol = feeProtocol }

// SetUnlocked updates the stored `Slot0.unlocked` metadata flag.
// It does not update the pool-wide `Unlocked` KV-store guard.
//
// Parameters:
//   - unlocked: Slot0 metadata value to store.
func (s *Slot0) SetUnlocked(unlocked bool) { s.unlocked = unlocked }

// SetObservationIndex updates the index of the most recently written observation.
//
// Parameters:
//   - observationIndex: observation ring-buffer index to store.
func (s *Slot0) SetObservationIndex(observationIndex uint16) {
	s.observationIndex = observationIndex
}

// SetObservationCardinality updates the current observation capacity.
//
// Parameters:
//   - observationCardinality: current number of observation slots available.
func (s *Slot0) SetObservationCardinality(observationCardinality uint16) {
	s.observationCardinality = observationCardinality
}

// SetObservationCardinalityNext updates the requested future observation capacity.
//
// Parameters:
//   - observationCardinalityNext: next capacity to use when the ring grows.
func (s *Slot0) SetObservationCardinalityNext(observationCardinalityNext uint16) {
	s.observationCardinalityNext = observationCardinalityNext
}

// NewSlot0 constructs slot0 with the supplied price, tick, protocol fee, and
// slot0 lock metadata. Observation metadata starts with index zero and
// cardinality one.
//
// Parameters:
//   - sqrtPriceX96: initial sqrt(token1/token0) price scaled by 2^96.
//   - tick: initial current pool tick.
//   - feeProtocol: packed token0/token1 protocol-fee denominator configuration.
//   - unlocked: initial Slot0 metadata value; it does not set the pool-wide
//     `Unlocked` KV-store guard.
//
// Returns:
//   - Slot0: initialized slot0 value with one observation slot.
func NewSlot0(
	sqrtPriceX96 *u256.Uint,
	tick int32,
	feeProtocol uint8,
	unlocked bool,
) Slot0 {
	return Slot0{
		sqrtPriceX96:               sqrtPriceX96.Clone(),
		tick:                       tick,
		feeProtocol:                feeProtocol,
		unlocked:                   unlocked,
		observationIndex:           0,
		observationCardinality:     1,
		observationCardinalityNext: 1,
	}
}

// TickInfo stores information about a specific tick in the pool.
// TIcks represent discrete price points that can be used as boundaries for positions.
type TickInfo struct {
	liquidityGross string // total position liquidity that references this tick
	liquidityNet   string // amount of net liquidity added (subtracted) when tick is crossed from left to right (right to left)

	// fee growth per unit of liquidity on the _other_ side of this tick (relative to the current tick)
	// only has relative meaning, not absolute — the value depends on when the tick is initialized
	feeGrowthOutside0X128 string
	feeGrowthOutside1X128 string

	tickCumulativeOutside int64 // cumulative tick value on the other side of the tick

	// the seconds per unit of liquidity on the _other_ side of this tick (relative to the current tick)
	// only has relative meaning, not absolute — the value depends on when the tick is initialized
	secondsPerLiquidityOutsideX128 string

	// the seconds spent on the other side of the tick (relative to the current tick)
	// only has relative meaning, not absolute — the value depends on when the tick is initialized
	secondsOutside uint32

	initialized bool // whether the tick is initialized
}

// TickInfo Getters methods
// LiquidityGross returns total position liquidity referencing this tick.
//
// Returns:
//   - string: gross liquidity encoded as a decimal string.
func (t *TickInfo) LiquidityGross() string { return t.liquidityGross }

// LiquidityNet returns net liquidity applied when this tick is crossed.
//
// Returns:
//   - string: signed net liquidity encoded as a decimal string.
func (t *TickInfo) LiquidityNet() string { return t.liquidityNet }

// FeeGrowthOutside0X128 returns token0 fee growth on the side of this tick opposite the current tick.
//
// Returns:
//   - string: token0 outside fee-growth accumulator scaled by 2^128.
func (t *TickInfo) FeeGrowthOutside0X128() string { return t.feeGrowthOutside0X128 }

// FeeGrowthOutside1X128 returns token1 fee growth on the side of this tick opposite the current tick.
//
// Returns:
//   - string: token1 outside fee-growth accumulator scaled by 2^128.
func (t *TickInfo) FeeGrowthOutside1X128() string { return t.feeGrowthOutside1X128 }

// SecondsPerLiquidityOutsideX128 returns seconds per liquidity outside this tick.
//
// Returns:
//   - string: outside seconds-per-liquidity accumulator scaled by 2^128.
func (t *TickInfo) SecondsPerLiquidityOutsideX128() string {
	return t.secondsPerLiquidityOutsideX128
}

// SecondsOutside returns the time spent on the side of this tick opposite the current tick.
//
// Returns:
//   - uint32: seconds accumulated outside the tick.
func (t *TickInfo) SecondsOutside() uint32 { return t.secondsOutside }

// Initialized reports whether this tick has active initialized state.
//
// Returns:
//   - bool: true when the tick is initialized; false otherwise.
func (t *TickInfo) Initialized() bool { return t.initialized }

// TickCumulativeOutside returns cumulative tick value on the side opposite the current tick.
//
// Returns:
//   - int64: outside cumulative tick value.
func (t *TickInfo) TickCumulativeOutside() int64 { return t.tickCumulativeOutside }

// TickInfo Setters methods
// SetLiquidityGross stores total position liquidity referencing this tick.
//
// Parameters:
//   - liquidityGross: gross liquidity encoded as a decimal string.
func (t *TickInfo) SetLiquidityGross(liquidityGross string) {
	t.liquidityGross = liquidityGross
}

// SetLiquidityNet stores the net liquidity change applied when crossing this tick.
//
// Parameters:
//   - liquidityNet: signed net liquidity encoded as a decimal string.
func (t *TickInfo) SetLiquidityNet(liquidityNet string) {
	t.liquidityNet = liquidityNet
}

// SetFeeGrowthOutside0X128 stores token0 outside fee growth for this tick.
//
// Parameters:
//   - feeGrowthOutside0X128: token0 outside fee growth scaled by 2^128, encoded as a decimal string.
func (t *TickInfo) SetFeeGrowthOutside0X128(feeGrowthOutside0X128 string) {
	t.feeGrowthOutside0X128 = feeGrowthOutside0X128
}

// SetFeeGrowthOutside1X128 stores token1 outside fee growth for this tick.
//
// Parameters:
//   - feeGrowthOutside1X128: token1 outside fee growth scaled by 2^128, encoded as a decimal string.
func (t *TickInfo) SetFeeGrowthOutside1X128(feeGrowthOutside1X128 string) {
	t.feeGrowthOutside1X128 = feeGrowthOutside1X128
}

// SetSecondsPerLiquidityOutsideX128 stores outside seconds-per-liquidity growth.
//
// Parameters:
//   - secondsPerLiquidityOutsideX128: outside seconds per liquidity scaled by 2^128, encoded as a decimal string.
func (t *TickInfo) SetSecondsPerLiquidityOutsideX128(secondsPerLiquidityOutsideX128 string) {
	t.secondsPerLiquidityOutsideX128 = secondsPerLiquidityOutsideX128
}

// SetSecondsOutside stores the seconds accumulated outside this tick.
//
// Parameters:
//   - secondsOutside: elapsed seconds outside the tick.
func (t *TickInfo) SetSecondsOutside(secondsOutside uint32) {
	t.secondsOutside = secondsOutside
}

// SetInitialized updates whether this tick is initialized.
//
// Parameters:
//   - initialized: true to mark the tick initialized, false otherwise.
func (t *TickInfo) SetInitialized(initialized bool) {
	t.initialized = initialized
}

// SetTickCumulativeOutside stores cumulative tick value outside this tick.
//
// Parameters:
//   - tickCumulativeOutside: cumulative tick value on the opposite side.
func (t *TickInfo) SetTickCumulativeOutside(tickCumulativeOutside int64) {
	t.tickCumulativeOutside = tickCumulativeOutside
}

// Clone returns an independent value copy of this tick's stored state.
//
// Returns:
//   - TickInfo: copied liquidity, fee-growth, time, and initialization fields.
func (t *TickInfo) Clone() TickInfo {
	return TickInfo{
		feeGrowthOutside0X128:          t.feeGrowthOutside0X128,
		feeGrowthOutside1X128:          t.feeGrowthOutside1X128,
		liquidityGross:                 t.liquidityGross,
		liquidityNet:                   t.liquidityNet,
		tickCumulativeOutside:          t.tickCumulativeOutside,
		secondsPerLiquidityOutsideX128: t.secondsPerLiquidityOutsideX128,
		secondsOutside:                 t.secondsOutside,
		initialized:                    t.initialized,
	}
}

// NewTickInfo creates an uninitialized tick state with zero accumulators.
//
// Returns:
//   - TickInfo: default tick state with all numeric fields zero and Initialized false.
func NewTickInfo() TickInfo {
	return TickInfo{
		liquidityGross:                 "0",
		liquidityNet:                   "0",
		feeGrowthOutside0X128:          "0",
		feeGrowthOutside1X128:          "0",
		secondsPerLiquidityOutsideX128: "0",
		secondsOutside:                 0,
		initialized:                    false,
		tickCumulativeOutside:          0,
	}
}

// PositionInfo stores aggregate liquidity, fee-growth checkpoints, and tokens
// owed for one pool-scoped lower/upper tick key.
type PositionInfo struct {
	liquidity                string // aggregate liquidity for this tick-range key
	feeGrowthInside0LastX128 string // fee growth per unit of liquidity for token0 as of last update
	feeGrowthInside1LastX128 string // fee growth per unit of liquidity for token1 as of last update

	// accumulated token0 amount waiting to be collected (principal or swap fee)
	tokensOwed0 int64

	// accumulated token1 amount waiting to be collected (principal or swap fee)
	tokensOwed1 int64
}

// Liquidity returns aggregate liquidity for this position range.
//
// Returns:
//   - string: position liquidity encoded as a decimal string.
func (p *PositionInfo) Liquidity() string { return p.liquidity }

// FeeGrowthInside0LastX128 returns the token0 fee-growth checkpoint for this position.
//
// Returns:
//   - string: token0 inside fee-growth checkpoint scaled by 2^128.
func (p *PositionInfo) FeeGrowthInside0LastX128() string { return p.feeGrowthInside0LastX128 }

// FeeGrowthInside1LastX128 returns the token1 fee-growth checkpoint for this position.
//
// Returns:
//   - string: token1 inside fee-growth checkpoint scaled by 2^128.
func (p *PositionInfo) FeeGrowthInside1LastX128() string { return p.feeGrowthInside1LastX128 }

// TokensOwed0 returns token0 accumulated for this position.
//
// Returns:
//   - int64: token0 principal or fee amount awaiting collection.
func (p *PositionInfo) TokensOwed0() int64 { return p.tokensOwed0 }

// TokensOwed1 returns token1 accumulated for this position.
//
// Returns:
//   - int64: token1 principal or fee amount awaiting collection.
func (p *PositionInfo) TokensOwed1() int64 { return p.tokensOwed1 }

// SetLiquidity updates aggregate liquidity for this position range.
//
// Parameters:
//   - liquidity: position liquidity encoded as a decimal string.
func (p *PositionInfo) SetLiquidity(liquidity string) {
	p.liquidity = liquidity
}

// SetFeeGrowthInside0LastX128 updates the token0 fee-growth checkpoint.
//
// Parameters:
//   - feeGrowthInside0LastX128: token0 inside fee-growth checkpoint scaled by 2^128, encoded as a decimal string.
func (p *PositionInfo) SetFeeGrowthInside0LastX128(feeGrowthInside0LastX128 string) {
	p.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
}

// SetFeeGrowthInside1LastX128 updates the token1 fee-growth checkpoint.
//
// Parameters:
//   - feeGrowthInside1LastX128: token1 inside fee-growth checkpoint scaled by 2^128, encoded as a decimal string.
func (p *PositionInfo) SetFeeGrowthInside1LastX128(feeGrowthInside1LastX128 string) {
	p.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
}

// SetTokensOwed0 updates token0 accumulated for this position.
//
// Parameters:
//   - tokensOwed0: token0 principal or fee amount awaiting collection.
func (p *PositionInfo) SetTokensOwed0(tokensOwed0 int64) {
	p.tokensOwed0 = tokensOwed0
}

// SetTokensOwed1 updates token1 accumulated for this position.
//
// Parameters:
//   - tokensOwed1: token1 principal or fee amount awaiting collection.
func (p *PositionInfo) SetTokensOwed1(tokensOwed1 int64) {
	p.tokensOwed1 = tokensOwed1
}

// NewPositionInfo creates a zeroed position state for a tick range.
//
// Returns:
//   - PositionInfo: position with zero liquidity, fee-growth checkpoints, and owed tokens.
func NewPositionInfo() PositionInfo {
	return PositionInfo{
		liquidity:                "0",
		feeGrowthInside0LastX128: "0",
		feeGrowthInside1LastX128: "0",
		tokensOwed0:              0,
		tokensOwed1:              0,
	}
}

// NewDefaultFeeAmountTickSpacing returns the default tick spacing for each supported fee tier.
//
// Returns:
//   - map[uint32]int32: fee-tier to tick-spacing mapping for 100, 500, 3000, and 10000 tiers.
func NewDefaultFeeAmountTickSpacing() map[uint32]int32 {
	return map[uint32]int32{
		100:   1,
		500:   10,
		3000:  60,
		10000: 200,
	}
}
