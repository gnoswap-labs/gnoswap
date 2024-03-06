package pool

import (
	"std"
	"strconv"

	"gno.land/p/demo/common"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"

	"gno.land/r/demo/gns"

	u256 "gno.land/p/big/uint256"
)

var (
	admins      []std.Address
	initialized bool = false

	feeAmountTickSpacing map[uint32]int32 = make(map[uint32]int32) // map[feeAmount]tick_spacing
	pools                map[string]*Pool = make(map[string]*Pool) // map[poolPath]*Pool
)

func InitManual() {
	// MUST BE ORIGIN CALLER
	std.AssertOriginCall()
	if initialized {
		panic(ufmt.Sprintf("[POOl] pool_manager.gno__InitManual() || expected initialized(%t) == false", initialized))
	}

	if !(std.GetOrigCaller() == consts.GNOSWAP_ADMIN) {
		panic(ufmt.Sprintf("[POOl] pool_manager.gno__InitManual() || expected std.GetOrigCaller(%s) == consts.GNOSWAP_ADMIN(%s)", std.GetOrigCaller().String(), consts.GNOSWAP_ADMIN.String()))
	}

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
	fee uint32,
	_sqrtPriceX96 string, // uint
) *Pool {
	if !(initialized) {
		panic(ufmt.Sprintf("[POOl] pool_manager.gno__gno__CreatePool() || expected initialized(%t) == true", initialized))
	}

	if token0Path == token1Path {
		panic(ufmt.Sprintf("[POOl] pool_manager.gno__CreatePool() || expected token0Path(%s) != token1Path(%s)", token0Path, token1Path))
	}

	sqrtPriceX96, err := u256.FromDecimal(_sqrtPriceX96)
	if err != nil {
		panic("CREATE POOL SQRT STRING")
	}

	sqrtPriceX96, err := u256.FromDecimal(_sqrtPriceX96)
	if err != nil {
		panic("CREATE POOL SQRT STRING")
	}

	if token1Path < token0Path {
		token0Path, token1Path = token1Path, token0Path
		tick := -(common.TickMathGetTickAtSqrtRatio(sqrtPriceX96))
		sqrtPriceX96 = common.TickMathGetSqrtRatioAtTick(tick)
	}

	// check tickSpacing for fee
	tickSpacing := feeAmountTickSpacing[fee]
	// requirePositive(bigint(tickSpacing), ufmt.Sprintf("[POOL] pool_manager.gno__CreatePool() || expected tickSpacing(%d) > 0", tickSpacing))

	// calculate poolPath
	poolPath := GetPoolPath(token0Path, token1Path, fee)

	// check whether the pool already exist
	pool, exist := pools[poolPath]
	if exist {
		panic(ufmt.Sprintf("[POOl] pool_manager.gno__CreatePool() || expected poolPath(%s) not to exist", poolPath))
	}

	if !exist {
		gns.TransferFrom(a2u(std.GetOrigCaller()), a2u(consts.GNOSWAP_ADMIN), consts.POOL_CREATION_FEE)

		pool = newPool(token0Path, token1Path, fee, tickSpacing, sqrtPriceX96)
		pools[poolPath] = pool
	}

	return pool
}

func GetPool(token0Path, token1Path string, fee uint32) *Pool {
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] pool_manager.gno__GetPool() || expected poolPath(%s) to exist", poolPath))
	}

	return pool
}

func GetPoolFromPoolPath(poolPath string) *Pool {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] pool_manager.gno__GetPoolFromPoolPath() || expected poolPath(%s) to exist", poolPath))
	}

	return pool
}

func GetPoolPath(token0Path, token1Path string, fee uint32) string {
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
	fee uint32,
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
