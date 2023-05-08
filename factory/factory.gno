package factory

import (
	"std"
	"strconv"

	"gno.land/p/demo/avl"
)

var (
	owner std.Address
	feeAmountTickSpacing avl.Tree
	getPool avl.Tree
)

// pools manages the mapping from the pool key (token0, token1, fee) to the pool struct
var pools map[string]*Pool

// The argument token names should be gno package names
// Tokens are sorted alphabetically and concatenated with a colon
func getPoolKeyFromTokenNames(token0, token1 string, fee bigint) string {
	if token0 < token1 {
		return token0 + ":" + token1 + ":" + strconv.Itoa(int(fee))
	} else {
		return token1 + ":" + token0 + ":" + strconv.Itoa(int(fee))
	}
}

func Init() {
	// can we init with parameters?
	owner = std.GetOrigCaller()
	feeAmountTickSpacing.Set("500", 10)
	feeAmountTickSpacing.Set("3000", 60)
	feeAmountTickSpacing.Set("10000", 200)
}

func CreatePool(
	tokenA std.Address,
	tokenB std.Address,
	fee bigint,
	sqrtPrice bigint,
	tick bigint,
) (pool std.Address) {
	require(tokenA != tokenB, "TokenA == TokenB")
	requrie(owner == GetOrigCaller(), "Owner is not the origin caller!")

	var token0 std.Address
	var token1 std.Address
	if tokenA < tokenB {
		token0 = tokenA
		token1 = tokenB
	} else {
		token0 = tokenB
		token1 = tokenA
	}
	require(token0 != zeroAddress, "Token0 has not yet been deployed") // XXX check if zeroAddress is possible
	
	tickSpacing, _ := feeAmountTickSpacing.Get(string(fee))
	require(tickSpacing != 0, "TickSpacing is 0")

	// XXX
	// check if nested avl.Tree is possible
	// => if possible compare nested avl.Tree
	// => if not, use map
	// Create2 + Dynamic Import need
	poolKey1 := getPoolKeyFromAddress(token0, token1, fee)
	pool, ok := pools.Get(poolKey1)
	if !ok {
		pools.Set(poolKey1, NewPool(token0, token1, fee, tickSpacing, sqrtPrice, tick)) // XXX init avl set possible
//		pools.Set(poolKey2, avl.Tree)
	}
	// nested avl.Tree [pools[poolKey1][fee]
	// poolWithFee, ok := pool.Get(poolKey1)

/*
	_tmpAddr := string(tokenA) + string(tokenB) + strconv.Itoa(int(fee))
	pool = std.Address(_tmpAddr)
*/
	// fix nested avl.Tree thing

	return pool
}

func getPool(token0, token1 string, fee bigint) *Pool {
	poolKey := getPoolKeyFromAddress(token0, token1, fee)
	pool, ok := pools.Get(poolKey)
	require(ok, "Pool does not exist")
	return pool
}



func SetOwner(_owner std.Address) {
	require(std.GetOrigCaller() == owner, "Owner is not the origin caller!")
	owner = _owner
}

func EnableFeeAmount(fee, tickSpacing bigint) {
	require(GetOrigCaller() == owner, "Owner is not the origin caller!")
	require(fee < 1000000, "Fee too high")
	require(tickSpacing > 0 && tickSpacing < 16384, "Tick spacing must be between 0 and 16384")
	_fee, ok := feeAmountTickSpacing.Get(string(fee))
	require(!ok, "Fee amount already enabled")
	// require(_fee == 0, "Fee amount already enabled")
	feeAmountTickSpacing.Set(string(fee), tickSpacing)
}

// helepr
func require(cond bool, msg string) {
	if !cond {
		panic(msg)
	}
}

// XXX
func getPoolKeyFromAddress(token0, token1 std.Address) string { // XXX std.Address
	if token0 < token1 {
		return string(token0) + string(token1)
	} else {
		return string(token1) + string(token0)
	}
}

func PoolMint(token0 string, token1 string, fee bigint, recipient std.Address, tickLower bigint, tickUpper bigint, amount bigint) (bigint, bigint) {
	pool := getPool(token0, token1, fee)
	return pool.Mint(recipient, tickLower, tickUpper, amount)
}

func PoolBurn(token0 string, token1 string, fee bigint, tickLower bigint, tickUpper bigint, amount bigint) (bigint, bigint) {
	pool := getPool(token0, token1, fee)
	return pool.Burn(tickLower, tickUpper, amount)
}

func PoolCollect(token0 string, token1 string, fee bigint, recipient std.Address, tickLower bigint, tickUpper bigint, amount0Requested bigint, amount1Requested bigint) (bigint, bigint) {
	pool := getPool(token0, token1, fee)
	return pool.Collect(recipient, tickLower, tickUpper, amount0Requested, amount1Requested)
}

func PoolSwap(token0 string, token1 string, fee bigint, recipient std.Address, zeroForOne bool, amountSpecified bigint, sqrtPriceLimit bigint) (bigint, bigint) {
	pool := getPool(token0, token1, fee)
	return pool.Swap(recipient, zeroForOne, amountSpecified, sqrtPriceLimit)
}

