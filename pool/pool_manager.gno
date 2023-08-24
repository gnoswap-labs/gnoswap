package gnoswap

import (
	"std"

	bar "gno.land/r/bar"
	foo "gno.land/r/foo"
)

var (
	admins      []std.Address
	initialized bool = false

	feeAmountTickSpacing map[bigint]bigint = make(map[bigint]bigint) // map[fee_amount]tick_spacing
	pools                map[string]*Pool  = make(map[string]*Pool)  // map[pool_key]*Pool
)

// XXX can it be init ?
func Init() {
	require(!initialized, "already initialized")
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
	fee bigint,
	sqrtPriceX96 bigint,
) *Pool {
	require(initialized, "not initialized")
	require(tokenA != tokenB, "tokenA == tokenB")

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
	tickSpacing := feeAmountTickSpacing[fee]
	require(tickSpacing > 0, "tickSpacing is not valid")

	// calculate poolKey
	poolKey := GetPoolKey(token0, token1, fee)

	// check whether the pool already exist
	pool, exist := pools[poolKey]
	require(!exist, "pool already exist")
	if !exist {
		pool = newPool(token0, token1, fee, bigint(tickSpacing), sqrtPriceX96)
		pools[poolKey] = pool
	}

	return pool
}

func GetPool(token0, token1 string, fee bigint) *Pool {
	poolKey := GetPoolKey(token0, token1, fee)
	pool, exist := pools[poolKey]
	require(exist, "pool not found")

	return pool
}

func GetPoolFromPoolKey(poolKey string) *Pool {
	pool, exist := pools[poolKey]
	require(exist, "pool not found")

	return pool
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
		ticks:                Ticks{},
		tickBitmaps:          TickBitmaps{},
		positions:            Positions{},
	}
}

func IsAdmin(target std.Address) bool {
	for _, admin := range admins {
		if admin == target {
			return true
		}
	}

	// target isn't one of admins
	return false
}
