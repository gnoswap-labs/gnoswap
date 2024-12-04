package pool

import (
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

func PoolGetSlot0Tick(poolPath string) int32 {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno()__PoolGetSlot0Tick || poolPath(%s) does not exist", poolPath),
		))
	}

	return pool.slot0.tick
}

func PoolGetSqrtPriceX96(poolPath string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno()__PoolGetSqrtPriceX96 || poolPath(%s) does not exist", poolPath),
		))
	}

	return pool.slot0.sqrtPriceX96
}

func PoolGetLiquidity(poolPath string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno()__PoolGetLiquidity || poolPath(%s) does not exist", poolPath),
		))
	}

	return pool.liquidity.ToString()
}

func GetPoolPositionLiquidity(poolPath, positionKey string) string {
	position := findPosition(poolPath, positionKey)
	return position.liquidity.ToString()
}

func GetPoolPositionFeeGrowthInside0LastX128(poolPath, positionKey string) string {
	position := findPosition(poolPath, positionKey)
	return position.feeGrowthInside0LastX128.ToString()
}

func GetPoolPositionFeeGrowthInside1LastX128(poolPath, positionKey string) string {
	position := findPosition(poolPath, positionKey)
	return position.feeGrowthInside1LastX128.ToString()
}

func GetPoolPositionTokensOwed0(poolPath, positionKey string) string {
	position := findPosition(poolPath, positionKey)
	return position.tokensOwed0.ToString()
}

func GetPoolPositionTokensOwed1(poolPath, positionKey string) string {
	position := findPosition(poolPath, positionKey)
	return position.tokensOwed1.ToString()
}

func findPosition(poolPath, positionKey string) PositionInfo {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("findPosition || poolPath(%s) does not exist", poolPath),
		))
	}

	iposition, exist := pool.positions.Get(positionKey)
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("findPosition || position(%s) does not exist", positionKey),
		))
	}

	return iposition.(PositionInfo)
}
