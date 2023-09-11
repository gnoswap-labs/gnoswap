package pool

import (
	"std"
	"strconv"

	bar "gno.land/r/bar"
	foo "gno.land/r/foo"

	"gno.land/p/demo/ufmt"
)

var (
	admins      []std.Address
	initialized bool = false

	feeAmountTickSpacing map[uint16]int32 = make(map[uint16]int32) // map[fee_amount]tick_spacing
	pools                map[string]*Pool = make(map[string]*Pool) // map[pool_key]*Pool
)

func InitManual() {
	require(!initialized, "[POOl] pool_manager.gno__InitManual() || contract must not be initialized")
	feeAmountTickSpacing[100] = 2
	feeAmountTickSpacing[500] = 10
	feeAmountTickSpacing[3000] = 60
	feeAmountTickSpacing[10000] = 200
	admins = append(admins, PrevRealmAddr())
	initialized = true
}

func CreatePool(
	tokenA string, // XXX inter-contract token0 pkg_path
	tokenB string, // XXX inter-contract token1 pkg_path
	fee uint16,
	sqrtPriceX96 bigint,
) *Pool {
	require(initialized, "[POOl] pool_manager.gno__CreatePool() || contract must be initialized")
	require(tokenA != tokenB, ufmt.Sprintf("[POOl] pool_manager.gno__CreatePool() || token pair cannot be the same__tokenA(%s) != tokenB(%s)", tokenA, tokenB))

	// r3v4_xxx: check whether token pair has been deployed successfuly
	var token0, token1 string
	if tokenA < tokenB {
		token0 = tokenA
		token1 = tokenB
	} else {
		token0 = tokenB
		token1 = tokenA
	}

	// check tickSpacing for fee
	tickSpacing := feeAmountTickSpacing[fee]
	require(tickSpacing > 0, ufmt.Sprintf("[POOL] pool_manager.gno__CreatePool() || tickSpacing(%s) > 0", tickSpacing))

	// calculate poolKey
	poolKey := GetPoolKey(token0, token1, fee)

	// check whether the pool already exist
	pool, exist := pools[poolKey]
	require(!exist, ufmt.Sprintf("[POOl] pool_manager.gno__CreatePool() || pool(%s) already exist", poolKey))

	if !exist {
		pool = newPool(token0, token1, fee, tickSpacing, sqrtPriceX96)
		pools[poolKey] = pool
	}

	return pool
}

func GetPool(token0, token1 string, fee uint16) *Pool {
	poolKey := GetPoolKey(token0, token1, fee)
	pool, exist := pools[poolKey]
	require(exist, ufmt.Sprintf("[POOL] pool_manager.gno__GetPool() || pool(%s) not found", poolKey))

	return pool
}

func GetPoolFromPoolKey(poolKey string) *Pool {
	pool, exist := pools[poolKey]
	require(exist, ufmt.Sprintf("[POOL] pool_manager.gno__GetPoolFromPoolKey() || pool(%s) not found", poolKey))

	return pool
}

func GetPoolKey(token0, token1 string, fee uint16) string {
	if token0 < token1 {
		return token0 + "_" + token1 + "_" + strconv.Itoa(int(fee))
	} else {
		return token1 + "_" + token0 + "_" + strconv.Itoa(int(fee))
	}
}

func newPool(
	token0 string,
	token1 string,
	fee uint16,
	tickSpacing int32,
	sqrtPriceX96 bigint,
) *Pool {
	maxLiquidityPerTick := tickTickSpacingToMaxLiquidityPerTick(tickSpacing)
	tick := tickMathGetTickAtSqrtRatio(sqrtPriceX96)

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

	// r3v4_xxx: dynamic import need to support multi token
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
		ticks:                Ticks{},
		tickBitmaps:          TickBitmaps{},
		positions:            Positions{},
	}
}

func isAdmin(target std.Address) bool {
	for _, admin := range admins {
		if admin == target {
			return true
		}
	}

	// target isn't one of admins
	return false
}
