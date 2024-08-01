package pool

import (
	"gno.land/p/demo/ufmt"
)

func PoolGetSlot0Tick(poolPath string) int32 {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetSlot0Tick() || pool(%s) does not exist", poolPath))
	}

	return pool.slot0.tick
}

func PoolGetLiquidity(poolPath string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetLiquidity() || pool(%s) does not exist", poolPath))
	}

	return pool.liquidity.ToString()
}
