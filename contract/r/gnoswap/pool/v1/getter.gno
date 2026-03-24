package v1

import (
	"strconv"

	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"
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

func (i *poolV1) mustGetPositionInfo(poolPath, key string) *pl.PositionInfo {
	if !i.ExistsPoolPath(poolPath) {
		panic(makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("expected poolPath(%s) to exist", poolPath)))
	}

	positions := i.store.GetPoolPositions(poolPath)

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

func (i *poolV1) mustGetTickInfo(poolPath string, tick int32) *pl.TickInfo {
	if !i.ExistsPoolPath(poolPath) {
		panic(makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("expected poolPath(%s) to exist", poolPath)))
	}

	pool := i.mustGetPoolCore(poolPath)
	tickInfo, err := pool.GetTick(tick)
	if err != nil {
		panic(err)
	}
	tickInfo = tickInfo.Clone()

	return &tickInfo
}

func (i *poolV1) GetToken0Path(poolPath string) string {
	return i.mustGetPoolCore(poolPath).Token0Path()
}

func (i *poolV1) GetToken1Path(poolPath string) string {
	return i.mustGetPoolCore(poolPath).Token1Path()
}

func (i *poolV1) GetFee(poolPath string) uint32 {
	return i.mustGetPoolCore(poolPath).Fee()
}

func (i *poolV1) GetBalanceToken0(poolPath string) string {
	return i.mustGetPoolCore(poolPath).BalanceToken0().ToString()
}

func (i *poolV1) GetBalanceToken1(poolPath string) string {
	return i.mustGetPoolCore(poolPath).BalanceToken1().ToString()
}

func (i *poolV1) GetTickSpacing(poolPath string) int32 {
	return i.mustGetPoolCore(poolPath).TickSpacing()
}

func (i *poolV1) GetMaxLiquidityPerTick(poolPath string) string {
	return i.mustGetPoolCore(poolPath).MaxLiquidityPerTick().ToString()
}

func (i *poolV1) GetSlot0FeeProtocol(poolPath string) uint8 {
	return i.mustGetPoolCore(poolPath).Slot0FeeProtocol()
}

func (i *poolV1) GetSlot0Unlocked(poolPath string) bool {
	return i.mustGetPoolCore(poolPath).Slot0Unlocked()
}

func (i *poolV1) GetFeeGrowthGlobal0X128(poolPath string) string {
	return i.mustGetPoolCore(poolPath).FeeGrowthGlobal0X128().ToString()
}

func (i *poolV1) GetFeeGrowthGlobal1X128(poolPath string) string {
	return i.mustGetPoolCore(poolPath).FeeGrowthGlobal1X128().ToString()
}

func (i *poolV1) GetProtocolFeesToken0(poolPath string) string {
	return i.mustGetPoolCore(poolPath).ProtocolFeesToken0().ToString()
}

func (i *poolV1) GetProtocolFeesToken1(poolPath string) string {
	return i.mustGetPoolCore(poolPath).ProtocolFeesToken1().ToString()
}

func (i *poolV1) GetLiquidity(poolPath string) string {
	return i.mustGetPoolCore(poolPath).Liquidity().ToString()
}

func (i *poolV1) MustGetPosition(poolPath, key string) *pl.PositionInfo {
	return i.mustGetPositionInfo(poolPath, key)
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
	return i.mustGetTickInfo(poolPath, tick).LiquidityGross().ToString()
}

func (i *poolV1) GetTickLiquidityNet(poolPath string, tick int32) string {
	return i.mustGetTickInfo(poolPath, tick).LiquidityNet().ToString()
}

func (i *poolV1) GetTickFeeGrowthOutside0X128(poolPath string, tick int32) string {
	return i.mustGetTickInfo(poolPath, tick).FeeGrowthOutside0X128().ToString()
}

func (i *poolV1) GetTickFeeGrowthOutside1X128(poolPath string, tick int32) string {
	return i.mustGetTickInfo(poolPath, tick).FeeGrowthOutside1X128().ToString()
}

func (i *poolV1) GetTickCumulativeOutside(poolPath string, tick int32) int64 {
	return i.mustGetTickInfo(poolPath, tick).TickCumulativeOutside()
}

func (i *poolV1) GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string {
	return i.mustGetTickInfo(poolPath, tick).SecondsPerLiquidityOutsideX128().ToString()
}

func (i *poolV1) GetTickSecondsOutside(poolPath string, tick int32) uint32 {
	return i.mustGetTickInfo(poolPath, tick).SecondsOutside()
}

func (i *poolV1) GetTickInitialized(poolPath string, tick int32) bool {
	return i.mustGetTickInfo(poolPath, tick).Initialized()
}

func (i *poolV1) GetSlot0Tick(poolPath string) int32 {
	return i.mustGetPoolCore(poolPath).Slot0Tick()
}

func (i *poolV1) GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	return i.mustGetPoolCore(poolPath).Slot0SqrtPriceX96().Clone()
}

func (i *poolV1) GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	pool := i.mustGetPoolCore(poolPath)
	return pool.FeeGrowthGlobal0X128().Clone(), pool.FeeGrowthGlobal1X128().Clone()
}

func (i *poolV1) GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (*u256.Uint, *u256.Uint) {
	tickInfo := i.mustGetTickInfo(poolPath, tick)
	return tickInfo.FeeGrowthOutside0X128().Clone(), tickInfo.FeeGrowthOutside1X128().Clone()
}

func (i *poolV1) GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	position := i.MustGetPosition(poolPath, key)
	return position.FeeGrowthInside0LastX128().Clone(), position.FeeGrowthInside1LastX128().Clone()
}

func (i *poolV1) GetPositionLiquidity(poolPath, key string) *u256.Uint {
	position := i.MustGetPosition(poolPath, key)
	return position.Liquidity().Clone()
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
	if !i.ExistsPoolPath(poolPath) {
		panic(makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("expected poolPath(%s) to exist", poolPath)))
	}

	observationState := i.mustGetPoolCore(poolPath).ObservationState()

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

	_ = secondsAgo

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
	pool := i.mustGetPoolCore(poolPath)
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
	if !i.ExistsPoolPath(poolPath) {
		return 0
	}

	return i.store.GetPoolPositions(poolPath).Size()
}

// GetPoolPositionKeys returns a paginated list of position keys in a pool.
func (i *poolV1) GetPoolPositionKeys(poolPath string, offset, count int) []string {
	if !i.ExistsPoolPath(poolPath) {
		return []string{}
	}

	positionKeys := make([]string, 0)
	positions := i.store.GetPoolPositions(poolPath)

	positions.IterateByOffset(offset, count, func(key string, _ any) bool {
		positionKeys = append(positionKeys, key)
		return false
	})

	return positionKeys
}

// GetInitializedTicksInRange returns initialized ticks within the given range.
func (i *poolV1) GetInitializedTicksInRange(poolPath string, tickLower, tickUpper int32) []int32 {
	if !i.ExistsPoolPath(poolPath) {
		return []int32{}
	}

	ticksTree := i.mustGetPoolCore(poolPath).Ticks()
	ticks := make([]int32, 0)
	startTickKey := pl.EncodeTickKey(tickLower)
	endTickKey := pl.EncodeTickKey(tickUpper + 1)

	ticksTree.Iterate(startTickKey, endTickKey, func(key string, _ any) bool {
		ticks = append(ticks, pl.DecodeTickKey(key))
		return false
	})

	return ticks
}

// GetTickInfo returns the tick info for a given tick.
func (i *poolV1) GetTickInfo(poolPath string, tick int32) (pl.TickInfo, error) {
	if !i.ExistsPoolPath(poolPath) {
		return pl.TickInfo{}, ufmt.Errorf("expected poolPath(%s) to exist", poolPath)
	}

	tickInfo, err := i.mustGetPoolCore(poolPath).GetTick(tick)
	if err != nil {
		return pl.TickInfo{}, err
	}

	return tickInfo.Clone(), nil
}

// GetTickBitmaps returns the tick bitmap for a given word position.
func (i *poolV1) GetTickBitmaps(poolPath string, wordPos int16) (*u256.Uint, error) {
	if !i.ExistsPoolPath(poolPath) {
		return nil, ufmt.Errorf("expected poolPath(%s) to exist", poolPath)
	}

	tickBitmaps := i.mustGetPoolCore(poolPath).TickBitmaps()
	wordPosStr := strconv.Itoa(int(wordPos))

	iTickBitmap, ok := tickBitmaps.Get(wordPosStr)
	if !ok {
		return nil, ufmt.Errorf("tick bitmap %d not found", wordPos)
	}

	tickBitmap, ok := iTickBitmap.(*u256.Uint)
	if !ok {
		return nil, ufmt.Errorf("failed to cast tick bitmap: %T", iTickBitmap)
	}

	return tickBitmap.Clone(), nil
}

// GetPosition returns the position info for a given key.
func (i *poolV1) GetPosition(poolPath, key string) (pl.PositionInfo, error) {
	if !i.ExistsPoolPath(poolPath) {
		return pl.PositionInfo{}, ufmt.Errorf("expected poolPath(%s) to exist", poolPath)
	}

	positions := i.store.GetPoolPositions(poolPath)
	iPositionInfo, ok := positions.Get(key)
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
	if !i.ExistsPoolPath(poolPath) {
		return nil, ufmt.Errorf("expected poolPath(%s) to exist", poolPath)
	}

	observationState := i.mustGetPoolCore(poolPath).ObservationState()
	if observationState == nil {
		return nil, ufmt.Errorf("observation state not found for pool %s", poolPath)
	}

	return observationState, nil
}
