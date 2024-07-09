package pool

import (
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/consts"
	en "gno.land/r/gnoswap/emission"

	"gno.land/r/gnoswap/gns"

	u256 "gno.land/p/gnoswap/uint256"
)

var (
	feeAmountTickSpacing map[uint32]int32 = make(map[uint32]int32) // maps fee to tickSpacing || map[feeAmount]tick_spacing
	pools                map[string]*Pool = make(map[string]*Pool) // maps poolPath to pool || map[poolPath]*Pool
)

func init() {
	feeAmountTickSpacing[100] = 1     // 0.01%
	feeAmountTickSpacing[500] = 10    // 0.05%
	feeAmountTickSpacing[3000] = 60   // 0.3%
	feeAmountTickSpacing[10000] = 200 // 1%
}

// CreatePool creates a new concentrated liquidity pool with the given token0Path, token1Path, fee, and sqrtPriceX96
// Each pool is identified by the poolPath, which is a combination of token0Path, token1Path, and fee
// It validates the contract initialization, pool existence, and token0Path and token1Path
// If validation passes, it calls newPool()
//
// Panics if any of the following conditions are met:
// - The pool already exists
// - Both token0Path and token1Path are the same
func CreatePool(
	token0Path string,
	token1Path string,
	fee uint32,
	_sqrtPriceX96 string, // uint256
) {
	en.MintAndDistributeGns()

	if token0Path == token1Path {
		panic(ufmt.Sprintf("[POOl] pool_manager.gno__CreatePool() || expected token0Path(%s) != token1Path(%s)", token0Path, token1Path))
	}

	if token0Path == consts.GNOT {
		token0Path = consts.WRAPPED_WUGNOT
	} else if token1Path == consts.GNOT {
		token1Path = consts.WRAPPED_WUGNOT
	}

	sqrtPriceX96 := u256.MustFromDecimal(_sqrtPriceX96)

	if token1Path < token0Path {
		token0Path, token1Path = token1Path, token0Path
		tick := -(common.TickMathGetTickAtSqrtRatio(sqrtPriceX96))
		sqrtPriceX96 = common.TickMathGetSqrtRatioAtTick(tick)
	}

	// check tickSpacing for fee
	tickSpacing := feeAmountTickSpacing[fee]
	// calculate poolPath
	poolPath := GetPoolPath(token0Path, token1Path, fee)

	// check whether the pool already exist
	pool, exist := pools[poolPath]
	if exist {
		panic(ufmt.Sprintf("[POOl] pool_manager.gno__CreatePool() || expected poolPath(%s) not to exist", poolPath))
	}

	if !exist {
		gns.TransferFrom(a2u(std.GetOrigCaller()), a2u(consts.PROTOCOL_FEE_ADDR), poolCreationFee)

		pool = newPool(token0Path, token1Path, fee, tickSpacing, sqrtPriceX96)
		pools[poolPath] = pool

		std.Emit(
			"GNOSWAP",
			"m_callType", callType(),
			"m_origCaller", origCaller(),
			"m_prevRealm", prevRealm(),
			"p_poolPath", poolPath,
		)
	}
}

// DoesPoolPathExist reports whether the pool exists with the given poolPath
func DoesPoolPathExist(poolPath string) bool {
	_, exist := pools[poolPath]
	return exist
}

// GetPool returns the pool with the given token0Path, token1Path, and fee
//
// Panics if any of the following conditions are met:
// - The pool does not exist
func GetPool(token0Path, token1Path string, fee uint32) *Pool {
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] pool_manager.gno__GetPool() || expected poolPath(%s) to exist", poolPath))
	}

	return pool
}

// GetPoolFromPoolPath returns the pool with the given poolPath
//
// Panics if any of the following conditions are met:
// - The pool does not exist
func GetPoolFromPoolPath(poolPath string) *Pool {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] pool_manager.gno__GetPoolFromPoolPath() || expected poolPath(%s) to exist", poolPath))
	}

	return pool
}

// GetPoolPath generates a poolPath from the given token0Path, token1Path, and fee
// If token0Path comes first in alphabetical order, it returns token0Path:token1Path:fee
// Otherwise, it returns token1Path:token0Path:fee
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	if token0Path < token1Path {
		return token0Path + ":" + token1Path + ":" + strconv.Itoa(int(fee))
	} else {
		return token1Path + ":" + token0Path + ":" + strconv.Itoa(int(fee))
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
