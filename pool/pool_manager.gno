package pool

import (
	"std"
	"strings"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	en "gno.land/r/gnoswap/v1/emission"

	"gno.land/r/gnoswap/v1/gns"

	u256 "gno.land/p/gnoswap/uint256"
)

var (
	feeAmountTickSpacing map[uint32]int32 = make(map[uint32]int32) // maps fee to tickSpacing || map[feeAmount]tick_spacing
	pools                map[string]*Pool = make(map[string]*Pool) // maps poolPath to pool || map[poolPath]*Pool

	slot0FeeProtocol uint8 = 0
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
// ref: https://docs.gnoswap.io/contracts/pool/pool_manager.gno#createpool
func CreatePool(
	token0Path string,
	token1Path string,
	fee uint32,
	_sqrtPriceX96 string, // uint256
) {
	common.IsHalted()
	en.MintAndDistributeGns()

	if token0Path == token1Path {
		panic(addDetailToError(
			errDuplicateTokenInPool,
			ufmt.Sprintf("pool_manager.gno__CreatePool() || expected token0Path(%s) != token1Path(%s)", token0Path, token1Path),
		))
	}

	// wrap first
	if token0Path == consts.GNOT {
		token0Path = consts.WRAPPED_WUGNOT
	} else if token1Path == consts.GNOT {
		token1Path = consts.WRAPPED_WUGNOT
	}

	// then check if token0Path == token1Path
	if token0Path == token1Path {
		panic(addDetailToError(
			errDuplicateTokenInPool,
			ufmt.Sprintf("pool_manager.gno__CreatePool() || expected token0Path(%s) != token1Path(%s)", token0Path, token1Path),
		))
	}

	sqrtPriceX96 := u256.MustFromDecimal(_sqrtPriceX96)

	if token1Path < token0Path {
		panic(addDetailToError(
			errTokenSortOrder,
			ufmt.Sprintf("pool_manager.gno__CreatePool() || expected token0Path(%s) < token1Path(%s)", token0Path, token1Path),
		))
	}

	// check tickSpacing for fee
	tickSpacing := feeAmountTickSpacing[fee]
	// calculate poolPath
	poolPath := GetPoolPath(token0Path, token1Path, fee)

	// check whether the pool already exist
	pool, exist := pools[poolPath]
	if exist {
		panic(addDetailToError(
			errPoolAlreadyExists,
			ufmt.Sprintf("pool_manager.gno__CreatePool() || expected poolPath(%s) not to exist", poolPath),
		))
	}

	prevAddr, prevRealm := getPrev()
	if !exist {
		gns.TransferFrom(a2u(std.PrevRealm().Addr()), a2u(consts.PROTOCOL_FEE_ADDR), poolCreationFee)
		std.Emit(
			"PoolCreationFee",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"internal_poolPath", poolPath,
			"internal_tokenPath", consts.GNS_PATH,
			"internal_amount", ufmt.Sprintf("%d", poolCreationFee),
		)

		pool = newPool(token0Path, token1Path, fee, tickSpacing, sqrtPriceX96)
		pools[poolPath] = pool

		std.Emit(
			"CreatePool",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"token0Path", token0Path,
			"token1Path", token1Path,
			"fee", ufmt.Sprintf("%d", fee),
			"sqrtPriceX96", _sqrtPriceX96,
			"internal_poolPath", poolPath,
		)
	}
}

// DoesPoolPathExist checks if a pool exists for the given poolPath.
// The poolPath is a unique identifier for a pool, combining token paths and fee.
func DoesPoolPathExist(poolPath string) bool {
	_, exist := pools[poolPath]
	return exist
}

// GetPool retrieves the pool for the given token paths and fee.
// It constructs the poolPath from the given parameters and returns the corresponding pool.
// Returns pool struct
func GetPool(token0Path, token1Path string, fee uint32) *Pool {
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("pool_manager.gno__GetPool() || expected poolPath(%s) to exist", poolPath),
		))
	}

	return pool
}

// GetPoolFromPoolPath retrieves the pool for the given poolPath.
func GetPoolFromPoolPath(poolPath string) *Pool {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("pool_manager.gno__GetPoolFromPoolPath() || expected poolPath(%s) to exist", poolPath),
		))
	}

	return pool
}

// GetPoolPath generates a poolPath from the given token paths and fee.
// The poolPath is constructed by joining the token paths and fee with colons.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	if token1Path < token0Path {
		token0Path, token1Path = token1Path, token0Path
	}

	var s strings.Builder
	s.WriteString(token0Path)
	s.WriteString(":")
	s.WriteString(token1Path)
	s.WriteString(":")
	s.WriteString(ufmt.Sprintf("%d", fee))

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
		feeProtocol:  slot0FeeProtocol,
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
