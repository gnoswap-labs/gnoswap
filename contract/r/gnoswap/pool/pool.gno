package pool

import (
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	i256 "gno.land/p/gnoswap/int256"
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
	balances             Balances // balances of the pool
	protocolFees         ProtocolFees
	maxLiquidityPerTick  *u256.Uint // the maximum amount of liquidity that can be added per tick
	feeGrowthGlobal0X128 *u256.Uint // uint256
	feeGrowthGlobal1X128 *u256.Uint // uint256
	liquidity            *u256.Uint // total amount of active liquidity in the pool (within current tick range)
	ticks                *avl.Tree  // tick(int32) -> TickInfo
	tickBitmaps          *avl.Tree  // tick(wordPos)(int16) -> bitMap(tickWord ^ mask)(*u256.Uint)
	positions            *avl.Tree  // maps the key (caller, lower tick, upper tick) to a unique position

	observationState *ObservationState // oracle state with historical observations
}

// Pool Getters methods
func (p *Pool) PoolPath() string                    { return GetPoolPath(p.token0Path, p.token1Path, p.fee) }
func (p *Pool) Token0Path() string                  { return p.token0Path }
func (p *Pool) Token1Path() string                  { return p.token1Path }
func (p *Pool) Fee() uint32                         { return p.fee }
func (p *Pool) Balances() Balances                  { return p.balances }
func (p *Pool) BalanceToken0() *u256.Uint           { return p.balances.token0 }
func (p *Pool) BalanceToken1() *u256.Uint           { return p.balances.token1 }
func (p *Pool) TickSpacing() int32                  { return p.tickSpacing }
func (p *Pool) MaxLiquidityPerTick() *u256.Uint     { return p.maxLiquidityPerTick }
func (p *Pool) Slot0() Slot0                        { return p.slot0 }
func (p *Pool) Slot0SqrtPriceX96() *u256.Uint       { return p.slot0.sqrtPriceX96 }
func (p *Pool) Slot0Tick() int32                    { return p.slot0.tick }
func (p *Pool) Slot0FeeProtocol() uint8             { return p.slot0.feeProtocol }
func (p *Pool) Slot0Unlocked() bool                 { return p.slot0.unlocked }
func (p *Pool) FeeGrowthGlobal0X128() *u256.Uint    { return p.feeGrowthGlobal0X128 }
func (p *Pool) FeeGrowthGlobal1X128() *u256.Uint    { return p.feeGrowthGlobal1X128 }
func (p *Pool) ProtocolFees() ProtocolFees          { return p.protocolFees }
func (p *Pool) ProtocolFeesToken0() *u256.Uint      { return p.protocolFees.token0 }
func (p *Pool) ProtocolFeesToken1() *u256.Uint      { return p.protocolFees.token1 }
func (p *Pool) Liquidity() *u256.Uint               { return p.liquidity }
func (p *Pool) Ticks() *avl.Tree                    { return p.ticks }
func (p *Pool) TickBitmaps() *avl.Tree              { return p.tickBitmaps }
func (p *Pool) Positions() *avl.Tree                { return p.positions }
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

func (p *Pool) SetBalances(balances Balances) {
	p.balances = balances
}

func (p *Pool) SetBalanceToken0(token0 *u256.Uint) {
	p.balances.token0 = token0
}

func (p *Pool) SetBalanceToken1(token1 *u256.Uint) {
	p.balances.token1 = token1
}

func (p *Pool) SetTickSpacing(tickSpacing int32) {
	p.tickSpacing = tickSpacing
}

func (p *Pool) SetMaxLiquidityPerTick(maxLiquidityPerTick *u256.Uint) {
	p.maxLiquidityPerTick = maxLiquidityPerTick
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

func (p *Pool) SetProtocolFees(protocolFees ProtocolFees) {
	p.protocolFees = protocolFees
}

func (p *Pool) SetProtocolFeesToken0(token0 *u256.Uint) {
	p.protocolFees.token0 = token0
}

func (p *Pool) SetProtocolFeesToken1(token1 *u256.Uint) {
	p.protocolFees.token1 = token1
}

func (p *Pool) SetLiquidity(liquidity *u256.Uint) {
	p.liquidity = liquidity
}

func (p *Pool) SetTicks(ticks *avl.Tree) {
	p.ticks = ticks
}

func (p *Pool) SetTickBitmaps(tickBitmaps *avl.Tree) {
	p.tickBitmaps = tickBitmaps
}

func (p *Pool) SetPositions(positions *avl.Tree) {
	p.positions = positions
}

func (p *Pool) SetObservationState(observationState *ObservationState) {
	p.observationState = observationState
}

func (p *Pool) HasTick(tick int32) bool {
	tickKey := encodeTickKey(tick)
	return p.ticks.Has(tickKey)
}

func (p *Pool) GetTick(tick int32) (TickInfo, error) {
	tickKey := encodeTickKey(tick)

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
	tickKey := encodeTickKey(tick)
	p.ticks.Set(tickKey, tickInfo)
}

func (p *Pool) DeleteTick(tick int32) {
	tickKey := encodeTickKey(tick)
	p.ticks.Remove(tickKey)
}

func (p *Pool) IterateTicks(startTick int32, endTick int32, fn func(tick int32, tickInfo TickInfo) bool) {
	startTickKey := encodeTickKey(startTick)
	endTickKey := encodeTickKey(endTick + 1) // endTick inclusive

	p.ticks.Iterate(startTickKey, endTickKey, func(key string, value any) bool {
		tick := decodeTickKey(key)

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
		balances:             Balances{TokenPair: p.balances.TokenPair.Clone()},
		protocolFees:         ProtocolFees{TokenPair: p.protocolFees.TokenPair.Clone()},
		maxLiquidityPerTick:  p.maxLiquidityPerTick.Clone(),
		feeGrowthGlobal0X128: p.feeGrowthGlobal0X128.Clone(),
		feeGrowthGlobal1X128: p.feeGrowthGlobal1X128.Clone(),
		liquidity:            p.liquidity.Clone(),
		ticks:                avl.NewTree(),
		tickBitmaps:          avl.NewTree(),
		positions:            avl.NewTree(),
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
	maxLiquidityPerTick *u256.Uint,
) *Pool {
	slot0 := newSlot0(sqrtPriceX96, tick, slot0FeeProtocol, true)

	return &Pool{
		token0Path:           token0Path,
		token1Path:           token1Path,
		balances:             newBalances(),
		fee:                  fee,
		tickSpacing:          tickSpacing,
		maxLiquidityPerTick:  maxLiquidityPerTick,
		slot0:                slot0,
		feeGrowthGlobal0X128: u256.Zero(),
		feeGrowthGlobal1X128: u256.Zero(),
		protocolFees:         newProtocolFees(),
		liquidity:            u256.Zero(),
		ticks:                avl.NewTree(),
		tickBitmaps:          avl.NewTree(),
		positions:            avl.NewTree(),
		observationState:     NewObservationState(time.Now().Unix()),
	}
}

type Balances struct{ TokenPair }

func newBalances() Balances {
	return Balances{
		TokenPair: NewTokenPair(u256.Zero(), u256.Zero()),
	}
}

type ProtocolFees struct{ TokenPair }

func newProtocolFees() ProtocolFees {
	return ProtocolFees{
		TokenPair: NewTokenPair(u256.Zero(), u256.Zero()),
	}
}

type TokenPair struct {
	token0, token1 *u256.Uint
}

func NewTokenPair(token0, token1 *u256.Uint) TokenPair {
	return TokenPair{
		token0: token0,
		token1: token1,
	}
}

func (t *TokenPair) Token0() *u256.Uint { return t.token0 }
func (t *TokenPair) Token1() *u256.Uint { return t.token1 }

func (t *TokenPair) SetToken0(token0 *u256.Uint) { t.token0 = token0 }
func (t *TokenPair) SetToken1(token1 *u256.Uint) { t.token1 = token1 }

func (t *TokenPair) Clone() TokenPair {
	return NewTokenPair(
		t.token0.Clone(),
		t.token1.Clone(),
	)
}

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
	liquidityGross *u256.Uint // total position liquidity that references this tick
	liquidityNet   *i256.Int  // amount of net liquidity added (subtracted) when tick is crossed from left to right (right to left)

	// fee growth per unit of liquidity on the _other_ side of this tick (relative to the current tick)
	// only has relative meaning, not absolute — the value depends on when the tick is initialized
	feeGrowthOutside0X128 *u256.Uint
	feeGrowthOutside1X128 *u256.Uint

	tickCumulativeOutside int64 // cumulative tick value on the other side of the tick

	// the seconds per unit of liquidity on the _other_ side of this tick (relative to the current tick)
	// only has relative meaning, not absolute — the value depends on when the tick is initialized
	secondsPerLiquidityOutsideX128 *u256.Uint

	// the seconds spent on the other side of the tick (relative to the current tick)
	// only has relative meaning, not absolute — the value depends on when the tick is initialized
	secondsOutside uint32

	initialized bool // whether the tick is initialized
}

// TickInfo Getters methods
func (t *TickInfo) LiquidityGross() *u256.Uint        { return t.liquidityGross }
func (t *TickInfo) LiquidityNet() *i256.Int           { return t.liquidityNet }
func (t *TickInfo) FeeGrowthOutside0X128() *u256.Uint { return t.feeGrowthOutside0X128 }
func (t *TickInfo) FeeGrowthOutside1X128() *u256.Uint { return t.feeGrowthOutside1X128 }
func (t *TickInfo) SecondsPerLiquidityOutsideX128() *u256.Uint {
	return t.secondsPerLiquidityOutsideX128
}
func (t *TickInfo) SecondsOutside() uint32       { return t.secondsOutside }
func (t *TickInfo) Initialized() bool            { return t.initialized }
func (t *TickInfo) TickCumulativeOutside() int64 { return t.tickCumulativeOutside }

// TickInfo Setters methods
func (t *TickInfo) SetLiquidityGross(liquidityGross *u256.Uint) {
	t.liquidityGross = liquidityGross
}

func (t *TickInfo) SetLiquidityNet(liquidityNet *i256.Int) {
	t.liquidityNet = liquidityNet
}

func (t *TickInfo) SetFeeGrowthOutside0X128(feeGrowthOutside0X128 *u256.Uint) {
	t.feeGrowthOutside0X128 = feeGrowthOutside0X128
}

func (t *TickInfo) SetFeeGrowthOutside1X128(feeGrowthOutside1X128 *u256.Uint) {
	t.feeGrowthOutside1X128 = feeGrowthOutside1X128
}

func (t *TickInfo) SetSecondsPerLiquidityOutsideX128(secondsPerLiquidityOutsideX128 *u256.Uint) {
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

func NewTickInfo() TickInfo {
	return TickInfo{
		liquidityGross:                 u256.Zero(),
		liquidityNet:                   i256.Zero(),
		feeGrowthOutside0X128:          u256.Zero(),
		feeGrowthOutside1X128:          u256.Zero(),
		secondsPerLiquidityOutsideX128: u256.Zero(),
		secondsOutside:                 0,
		initialized:                    false,
		tickCumulativeOutside:          0,
	}
}

func cloneTickInfo(src TickInfo) TickInfo {
	return TickInfo{
		feeGrowthOutside0X128:          src.feeGrowthOutside0X128.Clone(),
		feeGrowthOutside1X128:          src.feeGrowthOutside1X128.Clone(),
		liquidityGross:                 src.liquidityGross.Clone(),
		liquidityNet:                   src.liquidityNet.Clone(),
		tickCumulativeOutside:          src.tickCumulativeOutside,
		secondsPerLiquidityOutsideX128: src.secondsPerLiquidityOutsideX128.Clone(),
		secondsOutside:                 src.secondsOutside,
		initialized:                    src.initialized,
	}
}

type PositionInfo struct {
	liquidity *u256.Uint // amount of liquidity owned by this position

	// Fee growth per unit of liquidity as of the last update
	// Used to calculate uncollected fees for token0
	feeGrowthInside0LastX128 *u256.Uint

	// Fee growth per unit of liquidity as of the last update
	// Used to calculate uncollected fees for token1
	feeGrowthInside1LastX128 *u256.Uint

	// accumulated fees in token0 waiting to be collected
	tokensOwed0 *u256.Uint

	// accumulated fees in token1 waiting to be collected
	tokensOwed1 *u256.Uint
}

func (p *PositionInfo) Liquidity() *u256.Uint                { return p.liquidity }
func (p *PositionInfo) FeeGrowthInside0LastX128() *u256.Uint { return p.feeGrowthInside0LastX128 }
func (p *PositionInfo) FeeGrowthInside1LastX128() *u256.Uint { return p.feeGrowthInside1LastX128 }
func (p *PositionInfo) TokensOwed0() *u256.Uint              { return p.tokensOwed0 }
func (p *PositionInfo) TokensOwed1() *u256.Uint              { return p.tokensOwed1 }

func (p *PositionInfo) SetLiquidity(liquidity *u256.Uint) {
	p.liquidity = liquidity
}

func (p *PositionInfo) SetFeeGrowthInside0LastX128(feeGrowthInside0LastX128 *u256.Uint) {
	p.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
}

func (p *PositionInfo) SetFeeGrowthInside1LastX128(feeGrowthInside1LastX128 *u256.Uint) {
	p.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
}

func (p *PositionInfo) SetTokensOwed0(tokensOwed0 *u256.Uint) {
	p.tokensOwed0 = tokensOwed0
}

func (p *PositionInfo) SetTokensOwed1(tokensOwed1 *u256.Uint) {
	p.tokensOwed1 = tokensOwed1
}

func NewPositionInfo(
	liquidity *u256.Uint,
	feeGrowthInside0LastX128 *u256.Uint,
	feeGrowthInside1LastX128 *u256.Uint,
	tokensOwed0 *u256.Uint,
	tokensOwed1 *u256.Uint,
) PositionInfo {
	return PositionInfo{
		liquidity:                liquidity,
		feeGrowthInside0LastX128: feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: feeGrowthInside1LastX128,
		tokensOwed0:              tokensOwed0,
		tokensOwed1:              tokensOwed1,
	}
}
