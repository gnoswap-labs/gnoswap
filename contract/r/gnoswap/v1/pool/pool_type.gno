package pool

import (
	"strconv"
	"strings"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

type Balances struct {
	// current balance of the pool in token0/token1
	token0 *u256.Uint
	token1 *u256.Uint
}

func newBalances() Balances {
	return Balances{
		token0: u256.Zero(),
		token1: u256.Zero(),
	}
}

type Slot0 struct {
	sqrtPriceX96 *u256.Uint // current price of the pool as a sqrt(token1/token0) Q96 value
	tick         int32      // current tick of the pool, i.e according to the last tick transition that was run
	feeProtocol  uint8      // protocol fee for both tokens of the pool
	unlocked     bool       // whether the pool is currently locked to reentrancy
}

func (s *Slot0) Tick() int32        { return s.tick }
func (s *Slot0) FeeProtocol() uint8 { return s.feeProtocol }

func newSlot0(
	sqrtPriceX96 *u256.Uint,
	tick int32,
	feeProtocol uint8,
	unlocked bool,
) Slot0 {
	return Slot0{
		sqrtPriceX96: sqrtPriceX96,
		tick:         tick,
		feeProtocol:  feeProtocol,
		unlocked:     unlocked,
	}
}

type ProtocolFees struct {
	// current protocol fees of the pool in token0/token1
	token0 *u256.Uint
	token1 *u256.Uint
}

func newProtocolFees() ProtocolFees {
	return ProtocolFees{
		token0: u256.Zero(),
		token1: u256.Zero(),
	}
}

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
	liquidity            *u256.Uint // total amount of liquidity in the pool
	ticks                *avl.Tree  // tick(int32) -> TickInfo
	tickBitmaps          *avl.Tree  // tick(wordPos)(int16) -> bitMap(tickWord ^ mask)(*u256.Uint)
	positions            *avl.Tree  // maps the key (caller, lower tick, upper tick) to a unique position

	observation *Observation
}

func (p *Pool) PoolPath() string                 { return GetPoolPath(p.token0Path, p.token1Path, p.fee) }
func (p *Pool) Token0Path() string               { return p.token0Path }
func (p *Pool) Token1Path() string               { return p.token1Path }
func (p *Pool) Fee() uint32                      { return p.fee }
func (p *Pool) BalanceToken0() *u256.Uint        { return p.balances.token0 }
func (p *Pool) BalanceToken1() *u256.Uint        { return p.balances.token1 }
func (p *Pool) TickSpacing() int32               { return p.tickSpacing }
func (p *Pool) MaxLiquidityPerTick() *u256.Uint  { return p.maxLiquidityPerTick }
func (p *Pool) Slot0() Slot0                     { return p.slot0 }
func (p *Pool) Slot0SqrtPriceX96() *u256.Uint    { return p.slot0.sqrtPriceX96 }
func (p *Pool) Slot0Tick() int32                 { return p.slot0.tick }
func (p *Pool) Slot0FeeProtocol() uint8          { return p.slot0.feeProtocol }
func (p *Pool) Slot0Unlocked() bool              { return p.slot0.unlocked }
func (p *Pool) FeeGrowthGlobal0X128() *u256.Uint { return p.feeGrowthGlobal0X128 }
func (p *Pool) FeeGrowthGlobal1X128() *u256.Uint { return p.feeGrowthGlobal1X128 }
func (p *Pool) ProtocolFeesToken0() *u256.Uint   { return p.protocolFees.token0 }
func (p *Pool) ProtocolFeesToken1() *u256.Uint   { return p.protocolFees.token1 }
func (p *Pool) Liquidity() *u256.Uint            { return p.liquidity }
func (p *Pool) Observation() *Observation        { return p.observation }

func (p *Pool) Ticks() string {
	if p.ticks == nil {
		return "[]"
	}

	tickInfoStrings := []string{}

	p.ticks.Iterate("", "", func(tickKey string, tickValue any) bool {
		tick, err := strconv.ParseInt(tickKey, 10, 32)
		if err != nil {
			panic(err)
		}
		tickInfo, ok := tickValue.(TickInfo)
		if !ok {
			panic("failed to cast tick info to TickInfo")
		}

		tickInfoStrings = append(tickInfoStrings, ufmt.Sprintf(
			`{"tick":%d,"feeGrowthOutside0X128":"%s","feeGrowthOutside1X128":"%s"}`,
			tick,
			tickInfo.feeGrowthOutside0X128.ToString(),
			tickInfo.feeGrowthOutside1X128.ToString(),
		))

		return false
	})

	return "[" + strings.Join(tickInfoStrings, ",") + "]"
}

func (p *Pool) Clone() *Pool {
	ticks := avl.NewTree()
	tickBitmaps := avl.NewTree()
	positions := avl.NewTree()

	// clone ticks
	p.ticks.Iterate("", "", func(tickKey string, tickValue any) bool {
		tickInfo, ok := tickValue.(TickInfo)
		if !ok {
			panic(ufmt.Sprintf("failed to cast tickValue to TickInfo: %T", tickValue))
		}

		ticks.Set(tickKey, TickInfo{
			feeGrowthOutside0X128:          u256.Zero().Set(tickInfo.feeGrowthOutside0X128),
			feeGrowthOutside1X128:          u256.Zero().Set(tickInfo.feeGrowthOutside1X128),
			liquidityGross:                 u256.Zero().Set(tickInfo.liquidityGross),
			liquidityNet:                   i256.Zero().Set(tickInfo.liquidityNet),
			tickCumulativeOutside:          tickInfo.tickCumulativeOutside,
			secondsPerLiquidityOutsideX128: u256.Zero().Set(tickInfo.secondsPerLiquidityOutsideX128),
			secondsOutside:                 tickInfo.secondsOutside,
			initialized:                    tickInfo.initialized,
		})
		return false
	})

	// clone tickBitmaps
	p.tickBitmaps.Iterate("", "", func(tickKey string, tickValue any) bool {
		tickBitmap, ok := tickValue.(*u256.Uint)
		if !ok {
			panic(ufmt.Sprintf("failed to cast tickValue to *u256.Uint: %T", tickValue))
		}
		tickBitmaps.Set(tickKey, u256.Zero().Set(tickBitmap))
		return false
	})

	// clone positions
	p.positions.Iterate("", "", func(positionKey string, positionValue any) bool {
		positionInfo, ok := positionValue.(PositionInfo)
		if !ok {
			panic(ufmt.Sprintf("failed to cast positionValue to PositionInfo: %T", positionValue))
		}
		positions.Set(positionKey, PositionInfo{
			liquidity:                u256.Zero().Set(positionInfo.liquidity),
			feeGrowthInside0LastX128: u256.Zero().Set(positionInfo.feeGrowthInside0LastX128),
			feeGrowthInside1LastX128: u256.Zero().Set(positionInfo.feeGrowthInside1LastX128),
			tokensOwed0:              u256.Zero().Set(positionInfo.tokensOwed0),
			tokensOwed1:              u256.Zero().Set(positionInfo.tokensOwed1),
		})
		return false
	})

	return &Pool{
		token0Path:  p.token0Path,
		token1Path:  p.token1Path,
		fee:         p.fee,
		tickSpacing: p.tickSpacing,
		slot0: Slot0{
			sqrtPriceX96: u256.Zero().Set(p.slot0.sqrtPriceX96),
			tick:         p.slot0.tick,
			feeProtocol:  p.slot0.feeProtocol,
			unlocked:     p.slot0.unlocked,
		},
		balances: Balances{
			token0: u256.Zero().Set(p.balances.token0),
			token1: u256.Zero().Set(p.balances.token1),
		},
		protocolFees: ProtocolFees{
			token0: u256.Zero().Set(p.protocolFees.token0),
			token1: u256.Zero().Set(p.protocolFees.token1),
		},
		maxLiquidityPerTick:  u256.Zero().Set(p.maxLiquidityPerTick),
		feeGrowthGlobal0X128: u256.Zero().Set(p.feeGrowthGlobal0X128),
		feeGrowthGlobal1X128: u256.Zero().Set(p.feeGrowthGlobal1X128),
		liquidity:            u256.Zero().Set(p.liquidity),
		ticks:                ticks,
		tickBitmaps:          tickBitmaps,
		positions:            positions,
		observation: &Observation{
			lastCumulativeUpdateTime: p.observation.lastCumulativeUpdateTime,
			tickCumulative:           p.observation.tickCumulative,
			liquidityCumulative:      u256.Zero().Set(p.observation.liquidityCumulative),
		},
	}
}

func (p *Pool) calculateTickCumulative(currentTime int64) (int64, *u256.Uint, int64) {
	// calculate time delta
	observation := p.Observation()
	timeDelta := currentTime - observation.lastCumulativeUpdateTime
	if timeDelta <= 0 {
		return observation.tickCumulative, observation.liquidityCumulative, observation.lastCumulativeUpdateTime
	}

	// update cumulative values (only price is used)
	// sqrtPriceCumulativeX96 = sqrtPriceCumulativeX96 + sqrtPriceX96 * timeDelta
	tickDelta := int64(p.slot0.Tick()) * timeDelta

	// liquidityCumulative = liquidityCumulative + liquidity * timeDelta
	liquidityDelta := u256.Zero().Mul(p.liquidity, u256.NewUintFromInt64(timeDelta))

	tickCumulative := observation.tickCumulative + tickDelta
	liquidityCumulative := u256.Zero().Add(observation.liquidityCumulative, liquidityDelta)
	lastCumulativeUpdateTime := currentTime

	return tickCumulative, liquidityCumulative, lastCumulativeUpdateTime
}

// updatePriceCumulatives updates cumulative price values when pool price changes
// This should be called whenever the pool's price changes (swap, mint, burn)
func (p *Pool) updatePriceCumulatives(currentTime int64) {
	if currentTime < p.observation.lastCumulativeUpdateTime {
		return
	}

	tickCumulative, liquidityCumulative, lastCumulativeUpdateTime := p.calculateTickCumulative(currentTime)

	p.observation.liquidityCumulative = liquidityCumulative
	p.observation.tickCumulative = tickCumulative
	p.observation.lastCumulativeUpdateTime = lastCumulativeUpdateTime
}

type Observation struct {
	lastCumulativeUpdateTime int64      // last cumulative update time (in seconds)
	tickCumulative           int64      // cumulative tick
	liquidityCumulative      *u256.Uint // cumulative liquidity (time-weighted average calculation)
}

func (t *Observation) LastCumulativeUpdateTime() int64 { return t.lastCumulativeUpdateTime }
func (t *Observation) TickCumulative() int64           { return t.tickCumulative }
func (t *Observation) LiquidityCumulative() string     { return t.liquidityCumulative.ToString() }

func newObservation(currentTime int64) *Observation {
	return &Observation{
		lastCumulativeUpdateTime: currentTime,
		tickCumulative:           0,
		liquidityCumulative:      u256.Zero(),
	}
}
