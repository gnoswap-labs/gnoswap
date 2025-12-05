package v1

import (
	"chain/runtime"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
)

const MAX_UINT256 string = "115792089237316195423570985008687907853269984665640564039457584007913129639935"

func (p *positionV1) ApiGetPosition(id uint64) string {
	exist := p.ExistPosition(id)
	if !exist {
		return ""
	}

	rpcPosition := p.rpcMakePosition(id)
	baseStat := NewResponseQueryBase(runtime.ChainHeight(), time.Now().Unix())
	return makeJsonResponse(&baseStat, &PositionsResponse{
		Positions: []RpcPosition{rpcPosition},
		OwnerOf:   p.nftAccessor.OwnerOf,
	})
}

func (p *positionV1) ApiGetPositionUnclaimedFeeByPositionID(positionID uint64) string {
	unclaimedFee0, unclaimedFee1 := p.GetUnclaimedFee(positionID)
	fee := RpcUnclaimedFee{
		PositionID: positionID,
		Fee0:       unclaimedFee0.ToString(),
		Fee1:       unclaimedFee1.ToString(),
	}

	baseStat := NewResponseQueryBase(runtime.ChainHeight(), time.Now().Unix())
	return makeJsonResponse(&baseStat, &UnclaimedFeesResponse{
		Fees: []RpcUnclaimedFee{fee},
	})
}

func (p *positionV1) GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint) {
	// ref: https://blog.uniswap.org/uniswap-v3-math-primer-2#calculating-uncollected-fees
	position := p.mustGetPosition(positionId)

	liquidity := position.Liquidity()
	tickLower := position.TickLower()
	tickUpper := position.TickUpper()

	poolKey := position.PoolKey()

	currentTick := pl.GetSlot0Tick(poolKey)

	feeGrowthGlobal0X128, feeGrowthGlobal1X128 := pl.GetFeeGrowthGlobalX128(poolKey)
	tickUpperFeeGrowthOutside0X128, tickUpperFeeGrowthOutside1X128 := pl.GetTickFeeGrowthOutsideX128(poolKey, tickUpper)
	tickLowerFeeGrowthOutside0X128, tickLowerFeeGrowthOutside1X128 := pl.GetTickFeeGrowthOutsideX128(poolKey, tickLower)

	feeGrowthInside0LastX128 := position.FeeGrowthInside0LastX128()
	feeGrowthInside1LastX128 := position.FeeGrowthInside1LastX128()

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
	unclaimedFee0X128, overflow := u256.Zero().MulOverflow(liquidity, diffGrowthInside0X128)
	if overflow {
		panic(errOverflow)
	}
	unclaimedFee0 := u256.Zero().Div(unclaimedFee0X128, q128)

	diffGrowthInside1X128 := subUint256(feeGrowthInside1X128, feeGrowthInside1LastX128)
	unclaimedFee1X128, overflow := u256.Zero().MulOverflow(liquidity, diffGrowthInside1X128)
	if overflow {
		panic(errOverflow)
	}

	return unclaimedFee0, u256.Zero().Div(unclaimedFee1X128, q128)
}

func (p *positionV1) rpcMakePosition(positionId uint64) RpcPosition {
	position := p.mustGetPosition(positionId)

	poolKey := position.PoolKey()
	tickUpper := position.TickUpper()
	tickLower := position.TickLower()

	currentSqrtPriceX96 := pl.GetSlot0SqrtPriceX96(poolKey)
	lowerTickSqrtPriceX96 := common.TickMathGetSqrtRatioAtTick(tickLower)
	upperTickSqrtPriceX96 := common.TickMathGetSqrtRatioAtTick(tickUpper)

	calculatedToken0Balance, calculatedToken1Balance := common.GetAmountsForLiquidity(
		currentSqrtPriceX96,
		lowerTickSqrtPriceX96,
		upperTickSqrtPriceX96,
		position.Liquidity(),
	)

	token0Balance, token1Balance := position.Token0Balance(), position.Token1Balance()

	unclaimedFee0 := u256.Zero()
	unclaimedFee1 := u256.Zero()
	burned := p.IsBurned(positionId)
	if !burned {
		unclaimedFee0, unclaimedFee1 = p.GetUnclaimedFee(positionId)
	}

	owner, err := p.nftAccessor.OwnerOf(positionIdFrom(positionId))
	if err != nil {
		owner = zeroAddress
	}

	return RpcPosition{
		LpPositionId:             positionId,
		Burned:                   burned,
		Owner:                    owner.String(),
		Operator:                 position.Operator().String(),
		PoolKey:                  poolKey,
		TickLower:                tickLower,
		TickUpper:                tickUpper,
		Liquidity:                position.Liquidity().ToString(),
		FeeGrowthInside0LastX128: position.FeeGrowthInside0LastX128().ToString(),
		FeeGrowthInside1LastX128: position.FeeGrowthInside1LastX128().ToString(),
		TokensOwed0:              position.TokensOwed0().ToString(),
		TokensOwed1:              position.TokensOwed1().ToString(),
		Token0Balance:            token0Balance.ToString(),
		Token1Balance:            token1Balance.ToString(),
		CalculatedToken0Balance:  calculatedToken0Balance.ToString(),
		CalculatedToken1Balance:  calculatedToken1Balance.ToString(),
		FeeUnclaimed0:            unclaimedFee0.ToString(),
		FeeUnclaimed1:            unclaimedFee1.ToString(),
	}
}
