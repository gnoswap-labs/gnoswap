package v1

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
	pl "gno.land/r/gnoswap/pool"
)

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	return pl.GetPoolPath(token0Path, token1Path, fee)
}

// GetPool retrieves a pool instance based on the provided token paths and fee tier.
func (i *poolV1) GetPool(token0Path, token1Path string, fee uint32) *pl.Pool {
	poolPath := pl.GetPoolPath(token0Path, token1Path, fee)
	return i.mustGetPool(poolPath)
}

// GetFeeAmountTickSpacing retrieves the tick spacing associated with a given fee amount.
func (i *poolV1) GetFeeAmountTickSpacing(fee uint32) (spacing int32) {
	feeStr := formatUint(fee)

	feeAmountTickSpacing := i.store.GetFeeAmountTickSpacing()

	iTickSpacing, exist := feeAmountTickSpacing.Get(feeStr)
	if !exist {
		panic(newErrorWithDetail(
			errUnsupportedFeeTier,
			ufmt.Sprintf("expected fee(%d) to be one of %d, %d, %d, %d", fee, FeeTier100, FeeTier500, FeeTier3000, FeeTier10000),
		))
	}

	spacing, ok := iTickSpacing.(int32)
	if !ok {
		panic("failed to cast tick spacing to int32")
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
	return i.store.GetPools().Has(poolPath)
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
