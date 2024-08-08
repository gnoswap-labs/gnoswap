package pool

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"
	en "gno.land/r/gnoswap/v2/emission"

	"gno.land/r/gnoswap/v2/gns"

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

// CreatePool creates a new concentrated liquidity pool with the given parameters.
// It mints and distributes GNS tokens, validates the input parameters, and creates a new pool.
// If GNOT is used as one of the tokens, it is automatically wrapped to WUGNOT.
// The function ensures that token0Path is lexicographically smaller than token1Path.
//
// Parameters:
//   - token0Path: The path of the first token
//   - token1Path: The path of the second token
//   - fee: The fee tier for the pool
//   - _sqrtPriceX96: The initial square root price of the pool as a decimal string
//
// Panics:
//   - If token0Path equals token1Path
//   - If the pool already exists
//   - If the fee amount is invalid
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
		std.Emit(
			"GNOSWAP_PROTOCOL_FEE",
			"m_callType", callType(),
			"m_origCaller", origCaller(),
			"m_prevRealm", prevRealm(),
			"poolPath", poolPath,
			"reason", "pool_creation",
			"token", consts.GNS_PATH,
			"amount", strconv.FormatUint(poolCreationFee, 10),
		)

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

// DoesPoolPathExist checks if a pool exists for the given poolPath.
//
// The poolPath is a unique identifier for a pool, combining token paths and fee.
func DoesPoolPathExist(poolPath string) bool {
	_, exist := pools[poolPath]
	return exist
}

// GetPool retrieves the pool for the given token paths and fee.
// It constructs the poolPath from the given parameters and returns the corresponding pool.
//
// Panics:
//   - If the pool does not exist
func GetPool(token0Path, token1Path string, fee uint32) *Pool {
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] pool_manager.gno__GetPool() || expected poolPath(%s) to exist", poolPath))
	}

	return pool
}

// GetPoolFromPoolPath retrieves the pool for the given poolPath.
//
// Panics:
//   - If the pool does not exist
func GetPoolFromPoolPath(poolPath string) *Pool {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] pool_manager.gno__GetPoolFromPoolPath() || expected poolPath(%s) to exist", poolPath))
	}

	return pool
}

// GetPoolPath generates a poolPath from the given token paths and fee.
// The poolPath is constructed by joining the token paths and fee with colons.
//
// For example, if token0Path is "A" and token1Path is "B" with a fee of 500, the poolPath will be:
//
//	"A:B:500"
//
// If token0Path is lexicographically greater than token1Path, the paths are swapped before constructing the poolPath.
//
//	"B:A:500"
//
// It ensures that the token paths are in lexicographic order.
//
// Parameters:
//   - token0Path: The path of the first token
//   - token1Path: The path of the second token
//   - fee: The fee tier of the pool
//
// Returns:
//   - string: The constructed poolPath
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	if token1Path < token0Path {
		token0Path, token1Path = token1Path, token0Path
	}

	var s strings.Builder
	s.WriteString(token0Path)
	s.WriteString(":")
	s.WriteString(token1Path)
	s.WriteString(":")
	s.WriteString(strconv.FormatUint(uint64(fee), 10))

	return s.String()
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
