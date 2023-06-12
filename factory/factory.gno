package factory

import (
	"std"
	"strconv"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/grc/grc20"

	p "gno.land/r/pool"
)

var (
	owner                std.Address
	feeAmountTickSpacing avl.Tree
	initialized          bool = false
)

// pools manages the mapping from the pool key (token0, token1, fee) to the pool struct
var pools avl.Tree // map[string]*Pool

// The argument token names should be gno package names
// Tokens are sorted alphabetically and concatenated with a colon
func getPoolKeyFromTokenNames(token0, token1 string, fee bigint) string {
	if token0 < token1 {
		return token0 + "_" + token1 + "_" + string(fee)
	} else {
		return token1 + "_" + token0 + "_" + string(fee)
	}
}

// not init, but Init
func Init() {
	require(initialized == false, "Already initialized")
	owner = std.GetOrigCaller()
	feeAmountTickSpacing.Set("500", 10)
	feeAmountTickSpacing.Set("3000", 60)
	feeAmountTickSpacing.Set("10000", 200)
	initialized = true
}

func CreatePool(
	tokenA string, // XXX inter-contract token0 pkg_path
	tokenB string, // XXX inter-contract token1 pkg_path
	fee bigint,
	sqrtPrice bigint,
) (pool *p.Pool) {
	require(tokenA != tokenB, "TokenA == TokenB")
	require(owner == GetOrigCaller(), "Owner is not the origin caller!")

	var token0, token1 string
	if tokenA < tokenB {
		token0 = tokenA
		token1 = tokenB
	} else {
		token0 = tokenB
		token1 = tokenA
	}
	// require(token0 != zeroAddress, "Token0 has not yet been deployed") // XXX check if zeroAddress is possible

	tickSpacing, _ := feeAmountTickSpacing.Get(string(fee))
	require(tickSpacing != 0, "TickSpacing is 0")

	poolKey := getPoolKeyFromTokenNames(token0, token1, fee)
	// println("poolKey:", poolKey)

	_pool, exists := pools.Get(poolKey)
	if !exists {
		pool = p.NewPool(token0, token1, fee, bigint(tickSpacing), sqrtPrice)
		pools.Set(poolKey, pool)
	} else {
		panic("Pool already exists")
		// pool = _pool.(*p.Pool)
	}

	return pool
}

func SetOwner(_owner std.Address) {
	require(std.GetOrigCaller() == owner, "Owner is not the origin caller!")
	owner = _owner
}

// WHO CALLS IT ?
func EnableFeeAmount(fee, tickSpacing bigint) {
	require(GetOrigCaller() == owner, "Owner is not the origin caller!")
	require(fee >= bigint(0), "Fee too low")
	require(fee < bigint(1000000), "Fee too high")
	require(tickSpacing > 0 && tickSpacing < 16384, "Tick spacing must be between 0 and 16384")
	_fee, ok := feeAmountTickSpacing.Get(string(fee))
	require(!ok, "Fee amount already enabled")
	// require(_fee == 0, "Fee amount already enabled")
	feeAmountTickSpacing.Set(string(fee), tickSpacing)
}

func getPool(token0, token1 string, fee bigint) *p.Pool {
	poolKey := getPoolKeyFromTokenNames(token0, token1, fee)
	pool, exists := pools.Get(poolKey)
	if !exists {
		panic("Pool does not exist")
	}
	return pool.(*p.Pool)
}

// utils
func require(cond bool, msg string) {
	if !cond {
		panic(msg)
	}
}
