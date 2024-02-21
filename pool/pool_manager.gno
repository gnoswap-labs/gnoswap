package pool

import (
	"std"
	"strconv"

	"gno.land/p/demo/u256"
	"gno.land/p/demo/ufmt"

	gns "gno.land/r/demo/gns"
)

var (
	admins      []std.Address
	initialized bool = false

	feeAmountTickSpacing map[uint16]int32 = make(map[uint16]int32) // map[fee_amount]tick_spacing
	pools                map[string]*Pool = make(map[string]*Pool) // map[pool_key]*Pool
)

func InitManual() {
	require(!initialized, "[POOl] pool_manager.gno__InitManual() || contract must not be initialized")
	feeAmountTickSpacing[100] = 2     // 0.01%
	feeAmountTickSpacing[500] = 10    // 0.05%
	feeAmountTickSpacing[3000] = 60   // 0.3%
	feeAmountTickSpacing[10000] = 200 // 1%
	admins = append(admins, PrevRealmAddr())
	initialized = true
}

func CreatePool(
	tokenAPath string,
	tokenBPath string,
	fee uint16,
	sqrtPriceX96_ bigint,
) *Pool {
	require(initialized, "[POOl] pool_manager.gno__CreatePool() || contract must be initialized")
	require(tokenAPath != tokenBPath, ufmt.Sprintf("[POOl] pool_manager.gno__CreatePool() || token pair cannot be the same__tokenAPath(%s) != tokenBPath(%s)", tokenAPath, tokenBPath))

	sqrtPriceX96 := u256.FromBigint(sqrtPriceX96_)

	if tokenBPath < tokenAPath {
		tokenAPath, tokenBPath = tokenBPath, tokenAPath
		tick := -(TickMathGetTickAtSqrtRatio(sqrtPriceX96))
		sqrtPriceX96 = TickMathGetSqrtRatioAtTick(tick)
	}

	// check tickSpacing for fee
	tickSpacing := feeAmountTickSpacing[fee]
	require(tickSpacing > 0, ufmt.Sprintf("[POOL] pool_manager.gno__CreatePool() || tickSpacing(%d) > 0", tickSpacing))

	// calculate poolKey
	poolKey := GetPoolKey(tokenAPath, tokenBPath, fee)

	// check whether the pool already exist
	pool, exist := pools[poolKey]
	require(!exist, ufmt.Sprintf("[POOl] pool_manager.gno__CreatePool() || pool(%s) already exist", poolKey))

	if !exist {
		// 500 GNS as creation fee
		// recipent is same address that receives protocol fee
		// r3v4_xxx: change address when publish
		gns.TransferFrom(a2u(std.GetOrigCaller()), a2u(std.Address("g1vaekzh6lta047h6lta047h6lta047h6lutmjdk")), 500)

		pool = newPool(tokenAPath, tokenBPath, fee, tickSpacing, sqrtPriceX96)
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

func GetPoolKey(token0Path, token1Path string, fee uint16) string {
	if token0Path < token1Path {
		return token0Path + ":" + token1Path + ":" + strconv.Itoa(int(fee))
	} else {
		return token1Path + ":" + token0Path + ":" + strconv.Itoa(int(fee))
	}
}

func AddAdmin(addr std.Address) {
	caller := PrevRealmAddr()
	if isAdmin(caller) {
		admins = append(admins, addr)
	} else {
		panic("[POOL] pool_manager.gno__AddAdmin() || caller is not admin") // r3v4_xx: detailed error message ??
	}
}

func RemoveAdmin(addr std.Address) {
	caller := PrevRealmAddr()

	if isAdmin(caller) {
		if len(admins) == 1 {
			panic("[POOL] pool_manager.gno__RemoveAdmin() || cannot remove last admin")
		}
		for i, v := range admins {
			if v == addr {
				admins = append(admins[:i], admins[i+1:]...)
				return
			}
		}
	} else {
		panic("[POOL] pool_manager.gno__RemoveAdmin() || caller is not admin") // r3v4_xx: detailed error message ??
	}
}

func newPool(
	token0Path string,
	token1Path string,
	fee uint16,
	tickSpacing int32,
	sqrtPriceX96 *u256.Uint,
) *Pool {
	maxLiquidityPerTick := tickTickSpacingToMaxLiquidityPerTick(tickSpacing)
	tick := TickMathGetTickAtSqrtRatio(sqrtPriceX96)

	slot0 := Slot0{
		sqrtPriceX96: sqrtPriceX96,
		tick:         tick,
		feeProtocol:  0,
		unlocked:     true,
	}

	balances := Balances{
		token0: u256.Zero(),
		token1: u256.Zero(),
	}

	protocolFees := ProtocolFees{
		token0: u256.Zero(),
		token1: u256.Zero(),
	}

	return &Pool{
		token0Path:           token0Path,
		token1Path:           token1Path,
		balances:             balances,
		fee:                  fee,
		tickSpacing:          tickSpacing,
		maxLiquidityPerTick:  maxLiquidityPerTick,
		slot0:                slot0,
		feeGrowthGlobal0X128: u256.Zero(),
		feeGrowthGlobal1X128: u256.Zero(),
		protocolFees:         protocolFees,
		liquidity:            u256.Zero(),
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
