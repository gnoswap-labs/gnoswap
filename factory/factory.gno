package factory

import (
	"std"
	"strconv"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/grc/grc20"

	"gno.land/r/bar"
	"gno.land/r/foo"
)

type Slot0 struct {
	sqrtPriceX96 bigint
	tick         bigint
	feeProtocol  bigint
	unlocked     bool
}

type Balances struct {
	token0 bigint
	token1 bigint
}

type ProtocolFees struct {
	token0 bigint
	token1 bigint
}

// type Pool describes a single Pool/s state
// A pool is identificed with a unique key (token0, token1, fee), where token0 < token1
type Pool struct {
	token0 *grc20.AdminToken // XXX inter-contract, => call {pkg_path}.GetGRC20()
	token1 *grc20.AdminToken // XXX inter-contract, => call {pkg_path}.GetGRC20()

	balances Balances

	// fee is the fee tier of the pool
	fee bigint

	// tickSpacing is the spacing between ticks
	tickSpacing bigint

	// maxLiquidityPerTick is the maximum amount of liquidity that can be added per tick
	maxLiquidityPerTick bigint

	// slot0 is the current tick and price of the pool
	slot0 Slot0

	feeGrowthGlobal0X128 bigint
	feeGrowthGlobal1X128 bigint

	// protocolFees is the amount of fees collected by the protocol
	// collected by CollectFeeProtocol()
	protocolFees ProtocolFees
	// liquidity is the total amount of liquidity in the pool
	liquidity bigint

	// ticks is a mapping from tick index to tick
	ticks avl.Tree
	// tickBitmaps is a mapping from tick index to tick bitmap
	tickBitmaps avl.Tree
	// positions maps the key (caller, lower tick, upper tick) to a unique position
	positions avl.Tree
}

var (
	owner                std.Address
	feeAmountTickSpacing avl.Tree
	initialized          bool = false
)

// pools manages the mapping from the pool key (token0, token1, fee) to the pool struct
var pools avl.Tree // map[string]*Pool
var poolKeys []string

// The argument token names should be gno package names
// Tokens are sorted alphabetically and concatenated with a colon
func GetPoolKeyFromTokenNames(token0, token1 string, fee bigint) string {
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
) (pool *Pool) {
	require(initialized, "Not initialized")
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

	tickSpacing, exist := feeAmountTickSpacing.Get(string(fee))
	require(exist, "Fee amount not enabled")
	require(tickSpacing != 0, "TickSpacing is 0")

	poolKey := GetPoolKeyFromTokenNames(token0, token1, fee)

	_pool, exists := pools.Get(poolKey)
	if !exists {
		pool = newPool(token0, token1, fee, bigint(tickSpacing), sqrtPrice)
		pools.Set(poolKey, pool)
		poolKeys = append(poolKeys, poolKey)
	} else {
		panic("Pool already exists")
	}

	return pool
}

func SetOwner(_owner std.Address) {
	require(initialized, "Not initialized")
	require(std.GetOrigCaller() == owner, "Owner is not the origin caller!")
	owner = _owner
}

// WHO CALLS IT ?
func EnableFeeAmount(fee, tickSpacing bigint) {
	require(initialized, "Not initialized")
	require(GetOrigCaller() == owner, "Owner is not the origin caller!")
	require(fee >= bigint(0), "Fee too low")
	require(fee < bigint(1000000), "Fee too high")
	require(tickSpacing > 0 && tickSpacing < 16384, "Tick spacing must be between 0 and 16384")
	_fee, ok := feeAmountTickSpacing.Get(string(fee))
	require(!ok, "Fee amount already enabled")
	// require(_fee == 0, "Fee amount already enabled")
	feeAmountTickSpacing.Set(string(fee), tickSpacing)
}

func GetPool(token0, token1 string, fee bigint) interface{} {
	require(initialized, "Not initialized")
	poolKey := GetPoolKeyFromTokenNames(token0, token1, fee)
	pool, exists := pools.Get(poolKey)
	if !exists {
		// panic("Pool does not exist")
		return nil
	}

	return pool
}

// for position -> pool -> facotry
func GetPoolFromKey(poolKey string) interface{} {
	require(initialized, "Not initialized")
	pool, exists := pools.Get(poolKey)
	if !exists {
		panic("Pool does not exist")
	}

	return pool
}

func newPool(
	token0 string, // token0 pkg_path
	token1 string, // token1 pkg_path
	fee bigint,
	tickSpacing bigint,
	sqrtPriceX96 bigint,
) *Pool {
	require(initialized, "Not initialized")

	// XXX how to handle admin
	if GetOrigCaller() != owner {
		panic("Not owner")
	}

	if GetPool(token0, token1, fee) != nil {
		panic("pool already exists")
	}

	maxLiquidityPerTick := TickTickSpacingToMaxLiquidityPerTick(tickSpacing)
	tick := TickMathGetTickAtSqrtRatio(sqrtPriceX96)

	slot0 := Slot0{
		sqrtPriceX96,
		tick,
		0,
		true,
	}

	tmpToken0 := foo.GetGRC20() // token0.GetGRC20() ~= gno.land/r/foo.GetGRC20()
	tmpToken1 := bar.GetGRC20() // token1.GetGRC20() ~= gno.land/r/bar.GetGRC20()

	balances := Balances{
		bigint(0), // token0 bal
		bigint(0), // token1 bal
	}

	protocolFees := ProtocolFees{
		bigint(0),
		bigint(0),
	}

	return &Pool{
		token0:               tmpToken0, // XXX inter contract ==> gno.land/r/{coin}
		token1:               tmpToken1, // XXX inter contract ==> gno.land/r/{coin}
		balances:             balances,
		fee:                  fee,
		tickSpacing:          tickSpacing,
		maxLiquidityPerTick:  maxLiquidityPerTick,
		slot0:                slot0,
		feeGrowthGlobal0X128: bigint(0),
		feeGrowthGlobal1X128: bigint(0),
		protocolFees:         protocolFees,
		liquidity:            bigint(0),
		ticks:                avl.Tree{}, // make(map[bigint]TickInfo)
		tickBitmaps:          avl.Tree{}, // make(map[bigint]bigint)
		positions:            avl.Tree{}, // make(map[string]PositionInfo)
	}
}

// perhaps it's better for us to remove factory and just use pool with some managing ability
// unsafe
func UpdateAvlTree(av avl.Tree, k string, v interface{}) {
	// XXX restrict caller
	// caller := GetOrigCaller()
	// pos := std.DerivePkgAddr("gno.land/r/position")

	// if caller != pos {
	// 	panic("Caller is not a position contract")
	// }

	av.Set(k, v)
}

// perhaps it's better for us to remove factory and just use pool with some managing ability
// unsafe
func RemoveAvlTree(av avl.Tree, k string) {
	// XXX restrict caller
	// caller := GetOrigCaller()
	// pos := std.DerivePkgAddr("gno.land/r/position")

	// if caller != pos {
	// 	panic("Caller is not a position contract")
	// }

	av.Remove(k)
}

func UpdateLiquidity(pl interface{}, liquidity bigint) {
	// pool := pl.(*Pool) // XX
	pool := (*Pool)(pl) // OO
	pool.liquidity = liquidity
}

func UpdateBalances(pl interface{}, amount0, amount1 bigint) {
	pool := (*Pool)(pl) // OO
	pool.balances.token0 += amount0
	pool.balances.token1 += amount1
}

// utils
func require(cond bool, msg string) {
	if !cond {
		panic(msg)
	}
}
