package pool

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
)

// IPool interface defines all public methods that must be implemented by pool contract versions.
// This interface serves as the contract between the proxy layer and implementation versions,
// ensuring that all versions (v1, v2, v3, etc.) maintain the same public API.
//
// This design enables seamless upgrades while maintaining backwards compatibility.
// When upgrading from v1 to v2, the proxy simply switches the implementation pointer
// without changing the public interface, ensuring zero downtime and no breaking changes.
type IPool interface {
	IPoolManager
	IPoolPosition
	IPoolSwap
	IPoolGetter
}

// IPoolManager interface defines pool management operations.
// These methods handle pool creation and fee configuration.
type IPoolManager interface {
	// CreatePool creates a new concentrated liquidity pool.
	CreatePool(
		token0Path string,
		token1Path string,
		fee uint32,
		sqrtPriceX96 string,
	)

	// SetPoolCreationFee sets the pool creation fee.
	SetPoolCreationFee(fee int64)

	IncreaseObservationCardinalityNext(
		token0Path string,
		token1Path string,
		fee uint32,
		cardinalityNext uint16,
	)
}

// IPoolPosition interface defines position management operations.
// These methods handle liquidity provision and position management.
type IPoolPosition interface {
	// Mint adds liquidity to a pool position.
	Mint(
		token0Path string,
		token1Path string,
		fee uint32,
		tickLower int32,
		tickUpper int32,
		liquidityAmount string,
		positionCaller address,
	) (string, string)

	// Burn removes liquidity from a position.
	Burn(
		token0Path string,
		token1Path string,
		fee uint32,
		tickLower int32,
		tickUpper int32,
		liquidityAmount string,
		positionCaller address,
	) (string, string)

	// Collect transfers owed tokens from a position to recipient.
	Collect(
		token0Path string,
		token1Path string,
		fee uint32,
		recipient address,
		tickLower int32,
		tickUpper int32,
		amount0Requested string,
		amount1Requested string,
	) (string, string)

	SetWithdrawalFee(fee uint64)

	HandleWithdrawalFee(
		positionId uint64,
		token0Path string,
		amount0 string,
		token1Path string,
		amount1 string,
		poolPath string,
		positionCaller address,
	) (string, string)
}

// IPoolSwap interface defines swap and protocol fee operations.
// These methods handle token swaps and protocol fee management.
type IPoolSwap interface {
	Swap(
		token0Path string,
		token1Path string,
		fee uint32,
		recipient address,
		zeroForOne bool,
		amountSpecified string,
		sqrtPriceLimitX96 string,
		payer address,
		swapCallback func(cur realm, amount0Delta, amount1Delta int64, callbackMarker *CallbackMarker) error,
	) (string, string)

	SetSwapEndHook(hook func(cur realm, poolPath string) error)

	SetSwapStartHook(hook func(cur realm, poolPath string, timestamp int64))

	SetTickCrossHook(hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64))

	CollectProtocol(
		token0Path string,
		token1Path string,
		fee uint32,
		recipient address,
		amount0Requested string,
		amount1Requested string,
	) (string, string)

	SetFeeProtocol(feeProtocol0, feeProtocol1 uint8)
}

// IPoolGetter interface defines data retrieval operations.
// These methods provide read-only access to pool state and data.
type IPoolGetter interface {
	DrySwap(
		token0Path string,
		token1Path string,
		fee uint32,
		zeroForOne bool,
		amountSpecified string,
		sqrtPriceLimitX96 string,
	) (string, string, bool)

	ExistsPoolPath(poolPath string) bool

	GetBalanceToken0(poolPath string) string

	GetBalanceToken1(poolPath string) string

	GetFee(poolPath string) uint32

	GetFeeAmountTickSpacing(fee uint32) (spacing int32)

	GetFeeGrowthGlobal0X128(poolPath string) string

	GetFeeGrowthGlobal1X128(poolPath string) string

	GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint)

	GetLiquidity(poolPath string) string

	GetMaxLiquidityPerTick(poolPath string) string

	GetObservation(poolPath string, secondsAgo int64) (tickCumulative int64, liquidityCumulative, secondsPerLiquidityCumulativeX128 string, blockTimestamp int64)

	GetPoolCreationFee() int64

	GetPositionFeeGrowthInside0LastX128(poolPath, key string) string

	GetPositionFeeGrowthInside1LastX128(poolPath, key string) string

	GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint)

	GetPositionLiquidity(poolPath, key string) *u256.Uint

	GetPositionTokensOwed0(poolPath, key string) string

	GetPositionTokensOwed1(poolPath, key string) string

	GetProtocolFeesToken0(poolPath string) string

	GetProtocolFeesToken1(poolPath string) string

	GetSlot0FeeProtocol(poolPath string) uint8

	GetSlot0SqrtPriceX96(poolPath string) *u256.Uint

	GetSlot0Tick(poolPath string) int32

	GetSlot0Unlocked(poolPath string) bool

	GetTickCumulativeOutside(poolPath string, tick int32) int64

	GetTickFeeGrowthOutside0X128(poolPath string, tick int32) string

	GetTickFeeGrowthOutside1X128(poolPath string, tick int32) string

	GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (*u256.Uint, *u256.Uint)

	GetTickInitialized(poolPath string, tick int32) bool

	GetTickLiquidityGross(poolPath string, tick int32) string

	GetTickLiquidityNet(poolPath string, tick int32) string

	GetTickSecondsOutside(poolPath string, tick int32) uint32

	GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string

	GetTickSpacing(poolPath string) int32

	GetToken0Path(poolPath string) string

	GetToken1Path(poolPath string) string

	GetWithdrawalFee() uint64

	GetTWAP(poolPath string, secondsAgo uint32) (int32, *u256.Uint, error)

	GetPoolCount() int
	GetPoolPaths(offset, count int) []string
	GetFeeAmountTickSpacings() map[uint32]int32

	GetPoolPositionCount(poolPath string) int
	GetPoolPositionKeys(poolPath string, offset, count int) []string

	GetInitializedTicksInRange(poolPath string, tickLower, tickUpper int32) []int32

	// Structure getters
	GetPool(token0Path, token1Path string, fee uint32) (*Pool, error)
	GetTickInfo(poolPath string, tick int32) (TickInfo, error)
	GetTickBitmaps(poolPath string, wordPos int16) (*u256.Uint, error)
	GetPosition(poolPath, key string) (PositionInfo, error)
	GetObservationState(poolPath string) (*ObservationState, error)
}

// IPoolStore interface defines the storage abstraction for pool data.
// This interface provides a clean separation between business logic and storage,
// allowing different implementations to use the same storage interface.
//
// All pool implementations (v1, v2, etc.) use this interface to access
// and modify pool state, ensuring data consistency across versions.
type IPoolStore interface {
	HasPools() bool
	GetPools() *avl.Tree
	SetPools(pools *avl.Tree) error

	HasFeeAmountTickSpacing() bool
	GetFeeAmountTickSpacing() map[uint32]int32
	SetFeeAmountTickSpacing(feeAmountTickSpacing map[uint32]int32) error

	HasSlot0FeeProtocol() bool
	GetSlot0FeeProtocol() uint8
	SetSlot0FeeProtocol(slot0FeeProtocol uint8) error

	HasPoolCreationFee() bool
	GetPoolCreationFee() int64
	SetPoolCreationFee(poolCreationFee int64) error

	HasWithdrawalFeeBPS() bool
	GetWithdrawalFeeBPS() uint64
	SetWithdrawalFeeBPS(withdrawalFeeBPS uint64) error

	HasSwapStartHook() bool
	GetSwapStartHook() func(cur realm, poolPath string, timestamp int64)
	SetSwapStartHook(swapStartHook func(cur realm, poolPath string, timestamp int64)) error

	HasSwapEndHook() bool
	GetSwapEndHook() func(cur realm, poolPath string) error
	SetSwapEndHook(swapEndHook func(cur realm, poolPath string) error) error

	HasTickCrossHook() bool
	GetTickCrossHook() func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)
	SetTickCrossHook(tickCrossHook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) error
}

type CallbackMarker struct{}
