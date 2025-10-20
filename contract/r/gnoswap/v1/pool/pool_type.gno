package pool

import (
	"errors"
	"strconv"
	"strings"
	"time"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
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
	liquidity            *u256.Uint // total amount of active liquidity in the pool (within current tick range)
	ticks                *avl.Tree  // tick(int32) -> TickInfo
	tickBitmaps          *avl.Tree  // tick(wordPos)(int16) -> bitMap(tickWord ^ mask)(*u256.Uint)
	positions            *avl.Tree  // maps the key (caller, lower tick, upper tick) to a unique position

	observationState *ObservationState // oracle state with historical observations
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
		observationState:     newObservationState(time.Now().Unix()),
	}
}

// writeObservation writes a new observation to the oracle
func (p *Pool) writeObservation(currentTime int64, tick int32, liquidity *u256.Uint) error {
	if p.observationState == nil {
		p.observationState = newObservationState(currentTime)
	}

	err := p.observationState.write(currentTime, tick, liquidity)
	if err != nil {
		return err
	}

	return nil
}

// ObservationTickCumulative returns the current tick cumulative for backward compatibility
func (p *Pool) ObservationTickCumulative() int64 {
	if p.observationState == nil {
		return 0
	}

	lastObservation, err := p.observationState.lastObservation()
	if err != nil {
		return 0
	}

	return lastObservation.tickCumulative
}

// ObservationLiquidityCumulative returns the current liquidity cumulative for backward compatibility
func (p *Pool) ObservationLiquidityCumulative() string {
	if p.observationState == nil {
		return "0"
	}

	lastObservation, err := p.observationState.lastObservation()
	if err != nil {
		return "0"
	}

	return lastObservation.liquidityCumulative.ToString()
}

// ObservationSecondsPerLiquidityCumulativeX128 returns the current seconds per liquidity cumulative for backward compatibility
func (p *Pool) ObservationSecondsPerLiquidityCumulativeX128() string {
	if p.observationState == nil {
		return "0"
	}

	lastObservation, err := p.observationState.lastObservation()
	if err != nil {
		return "0"
	}

	return lastObservation.secondsPerLiquidityCumulativeX128.ToString()
}

// ObservationBlockTimestamp returns the current observation timestamp for backward compatibility
func (p *Pool) ObservationBlockTimestamp() int64 {
	if p.observationState == nil {
		return time.Now().Unix()
	}

	lastObservation, err := p.observationState.lastObservation()
	if err != nil {
		return time.Now().Unix()
	}

	return lastObservation.blockTimestamp
}

// GetTWAP calculates the time-weighted average price between two points in time
// Returns the average tick over the time period
func (p *Pool) GetTWAP(secondsAgo uint32) (int32, error) {
	if secondsAgo == 0 {
		return p.slot0.tick, nil
	}

	// Check if observation state is initialized
	if p.observationState == nil {
		return 0, errors.New("observation state not initialized")
	}

	// Check if we have enough observations
	if p.observationState.cardinality == 0 {
		return 0, errors.New("no observations available")
	}

	// Get observations for current time and secondsAgo
	secondsAgos := []uint32{secondsAgo, 0}
	currentTime := time.Now().Unix()

	tickCumulatives, _, err := p.observationState.observe(
		currentTime,
		secondsAgos,
		p.slot0.tick,
		p.observationState.index,
		p.liquidity,
		p.observationState.cardinality,
	)
	if err != nil {
		return 0, err
	}

	// Ensure we have valid data
	if len(tickCumulatives) != 2 {
		return 0, errors.New("insufficient observation data")
	}

	// Calculate TWAP: (tickCumulative_now - tickCumulative_before) / timeDelta
	tickDelta := tickCumulatives[1] - tickCumulatives[0]
	twapTick := int32(tickDelta / int64(secondsAgo))

	return twapTick, nil
}

// IncreaseObservationCardinalityLimit increases the maximum number of observations
// that the oracle can store. This does not immediately increase cardinality,
// but sets it to increase on the next write.
func (p *Pool) IncreaseObservationCardinalityLimit(observationCardinalityNext uint16) error {
	if p.observationState == nil {
		return errors.New("observation state not initialized")
	}

	if observationCardinalityNext > maxObservationCardinality {
		return errors.New("observation cardinality next exceeds maximum")
	}

	if observationCardinalityNext <= p.observationState.cardinalityLimit {
		return errors.New("observation cardinality next must be greater than current")
	}

	p.observationState.cardinalityLimit = observationCardinalityNext

	return nil
}
