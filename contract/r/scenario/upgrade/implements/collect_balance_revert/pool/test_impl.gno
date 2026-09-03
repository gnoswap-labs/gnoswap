package collect_balance_revert

import (
	pool "gno.land/r/gnoswap/pool"
	v1 "gno.land/r/gnoswap/pool/v1"
)

type testPool struct {
	pool.IPool
	store pool.IPoolStore
}

func init(cur realm) {
	pool.RegisterInitializer(cross(cur), func(_ int, rlm realm, store pool.IPoolStore) pool.IPool {
		return &testPool{
			IPool: v1.NewPoolV1(store),
			store: store,
		}
	})
}

func (t *testPool) CollectSwapFee(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
) (string, string, string, string) {
	t.capToken0Balance(0, rlm, token0Path, token1Path, fee)
	return t.IPool.CollectSwapFee(0, rlm, token0Path, token1Path, fee, recipient, tickLower, tickUpper, amount0Requested, amount1Requested)
}

func (t *testPool) Collect(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	t.capToken0Balance(0, rlm, token0Path, token1Path, fee)
	return t.IPool.Collect(0, rlm, token0Path, token1Path, fee, recipient, tickLower, tickUpper, amount0Requested, amount1Requested)
}

func (t *testPool) capToken0Balance(_ int, rlm realm, token0Path, token1Path string, fee uint32) {
	pools := t.store.GetPools()
	poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
	storedPool := pools.Get(poolPath).(*pool.Pool)
	storedPool.SetBalanceToken0(1)
	pools.Set(poolPath, storedPool)
	if err := t.store.SetPools(0, rlm, pools); err != nil {
		panic(err)
	}
}
