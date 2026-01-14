package v2

import (
	"strconv"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
	pl "gno.land/r/gnoswap/pool"
)

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	return pl.GetPoolPath(token0Path, token1Path, fee)
}

// GetPool retrieves a pool instance based on the provided token paths and fee tier.
func (i *poolV1) GetPool(token0Path, token1Path string, fee uint32) (*pl.Pool, error) {
	poolPath := pl.GetPoolPath(token0Path, token1Path, fee)
	return i.getPool(poolPath)
}

// GetFeeAmountTickSpacing retrieves the tick spacing associated with a given fee amount.
func (i *poolV1) GetFeeAmountTickSpacing(fee uint32) (spacing int32) {
	feeAmountTickSpacing := i.store.GetFeeAmountTickSpacing()

	spacing, exist := feeAmountTickSpacing[fee]
	if !exist {
		panic(newErrorWithDetail(
			errUnsupportedFeeTier,
			ufmt.Sprintf("expected fee(%d) to be one of %d, %d, %d, %d", fee, FeeTier100, FeeTier500, FeeTier3000, FeeTier10000),
		))
	}

	return spacing
}

func (i *poolV1) GetToken0Path(poolPath string) string {
	return i.mustGetPool(poolPath).Token0Path()
}

func (i *poolV1) GetToken1Path(poolPath string) string {
	return i.mustGetPool(poolPath).Token1Path()
}

func (i *poolV1) GetFee(poolPath string) uint32 {
	return i.mustGetPool(poolPath).Fee()
}

func (i *poolV1) GetBalanceToken0(poolPath string) string {
	return i.mustGetPool(poolPath).BalanceToken0().ToString()
}

func (i *poolV1) GetBalanceToken1(poolPath string) string {
	return i.mustGetPool(poolPath).BalanceToken1().ToString()
}

func (i *poolV1) GetTickSpacing(poolPath string) int32 {
	return i.mustGetPool(poolPath).TickSpacing()
}

func (i *poolV1) GetMaxLiquidityPerTick(poolPath string) string {
	return i.mustGetPool(poolPath).MaxLiquidityPerTick().ToString()
}

func (i *poolV1) GetSlot0FeeProtocol(poolPath string) uint8 {
	return i.mustGetPool(poolPath).Slot0FeeProtocol()
}

func (i *poolV1) GetSlot0Unlocked(poolPath string) bool {
	return i.mustGetPool(poolPath).Slot0Unlocked()
}

func (i *poolV1) GetFeeGrowthGlobal0X128(poolPath string) string {
	return i.mustGetPool(poolPath).FeeGrowthGlobal0X128().ToString()
}

func (i *poolV1) GetFeeGrowthGlobal1X128(poolPath string) string {
	return i.mustGetPool(poolPath).FeeGrowthGlobal1X128().ToString()
}

func (i *poolV1) GetProtocolFeesToken0(poolPath string) string {
	return i.mustGetPool(poolPath).ProtocolFeesToken0().ToString()
}

func (i *poolV1) GetProtocolFeesToken1(poolPath string) string {
	return i.mustGetPool(poolPath).ProtocolFeesToken1().ToString()
}

func (i *poolV1) GetLiquidity(poolPath string) string {
	return i.mustGetPool(poolPath).Liquidity().ToString()
}

func (i *poolV1) MustGetPosition(poolPath, key string) *pl.PositionInfo {
	pool := i.mustGetPool(poolPath)

	positions := pool.Positions()

	result, exist := positions.Get(key)
	if !exist {
		panic(newErrorWithDetail(
			errDataNotFound,
			ufmt.Sprintf("expected position(%s) to exist", key),
		))
	}

	position, ok := result.(pl.PositionInfo)
	if !ok {
		panic("failed to cast position to PositionInfo")
	}

	return &position
}

func (i *poolV1) GetPositionFeeGrowthInside0LastX128(poolPath, key string) string {
	return i.MustGetPosition(poolPath, key).FeeGrowthInside0LastX128().ToString()
}

func (i *poolV1) GetPositionFeeGrowthInside1LastX128(poolPath, key string) string {
	return i.MustGetPosition(poolPath, key).FeeGrowthInside1LastX128().ToString()
}

func (i *poolV1) GetPositionTokensOwed0(poolPath, key string) string {
	return i.MustGetPosition(poolPath, key).TokensOwed0().ToString()
}

func (i *poolV1) GetPositionTokensOwed1(poolPath, key string) string {
	return i.MustGetPosition(poolPath, key).TokensOwed1().ToString()
}

func (i *poolV1) GetTickLiquidityGross(poolPath string, tick int32) string {
	pool := i.mustGetPool(poolPath)
	return GetTickLiquidityGross(pool, tick).ToString()
}

func (i *poolV1) GetTickLiquidityNet(poolPath string, tick int32) string {
	pool := i.mustGetPool(poolPath)
	return GetTickLiquidityNet(pool, tick).ToString()
}

func (i *poolV1) GetTickFeeGrowthOutside0X128(poolPath string, tick int32) string {
	pool := i.mustGetPool(poolPath)
	return GetTickFeeGrowthOutside0X128(pool, tick).ToString()
}

func (i *poolV1) GetTickFeeGrowthOutside1X128(poolPath string, tick int32) string {
	pool := i.mustGetPool(poolPath)
	return GetTickFeeGrowthOutside1X128(pool, tick).ToString()
}

func (i *poolV1) GetTickCumulativeOutside(poolPath string, tick int32) int64 {
	pool := i.mustGetPool(poolPath)
	return GetTickCumulativeOutside(pool, tick)
}

func (i *poolV1) GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string {
	pool := i.mustGetPool(poolPath)
	return GetTickSecondsPerLiquidityOutsideX128(pool, tick).ToString()
}

func (i *poolV1) GetTickSecondsOutside(poolPath string, tick int32) uint32 {
	pool := i.mustGetPool(poolPath)
	return GetTickSecondsOutside(pool, tick)
}

func (i *poolV1) GetTickInitialized(poolPath string, tick int32) bool {
	pool := i.mustGetPool(poolPath)
	return GetTickInitialized(pool, tick)
}

func (i *poolV1) GetSlot0Tick(poolPath string) int32 {
	return i.mustGetPool(poolPath).Slot0Tick()
}

func (i *poolV1) GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	slot0 := i.mustGetPool(poolPath).Slot0()
	return u256.Zero().Set(slot0.SqrtPriceX96())
}

func (i *poolV1) GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	pool := i.mustGetPool(poolPath)
	return u256.Zero().Set(pool.FeeGrowthGlobal0X128()), u256.Zero().Set(pool.FeeGrowthGlobal1X128())
}

func (i *poolV1) GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (*u256.Uint, *u256.Uint) {
	pool := i.mustGetPool(poolPath)
	return u256.Zero().Set(GetTickFeeGrowthOutside0X128(pool, tick)), u256.Zero().Set(GetTickFeeGrowthOutside1X128(pool, tick))
}

func (i *poolV1) GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	position := i.MustGetPosition(poolPath, key)
	return u256.Zero().Set(position.FeeGrowthInside0LastX128()), u256.Zero().Set(position.FeeGrowthInside1LastX128())
}

func (i *poolV1) GetPositionLiquidity(poolPath, key string) *u256.Uint {
	position := i.MustGetPosition(poolPath, key)
	return u256.Zero().Set(position.Liquidity())
}

func (i *poolV1) ExistsPoolPath(poolPath string) bool {
	pools := i.store.GetPools()
	return pools.Has(poolPath)
}

func (i *poolV1) GetObservation(poolPath string, secondsAgo int64) (
	tickCumulative int64,
	liquidityCumulative,
	secondsPerLiquidityCumulativeX128 string,
	blockTimestamp int64,
) {
	pool := i.mustGetPool(poolPath)
	observationState := pool.ObservationState()

	if observationState == nil {
		return 0, "0", "0", 0
	}

	lastObservation, err := lastObservation(observationState)
	if err != nil {
		return 0, "0", "0", 0
	}

	tickCumulative = lastObservation.TickCumulative()
	liquidityCumulative = lastObservation.LiquidityCumulative().ToString()
	secondsPerLiquidityCumulativeX128 = lastObservation.SecondsPerLiquidityCumulativeX128().ToString()
	blockTimestamp = lastObservation.BlockTimestamp()

	return
}

func (i *poolV1) GetPoolCreationFee() int64 {
	return i.store.GetPoolCreationFee()
}

func (i *poolV1) GetWithdrawalFee() uint64 {
	return i.store.GetWithdrawalFeeBPS()
}

// GetTWAP returns the time-weighted average price for a pool over a specified period
//
// Parameters:
//   - poolPath: The path of the pool (e.g., "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
//   - secondsAgo: Number of seconds ago to calculate TWAP from
//
// Returns TWAP tick and error
func (i *poolV1) GetTWAP(poolPath string, secondsAgo uint32) (int32, *u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, nil, err
	}

	return getTWAP(pool, secondsAgo)
}

// GetPoolCount returns the total number of pools.
func (i *poolV1) GetPoolCount() int {
	pools := i.store.GetPools()
	return pools.Size()
}

// GetPoolPaths returns a paginated list of pool paths.
func (i *poolV1) GetPoolPaths(offset, count int) []string {
	pools := i.store.GetPools()
	poolPaths := make([]string, 0)

	pools.IterateByOffset(offset, count, func(key string, _ any) bool {
		poolPaths = append(poolPaths, key)
		return false
	})

	return poolPaths
}

// GetFeeAmountTickSpacings returns all fee tier to tick spacing mappings.
func (i *poolV1) GetFeeAmountTickSpacings() map[uint32]int32 {
	return i.store.GetFeeAmountTickSpacing()
}

// GetPoolPositionCount returns the number of positions in a pool.
func (i *poolV1) GetPoolPositionCount(poolPath string) int {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0
	}

	return pool.Positions().Size()
}

// GetPoolPositionKeys returns a paginated list of position keys in a pool.
func (i *poolV1) GetPoolPositionKeys(poolPath string, offset, count int) []string {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return []string{}
	}

	positionKeys := make([]string, 0)

	pool.Positions().IterateByOffset(offset, count, func(key string, _ any) bool {
		positionKeys = append(positionKeys, key)
		return false
	})

	return positionKeys
}

// Tick enumeration

// GetInitializedTicksInRange returns initialized ticks within the given range.
func (i *poolV1) GetInitializedTicksInRange(poolPath string, tickLower, tickUpper int32) []int32 {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return []int32{}
	}

	ticks := make([]int32, 0)

	tickLowerStr := strconv.FormatInt(int64(tickLower), 10)
	tickUpperStr := strconv.FormatInt(int64(tickUpper), 10)

	pool.Ticks().Iterate(tickLowerStr, tickUpperStr, func(key string, _ any) bool {
		tick, err := strconv.ParseInt(key, 10, 32)
		if err != nil {
			return false
		}

		ticks = append(ticks, int32(tick))
		return false
	})

	return ticks
}

// Structure getters

// GetTickInfo returns the tick info for a given tick.
func (i *poolV1) GetTickInfo(poolPath string, tick int32) (pl.TickInfo, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return pl.TickInfo{}, err
	}

	tickStr := strconv.Itoa(int(tick))
	iTickInfo, ok := pool.Ticks().Get(tickStr)
	if !ok {
		return pl.TickInfo{}, ufmt.Errorf("tick %d not found", tick)
	}

	tickInfo, ok := iTickInfo.(pl.TickInfo)
	if !ok {
		return pl.TickInfo{}, ufmt.Errorf("failed to cast tickInfo: %T", iTickInfo)
	}

	return tickInfo, nil
}

// GetTickBitmaps returns the tick bitmap for a given word position.
func (i *poolV1) GetTickBitmaps(poolPath string, wordPos int16) (*u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, err
	}

	wordPosStr := strconv.Itoa(int(wordPos))

	iTickBitmap, ok := pool.TickBitmaps().Get(wordPosStr)
	if !ok {
		return nil, ufmt.Errorf("tick bitmap %d not found", wordPos)
	}

	tickBitmap, ok := iTickBitmap.(*u256.Uint)
	if !ok {
		return nil, ufmt.Errorf("failed to cast tick bitmap: %T", iTickBitmap)
	}

	return tickBitmap, nil
}

// GetPosition returns the position info for a given key.
func (i *poolV1) GetPosition(poolPath, key string) (pl.PositionInfo, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return pl.PositionInfo{}, err
	}

	iPositionInfo, ok := pool.Positions().Get(key)
	if !ok {
		return pl.PositionInfo{}, ufmt.Errorf("position %s not found", key)
	}

	positionInfo, ok := iPositionInfo.(pl.PositionInfo)
	if !ok {
		return pl.PositionInfo{}, ufmt.Errorf("failed to cast positionInfo: %T", iPositionInfo)
	}

	return positionInfo, nil
}

// GetObservationState returns the observation state for a pool.
func (i *poolV1) GetObservationState(poolPath string) (*pl.ObservationState, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, err
	}

	observationState := pool.ObservationState()
	if observationState == nil {
		return nil, ufmt.Errorf("observation state not found for pool %s", poolPath)
	}

	return observationState, nil
}
