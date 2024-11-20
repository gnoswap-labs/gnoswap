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
