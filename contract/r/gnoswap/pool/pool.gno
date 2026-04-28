package pool

import (
	"time"

	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256"
)

// type Pool describes a single Pool's state
// A pool is identificed with a unique key (token0, token1, fee), where token0 < token1
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
	ticks                *bptree.BPTree    // tick(int32) -> TickInfo
	tickBitmaps          map[int16]string // tick(wordPos)(int16) -> bitMap(tickWord ^ mask)(string)
	positions            *bptree.BPTree    // maps the key (caller, lower tick, upper tick) to a unique position

	observationState *ObservationState // oracle state with historical observations
}

// Pool Getters methods
func (p *Pool) PoolPath() string                    { return GetPoolPath(p.token0Path, p.token1Path, p.fee) }
func (p *Pool) Token0Path() string                  { return p.token0Path }
func (p *Pool) Token1Path() string                  { return p.token1Path }
func (p *Pool) Fee() uint32                         { return p.fee }
func (p *Pool) Balances() TokenPair                 { return p.balances }
func (p *Pool) BalanceToken0() int64                { return p.balances.token0 }
func (p *Pool) BalanceToken1() int64                { return p.balances.token1 }
func (p *Pool) TickSpacing() int32                  { return p.tickSpacing }
func (p *Pool) Slot0() Slot0                        { return p.slot0 }
func (p *Pool) Slot0SqrtPriceX96() *u256.Uint       { return p.slot0.sqrtPriceX96 }
func (p *Pool) Slot0Tick() int32                    { return p.slot0.tick }
func (p *Pool) Slot0FeeProtocol() uint8             { return p.slot0.feeProtocol }
func (p *Pool) Slot0Unlocked() bool                 { return p.slot0.unlocked }
func (p *Pool) FeeGrowthGlobal0X128() *u256.Uint    { return p.feeGrowthGlobal0X128 }
func (p *Pool) FeeGrowthGlobal1X128() *u256.Uint    { return p.feeGrowthGlobal1X128 }
func (p *Pool) ProtocolFees() TokenPair             { return p.protocolFees }
func (p *Pool) ProtocolFeesToken0() int64           { return p.protocolFees.token0 }
func (p *Pool) ProtocolFeesToken1() int64           { return p.protocolFees.token1 }
func (p *Pool) Liquidity() *u256.Uint               { return p.liquidity }
func (p *Pool) Ticks() *bptree.BPTree                { return p.ticks }
func (p *Pool) TickBitmaps() map[int16]string       { return p.tickBitmaps }
func (p *Pool) Positions() *bptree.BPTree            { return p.positions }
func (p *Pool) ObservationState() *ObservationState { return p.observationState }

// Pool Setters methods
func (p *Pool) SetToken0Path(token0Path string) {
	p.token0Path = token0Path
}

func (p *Pool) SetToken1Path(token1Path string) {
	p.token1Path = token1Path
}

func (p *Pool) SetFee(fee uint32) {
	p.fee = fee
}

func (p *Pool) SetBalances(balances TokenPair) {
	p.balances = balances
}

func (p *Pool) SetBalanceToken0(token0 int64) {
	p.balances.token0 = token0
}

func (p *Pool) SetBalanceToken1(token1 int64) {
	p.balances.token1 = token1
}

func (p *Pool) SetTickSpacing(tickSpacing int32) {
	p.tickSpacing = tickSpacing
}

func (p *Pool) SetSlot0(slot0 Slot0) {
	p.slot0 = slot0
}

func (p *Pool) SetFeeGrowthGlobal0X128(feeGrowthGlobal0X128 *u256.Uint) {
	p.feeGrowthGlobal0X128 = feeGrowthGlobal0X128
}

func (p *Pool) SetFeeGrowthGlobal1X128(feeGrowthGlobal1X128 *u256.Uint) {
	p.feeGrowthGlobal1X128 = feeGrowthGlobal1X128
}

func (p *Pool) SetProtocolFees(protocolFees TokenPair) {
	p.protocolFees = protocolFees
}

func (p *Pool) SetProtocolFeesToken0(token0 int64) {
	p.protocolFees.token0 = token0
}

func (p *Pool) SetProtocolFeesToken1(token1 int64) {
	p.protocolFees.token1 = token1
}

func (p *Pool) SetLiquidity(liquidity *u256.Uint) {
	p.liquidity = liquidity
}

func (p *Pool) SetTicks(ticks *bptree.BPTree) {
	p.ticks = ticks
}

func (p *Pool) SetTickBitmaps(tickBitmaps map[int16]string) {
	p.tickBitmaps = tickBitmaps
}

func (p *Pool) SetPositions(positions *bptree.BPTree) {
	p.positions = positions
}

func (p *Pool) SetObservationState(observationState *ObservationState) {
	p.observationState = observationState
}

func (p *Pool) HasTick(tick int32) bool {
	tickKey := EncodeTickKey(tick)
	return p.ticks.Has(tickKey)
}

func (p *Pool) GetTick(tick int32) (TickInfo, error) {
	tickKey := EncodeTickKey(tick)

	iTickInfo, ok := p.ticks.Get(tickKey)
	if !ok {
		return TickInfo{}, ufmt.Errorf("tick %d not found", tick)
	}

	tickInfo, ok := iTickInfo.(TickInfo)
	if !ok {
		panic(ufmt.Sprintf("failed to cast tickInfo to TickInfo: %T", iTickInfo))
	}

	return tickInfo, nil
}

func (p *Pool) SetTick(tick int32, tickInfo TickInfo) {
	tickKey := EncodeTickKey(tick)
	p.ticks.Set(tickKey, tickInfo)
}

func (p *Pool) DeleteTick(tick int32) {
	tickKey := EncodeTickKey(tick)
	p.ticks.Remove(tickKey)
}

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

func (p *Pool) Clone() *Pool {
	return &Pool{
		token0Path:  p.token0Path,
		token1Path:  p.token1Path,
		fee:         p.fee,
		tickSpacing: p.tickSpacing,
		slot0: Slot0{
			sqrtPriceX96: p.slot0.sqrtPriceX96.Clone(),
			tick:         p.slot0.tick,
			feeProtocol:  p.slot0.feeProtocol,
			unlocked:     p.slot0.unlocked,
		},
		balances:             p.balances,
		protocolFees:         p.protocolFees,
		feeGrowthGlobal0X128: p.feeGrowthGlobal0X128.Clone(),
		feeGrowthGlobal1X128: p.feeGrowthGlobal1X128.Clone(),
		liquidity:            p.liquidity.Clone(),
		ticks:                clonePoolTicks(p.ticks),
		tickBitmaps:          clonePoolTickBitmaps(p.tickBitmaps),
		positions:            bptree.NewBPTreeN(16),
		observationState:     NewObservationState(time.Now().Unix()),
	}
}

func NewPool(
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 *u256.Uint,
	tickSpacing int32,
	tick int32,
	slot0FeeProtocol uint8,
) *Pool {
	slot0 := newSlot0(sqrtPriceX96, tick, slot0FeeProtocol, true)

	return &Pool{
		token0Path:           token0Path,
		token1Path:           token1Path,
		balances:             newTokenPair(),
		fee:                  fee,
		tickSpacing:          tickSpacing,
		slot0:                slot0,
		feeGrowthGlobal0X128: u256.Zero(),
		feeGrowthGlobal1X128: u256.Zero(),
		protocolFees:         newTokenPair(),
		liquidity:            u256.Zero(),
		ticks:                bptree.NewBPTreeN(32),
		tickBitmaps:          make(map[int16]string),
		positions:            bptree.NewBPTreeN(16),
		observationState:     NewObservationState(time.Now().Unix()),
	}
}

type TokenPair struct {
	token0, token1 int64
}

func newTokenPair() TokenPair {
	return TokenPair{
		token0: 0,
		token1: 0,
	}
}

func (p *TokenPair) Token0() int64          { return p.token0 }
func (p *TokenPair) Token1() int64          { return p.token1 }
func (p *TokenPair) SetToken0(token0 int64) { p.token0 = token0 }
func (p *TokenPair) SetToken1(token1 int64) { p.token1 = token1 }

type Slot0 struct {
	sqrtPriceX96 *u256.Uint // current price of the pool as a sqrt(token1/token0) Q96 value
	tick         int32      // current tick of the pool, i.e according to the last tick transition that was run
	feeProtocol  uint8      // protocol fee for both tokens of the pool
	unlocked     bool       // whether the pool is currently locked to reentrancy
}

func (s *Slot0) SqrtPriceX96() *u256.Uint { return s.sqrtPriceX96 }
func (s *Slot0) Tick() int32              { return s.tick }
func (s *Slot0) FeeProtocol() uint8       { return s.feeProtocol }
func (s *Slot0) Unlocked() bool           { return s.unlocked }

func (s *Slot0) SetSqrtPriceX96(sqrtPriceX96 *u256.Uint) { s.sqrtPriceX96 = sqrtPriceX96 }
func (s *Slot0) SetTick(tick int32)                      { s.tick = tick }
func (s *Slot0) SetFeeProtocol(feeProtocol uint8)        { s.feeProtocol = feeProtocol }
func (s *Slot0) SetUnlocked(unlocked bool)               { s.unlocked = unlocked }

func newSlot0(
	sqrtPriceX96 *u256.Uint,
	tick int32,
	feeProtocol uint8,
	unlocked bool,
) Slot0 {
	return Slot0{
		sqrtPriceX96: sqrtPriceX96.Clone(),
		tick:         tick,
		feeProtocol:  feeProtocol,
		unlocked:     unlocked,
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
func (t *TickInfo) LiquidityGross() string        { return t.liquidityGross }
func (t *TickInfo) LiquidityNet() string          { return t.liquidityNet }
func (t *TickInfo) FeeGrowthOutside0X128() string { return t.feeGrowthOutside0X128 }
func (t *TickInfo) FeeGrowthOutside1X128() string { return t.feeGrowthOutside1X128 }
func (t *TickInfo) SecondsPerLiquidityOutsideX128() string {
	return t.secondsPerLiquidityOutsideX128
}
func (t *TickInfo) SecondsOutside() uint32       { return t.secondsOutside }
func (t *TickInfo) Initialized() bool            { return t.initialized }
func (t *TickInfo) TickCumulativeOutside() int64 { return t.tickCumulativeOutside }

// TickInfo Setters methods
func (t *TickInfo) SetLiquidityGross(liquidityGross string) {
	t.liquidityGross = liquidityGross
}

func (t *TickInfo) SetLiquidityNet(liquidityNet string) {
	t.liquidityNet = liquidityNet
}

func (t *TickInfo) SetFeeGrowthOutside0X128(feeGrowthOutside0X128 string) {
	t.feeGrowthOutside0X128 = feeGrowthOutside0X128
}

func (t *TickInfo) SetFeeGrowthOutside1X128(feeGrowthOutside1X128 string) {
	t.feeGrowthOutside1X128 = feeGrowthOutside1X128
}

func (t *TickInfo) SetSecondsPerLiquidityOutsideX128(secondsPerLiquidityOutsideX128 string) {
	t.secondsPerLiquidityOutsideX128 = secondsPerLiquidityOutsideX128
}

func (t *TickInfo) SetSecondsOutside(secondsOutside uint32) {
	t.secondsOutside = secondsOutside
}

func (t *TickInfo) SetInitialized(initialized bool) {
	t.initialized = initialized
}

func (t *TickInfo) SetTickCumulativeOutside(tickCumulativeOutside int64) {
	t.tickCumulativeOutside = tickCumulativeOutside
}

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

// PositionInfo stores liquidity and fee state for a position.
// Liquidity and fee-growth fields are stored as decimal strings to reduce storage cost,
// while transferable owed amounts stay as int64 for token transfer boundaries.
type PositionInfo struct {
	liquidity                string // amount of liquidity owned by this position
	feeGrowthInside0LastX128 string // fee growth per unit of liquidity for token0 as of last update
	feeGrowthInside1LastX128 string // fee growth per unit of liquidity for token1 as of last update

	// accumulated fees in token0 waiting to be collected
	tokensOwed0 int64

	// accumulated fees in token1 waiting to be collected
	tokensOwed1 int64
}

func (p *PositionInfo) Liquidity() string                { return p.liquidity }
func (p *PositionInfo) FeeGrowthInside0LastX128() string { return p.feeGrowthInside0LastX128 }
func (p *PositionInfo) FeeGrowthInside1LastX128() string { return p.feeGrowthInside1LastX128 }
func (p *PositionInfo) TokensOwed0() int64               { return p.tokensOwed0 }
func (p *PositionInfo) TokensOwed1() int64               { return p.tokensOwed1 }

func (p *PositionInfo) SetLiquidity(liquidity string) {
	p.liquidity = liquidity
}

func (p *PositionInfo) SetFeeGrowthInside0LastX128(feeGrowthInside0LastX128 string) {
	p.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
}

func (p *PositionInfo) SetFeeGrowthInside1LastX128(feeGrowthInside1LastX128 string) {
	p.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
}

func (p *PositionInfo) SetTokensOwed0(tokensOwed0 int64) {
	p.tokensOwed0 = tokensOwed0
}

func (p *PositionInfo) SetTokensOwed1(tokensOwed1 int64) {
	p.tokensOwed1 = tokensOwed1
}
