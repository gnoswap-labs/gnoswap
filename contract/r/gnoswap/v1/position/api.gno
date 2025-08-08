package position

import (
	"std"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gnft"
	pl "gno.land/r/gnoswap/v1/pool"
)

const MAX_UINT256 string = "115792089237316195423570985008687907853269984665640564039457584007913129639935"

func ApiGetPosition(id uint64) string {
	_, exist := GetPosition(id)
	if !exist {
		return ""
	}

	rpcPosition := rpcMakePosition(id)
	baseStat := NewResponseQueryBase(std.ChainHeight(), time.Now().Unix())
	return makeJsonResponse(&baseStat, &PositionsResponse{Positions: []RpcPosition{rpcPosition}})
}

func ApiGetPositionUnclaimedFeeByLpPositionId(lpPositionId uint64) string {
	unclaimedFee0, unclaimedFee1 := unclaimedFee(lpPositionId)
	fee := RpcUnclaimedFee{
		LpPositionId: lpPositionId,
		Fee0:         unclaimedFee0.ToString(),
		Fee1:         unclaimedFee1.ToString(),
	}

	baseStat := NewResponseQueryBase(std.ChainHeight(), time.Now().Unix())
	return makeJsonResponse(&baseStat, &UnclaimedFeesResponse{
		Fees: []RpcUnclaimedFee{fee},
	})
}

func rpcMakePosition(positionId uint64) RpcPosition {
	position := MustGetPosition(positionId)

	currentSqrtPriceX96 := pl.GetSlot0SqrtPriceX96(position.poolKey)
	lowerTickSqrtPriceX96 := common.TickMathGetSqrtRatioAtTick(position.tickLower)
	upperTickSqrtPriceX96 := common.TickMathGetSqrtRatioAtTick(position.tickUpper)

	calculatedToken0Balance, calculatedToken1Balance := common.GetAmountsForLiquidity(
		currentSqrtPriceX96,
		lowerTickSqrtPriceX96,
		upperTickSqrtPriceX96,
		position.liquidity,
	)

	token0Balance, token1Balance := position.token0Balance, position.token1Balance

	unclaimedFee0 := u256.Zero()
	unclaimedFee1 := u256.Zero()
	burned := IsBurned(positionId)
	if !burned {
		unclaimedFee0, unclaimedFee1 = unclaimedFee(positionId)
	}

	owner, err := gnft.OwnerOf(positionIdFrom(positionId))
	if err != nil {
		owner = zeroAddress
	}

	return RpcPosition{
		LpPositionId:             positionId,
		Burned:                   burned,
		Owner:                    owner.String(),
		Operator:                 position.operator.String(),
		PoolKey:                  position.poolKey,
		TickLower:                position.tickLower,
		TickUpper:                position.tickUpper,
		Liquidity:                position.liquidity.ToString(),
		FeeGrowthInside0LastX128: position.feeGrowthInside0LastX128.ToString(),
		FeeGrowthInside1LastX128: position.feeGrowthInside1LastX128.ToString(),
		TokensOwed0:              position.tokensOwed0.ToString(),
		TokensOwed1:              position.tokensOwed1.ToString(),
		Token0Balance:            token0Balance.ToString(),
		Token1Balance:            token1Balance.ToString(),
		CalculatedToken0Balance:  calculatedToken0Balance,
		CalculatedToken1Balance:  calculatedToken1Balance,
		FeeUnclaimed0:            unclaimedFee0.ToString(),
		FeeUnclaimed1:            unclaimedFee1.ToString(),
	}
}

func UnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint) {
	return unclaimedFee(positionId)
}

func unclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint) {
	// ref: https://blog.uniswap.org/uniswap-v3-math-primer-2#calculating-uncollected-fees

	position := MustGetPosition(positionId)

	liquidity := position.liquidity
	tickLower := position.tickLower
	tickUpper := position.tickUpper

	poolKey := position.poolKey

	currentTick := pl.GetSlot0Tick(poolKey)

	feeGrowthGlobal0X128, feeGrowthGlobal1X128 := pl.GetFeeGrowthGlobalX128(poolKey)
	tickUpperFeeGrowthOutside0X128, tickUpperFeeGrowthOutside1X128 := pl.GetTickFeeGrowthOutsideX128(poolKey, tickUpper)
	tickLowerFeeGrowthOutside0X128, tickLowerFeeGrowthOutside1X128 := pl.GetTickFeeGrowthOutsideX128(poolKey, tickLower)

	feeGrowthInside0LastX128 := position.feeGrowthInside0LastX128
	feeGrowthInside1LastX128 := position.feeGrowthInside1LastX128

	var tickLowerFeeGrowthBelow0, tickLowerFeeGrowthBelow1, tickUpperFeeGrowthAbove0, tickUpperFeeGrowthAbove1 *u256.Uint

	if currentTick >= tickUpper {
		tickUpperFeeGrowthAbove0 = subUint256(feeGrowthGlobal0X128, tickUpperFeeGrowthOutside0X128)
		tickUpperFeeGrowthAbove1 = subUint256(feeGrowthGlobal1X128, tickUpperFeeGrowthOutside1X128)
	} else {
		tickUpperFeeGrowthAbove0 = tickUpperFeeGrowthOutside0X128
		tickUpperFeeGrowthAbove1 = tickUpperFeeGrowthOutside1X128
	}

	if currentTick >= tickLower {
		tickLowerFeeGrowthBelow0 = tickLowerFeeGrowthOutside0X128
		tickLowerFeeGrowthBelow1 = tickLowerFeeGrowthOutside1X128
	} else {
		tickLowerFeeGrowthBelow0 = subUint256(feeGrowthGlobal0X128, tickLowerFeeGrowthOutside0X128)
		tickLowerFeeGrowthBelow1 = subUint256(feeGrowthGlobal1X128, tickLowerFeeGrowthOutside1X128)
	}

	feeGrowthInside0X128 := subUint256(feeGrowthGlobal0X128, tickLowerFeeGrowthBelow0)
	feeGrowthInside0X128 = subUint256(feeGrowthInside0X128, tickUpperFeeGrowthAbove0)

	feeGrowthInside1X128 := subUint256(feeGrowthGlobal1X128, tickLowerFeeGrowthBelow1)
	feeGrowthInside1X128 = subUint256(feeGrowthInside1X128, tickUpperFeeGrowthAbove1)

	diffGrowthInside0X128 := subUint256(feeGrowthInside0X128, feeGrowthInside0LastX128)
	unclaimedFee0X128 := u256.Zero().Mul(liquidity, diffGrowthInside0X128)
	unclaimedFee0 := u256.Zero().Div(unclaimedFee0X128, u256.MustFromDecimal(Q128))

	diffGrowthInside1X128 := subUint256(feeGrowthInside1X128, feeGrowthInside1LastX128)
	unclaimedFee1X128 := u256.Zero().Mul(liquidity, diffGrowthInside1X128)
	unclaimedFee1 := u256.Zero().Div(unclaimedFee1X128, u256.MustFromDecimal(Q128))

	return unclaimedFee0, unclaimedFee1
}

func IsBurned(positionId uint64) bool {
	position := MustGetPosition(positionId)
	return position.burned
}
