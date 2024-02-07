package pool

import (
	"std"
	"strconv"

	"gno.land/p/demo/common"
	"gno.land/p/demo/u256"
	"gno.land/p/demo/ufmt"

	gns "gno.land/r/demo/gns"
)

var (
	admins      []std.Address
	initialized bool = false

	feeAmountTickSpacing map[uint16]int32 = make(map[uint16]int32) // map[feeAmount]tick_spacing
	pools                map[string]*Pool = make(map[string]*Pool) // map[poolPath]*Pool
)

func InitManual() {
	// MUST BE ORIGIN CALLER
	std.AssertOriginCall()
	require(!initialized, ufmt.Sprintf("[POOl] pool_manager.gno__InitManual() || expected initialized(%t) == false", initialized))
	require(std.GetOrigCaller() == consts.GNOSWAP_ADMIN, ufmt.Sprintf("[POOl] pool_manager.gno__InitManual() || expected std.GetOrigCaller(%s) == consts.GNOSWAP_ADMIN(%s)", std.GetOrigCaller().String(), consts.GNOSWAP_ADMIN.String()))
	feeAmountTickSpacing[100] = 2     // 0.01%
	feeAmountTickSpacing[500] = 10    // 0.05%
	feeAmountTickSpacing[3000] = 60   // 0.3%
	feeAmountTickSpacing[10000] = 200 // 1%
	admins = append(admins, std.PrevRealm().Addr())
	initialized = true
}

func CreatePool(
	token0Path string,
	token1Path string,
	fee uint16,
	sqrtPriceX96_ bigint,
) *Pool {
	require(initialized, ufmt.Sprintf("[POOl] pool_manager.gno__gno__CreatePool() || expected initialized(%t) == true", initialized))
	require(token0Path != token1Path, ufmt.Sprintf("[POOl] pool_manager.gno__CreatePool() || expected token0Path(%s) != token1Path(%s)", token0Path, token1Path))

	sqrtPriceX96 := u256.FromBigint(sqrtPriceX96_)

	if tokenBPath < tokenAPath {
		tokenAPath, tokenBPath = tokenBPath, tokenAPath
		tick := -(TickMathGetTickAtSqrtRatio(sqrtPriceX96))
		sqrtPriceX96 = TickMathGetSqrtRatioAtTick(tick)
	}

	// check tickSpacing for fee
	tickSpacing := feeAmountTickSpacing[fee]
	requirePositive(bigint(tickSpacing), ufmt.Sprintf("[POOL] pool_manager.gno__CreatePool() || expected tickSpacing(%d) > 0", tickSpacing))

	// calculate poolPath
	poolPath := GetPoolPath(token0Path, token1Path, fee)

	// check whether the pool already exist
	pool, exist := pools[poolPath]
	requireExist(!exist, ufmt.Sprintf("[POOl] pool_manager.gno__CreatePool() || expected poolPath(%s) not to exist", poolPath))

	if !exist {
		gns.TransferFrom(a2u(std.GetOrigCaller()), a2u(consts.GNOSWAP_ADMIN), consts.POOL_CREATION_FEE)

		pool = newPool(token0Path, token1Path, fee, tickSpacing, sqrtPriceX96)
		pools[poolPath] = pool
	}

	return pool
}

func GetPool(token0Path, token1Path string, fee uint16) *Pool {
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] pool_manager.gno__GetPool() || expected poolPath(%s) to exist", poolPath))

	return pool
}

func GetPoolFromPoolPath(poolPath string) *Pool {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] pool_manager.gno__GetPoolFromPoolPath() || expected poolPath(%s) to exist", poolPath))

	return pool
}

func GetPoolPath(token0Path, token1Path string, fee uint16) string {
	if token0Path < token1Path {
		return token0Path + ":" + token1Path + ":" + strconv.Itoa(int(fee))
	} else {
		return token1Path + ":" + token0Path + ":" + strconv.Itoa(int(fee))
	}
}

func AddAdmin(addr std.Address) {
	caller := std.PrevRealm().Addr()
	if isAdmin(caller) {
		admins = append(admins, addr)
	} else {
		panic(ufmt.Sprintf("[POOL] pool_manager.gno__AddAdmin() || caller(%s) is not admin", caller.String()))
	}
}

func RemoveAdmin(addr std.Address) {
	caller := std.PrevRealm().Addr()

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
		panic(ufmt.Sprintf("[POOL] pool_manager.gno__RemoveAdmin() || caller(%s) is not admin", caller.String()))
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
	tick := common.TickMathGetTickAtSqrtRatio(sqrtPriceX96)

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

	return &Pool{
		token0Path:           token0Path,
		token1Path:           token1Path,
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
