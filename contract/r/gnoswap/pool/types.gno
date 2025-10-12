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
	SetPoolCreationFee(
		poolCreationFee int64,
	)

	// SetWithdrawalFee sets the withdrawal fee.
	SetWithdrawalFeeBPS(
		withdrawalFeeBPS uint64,
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
}

// IPoolSwap interface defines swap and protocol fee operations.
// These methods handle token swaps and protocol fee management.
type IPoolSwap interface {
	// Swap executes a token swap.
	Swap(
		token0Path string,
		token1Path string,
		fee uint32,
		recipient address,
		zeroForOne bool,
		amountSpecified string,
		sqrtPriceLimitX96 string,
		caller address,
	) (string, string)

	// DrySwap simulates a swap without executing it.
	DrySwap(
		token0Path string,
		token1Path string,
		fee uint32,
		zeroForOne bool,
		amountSpecified string,
		sqrtPriceLimitX96 string,
	) (string, string)

	// CollectProtocol collects accumulated protocol fees.
	CollectProtocol(
		token0Path string,
		token1Path string,
		fee uint32,
		recipient address,
		amount0Requested string,
		amount1Requested string,
	) (string, string)

	// SetFeeProtocol sets the protocol fee percentage.
	SetFeeProtocol(
		feeProtocol0 uint8,
		feeProtocol1 uint8,
	)
}

// IPoolGetter interface defines data retrieval operations.
// These methods provide read-only access to pool state and data.
type IPoolGetter interface {
	// GetPoolPath returns the pool path for given tokens and fee.
	GetPoolPath(token0Path, token1Path string, fee uint32) string

	// GetSlot0SqrtPriceX96 returns the current sqrt price.
	GetSlot0SqrtPriceX96(poolPath string) *u256.Uint

	// GetSlot0Tick returns the current tick.
	GetSlot0Tick(poolPath string) int32

	// GetLiquidity returns current liquidity.
	GetLiquidity(poolPath string) string

	// GetBalanceToken0 returns token0 balance.
	GetBalanceToken0(poolPath string) string

	// GetBalanceToken1 returns token1 balance.
	GetBalanceToken1(poolPath string) string

	// GetFeeGrowthGlobalX128 returns global fee growth values.
	GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint)

	// GetPositionFeeGrowthInsideLastX128 returns position fee growth.
	GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint)

	// GetObservation returns oracle observation data.
	GetObservation(poolPath string, secondsAgo int64) (int64, string, string, int64)

	// ExistsPoolPath checks if pool exists.
	ExistsPoolPath(poolPath string) bool

	// ApiGetPool returns pool data as JSON.
	ApiGetPool(poolPath string) string

	// ApiGetTWAP returns time-weighted average price.
	ApiGetTWAP(poolPath string, secondsAgo uint32) string
}

// IPoolStore interface defines the storage abstraction for pool data.
// This interface provides a clean separation between business logic and storage,
// allowing different implementations to use the same storage interface.
//
// All pool implementations (v1, v2, etc.) use this interface to access
// and modify pool state, ensuring data consistency across versions.
type IPoolStore interface {
	GetPools() *avl.Tree
	SetPools(pools *avl.Tree) error

	GetFeeAmountTickSpacing() *avl.Tree
	SetFeeAmountTickSpacing(feeAmountTickSpacing *avl.Tree) error

	GetSlot0FeeProtocol() uint8
	SetSlot0FeeProtocol(slot0FeeProtocol uint8) error

	GetPoolCreationFee() int64
	SetPoolCreationFee(poolCreationFee int64) error

	GetWithdrawalFeeBPS() uint64
	SetWithdrawalFeeBPS(withdrawalFeeBPS uint64) error
}
