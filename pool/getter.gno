package pool

import (
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// PoolGetPoolList returns a list of all pool paths
func PoolGetPoolList() []string {
	poolPaths := []string{}
	for poolPath, _ := range pools {
		poolPaths = append(poolPaths, poolPath)
	}

	return poolPaths
}

// PoolGetSlot0Tick returns the tick of the certain pool
func PoolGetSlot0Tick(poolPath string) int32 {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("poolPath(%s) does not exist", poolPath),
		))
	}

	return pool.slot0.tick
}

// PoolGetSqrtPriceX96 returns the sqrt price in Q96 notation of the certain pool
func PoolGetSqrtPriceX96(poolPath string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("poolPath(%s) does not exist", poolPath),
		))
	}

	return pool.slot0.sqrtPriceX96
}

// PoolGetLiquidity returns the liquidity of the certain pool
func PoolGetLiquidity(poolPath string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("poolPath(%s) does not exist", poolPath),
		))
	}

	return pool.liquidity.ToString()
}
