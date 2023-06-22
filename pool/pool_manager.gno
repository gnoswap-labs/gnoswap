package gnoswap

import (
	"std"

	"gno.land/p/demo/avl"

	bar "gno.land/r/bar"
	foo "gno.land/r/foo"
)

var (
	owner                std.Address
	initialized          bool = false
	feeAmountTickSpacing avl.Tree

	pools avl.Tree // map[string]*Pool
)

// XXX can it be init ?
func Init() {
	require(!initialized, "already initialized")
	owner = GetOrigCaller()
	// feeAmountTickSpacing.Set("100", 2)     // fee 0.01% // for stable coin pair
	feeAmountTickSpacing.Set("500", 10)    // fee 0.05%
	feeAmountTickSpacing.Set("3000", 60)   // fee 0.3%
	feeAmountTickSpacing.Set("10000", 200) // fee 1%
	initialized = true
}

func CreatePool(
	tokenA string, // XXX inter-contract token0 pkg_path
	tokenB string, // XXX inter-contract token1 pkg_path
	fee bigint,
	sqrtPriceX96 bigint,
) (pool *Pool) {
	require(initialized, "not initialized")
	require(tokenA != tokenB, "tokenA == tokenB")

	// XXX remove pool creation limit ?
	require(owner == GetOrigCaller(), "owner is not the origin caller!")

	// XXX check if token0, 1 has ben deployed
	// inter-contract call

	var token0, token1 string
	if tokenA < tokenB {
		token0 = tokenA
		token1 = tokenB
	} else {
		token0 = tokenB
		token1 = tokenA
	}

	// check tickSpacing for fee
	tickSpacing, ok := feeAmountTickSpacing.Get(string(fee))
	require(ok, "fee amount not enabled")
	require(tickSpacing != 0, "tickSpacing is 0")
	require(tickSpacing > 0, "tickSpacing is negative")

	// calculate poolKey
	poolKey := GetPoolKey(token0, token1, fee)

	// check whether the pool already exists
	_, ok = pools.Get(poolKey)
	if ok {
		panic("pool already exists")
	} else {
		pool := newPool(token0, token1, fee, bigint(tickSpacing), sqrtPriceX96)
		pools.Set(poolKey, pool)
		return pool
	}
}

func GetPool(token0, token1 string, fee bigint) *Pool {
	poolKey := GetPoolKey(token0, token1, fee)
	pool, ok := pools.Get(poolKey)
	require(ok, "pool not found")
	return pool.(*Pool)
	// return (*Pool)(pool)
}

func GetPoolFromPoolKey(poolKey string) *Pool {
	pool, ok := pools.Get(poolKey)
	require(ok, "pool not found")
	return pool.(*Pool)
	// return (*Pool)(pool)
}

func GetPoolKey(token0, token1 string, fee bigint) string {
	if token0 < token1 {
		return token0 + "_" + token1 + "_" + string(fee)
	} else {
		return token1 + "_" + token0 + "_" + string(fee)
	}
}

func newPool(
	token0 string,
	token1 string,
	fee bigint,
	tickSpacing bigint,
	sqrtPriceX96 bigint,
) *Pool {
	maxLiquidityPerTick := TickTickSpacingToMaxLiquidityPerTick(tickSpacing)
	tick := TickMathGetTickAtSqrtRatio(sqrtPriceX96)

	slot0 := Slot0{
		sqrtPriceX96: sqrtPriceX96,
		tick:         tick,
		feeProtocol:  0,
		unlocked:     true,
	}

	balances := Balances{
		token0: 0,
		token1: 0,
	}

	protocolFees := ProtocolFees{
		token0: 0,
		token1: 0,
	}

	// XXX dynamic import
	// inter-contract OR realm-banker...
	return &Pool{
		token0:               foo.GetGRC20(), // token0.GetGRC20() // gno.land/r/foo.GetGRC20()
		token1:               bar.GetGRC20(), // token1.GetGRC20() // gno.land/r/bar.GetGRC20()
		balances:             balances,
		fee:                  fee,
		tickSpacing:          tickSpacing,
		maxLiquidityPerTick:  maxLiquidityPerTick,
		slot0:                slot0,
		feeGrowthGlobal0X128: 0,
		feeGrowthGlobal1X128: 0,
		protocolFees:         protocolFees,
		liquidity:            0,
		ticks:                avl.Tree{},
		tickBitmaps:          avl.Tree{},
		positions:            avl.Tree{},
	}
}
