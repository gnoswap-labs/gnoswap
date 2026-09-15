package position

import (
	u256 "gno.land/p/gnoswap/uint256/v1"
	bptree "gno.land/p/nt/bptree/v0"
	rotree "gno.land/p/nt/bptree/rotree/v0"
)

type IPosition interface {
	IPositionManager
	IPositionGetter
}

type IPositionManager interface {
	// Mint creates a new liquidity position NFT.
	//
	// Parameters:
	//   - _: leading integer discriminator; callers pass 0
	//   - rlm: propagated realm context; implementations validate it as current before changing state
	//   - token0: path of the first token in the pool
	//   - token1: path of the second token in the pool
	//   - fee: pool fee tier used to identify the pool
	//   - tickLower: lower tick boundary of the position's price range
	//   - tickUpper: upper tick boundary of the position's price range
	//   - amount0Desired: desired amount of token0 to provide
	//   - amount1Desired: desired amount of token1 to provide
	//   - amount0Min: minimum acceptable token0 amount for slippage protection
	//   - amount1Min: minimum acceptable token1 amount for slippage protection
	//   - deadline: transaction expiration timestamp
	//   - mintTo: recipient address of the position NFT
	//   - referrer: referrer identifier used for reward tracking
	//
	// Returns:
	//   - positionId: newly minted position NFT token ID
	//   - liquidity: liquidity minted into the position, represented as a decimal string
	//   - amount0: actual amount of token0 added, represented as a decimal string
	//   - amount1: actual amount of token1 added, represented as a decimal string
	Mint(
		_ int,
		rlm realm,
		token0 string,
		token1 string,
		fee uint32,
		tickLower int32,
		tickUpper int32,
		amount0Desired string,
		amount1Desired string,
		amount0Min string,
		amount1Min string,
		deadline int64,
		mintTo address,
		referrer string,
	) (uint64, string, string, string)

	// IncreaseLiquidity adds liquidity to an existing position.
	//
	// Parameters:
	//   - _: leading integer discriminator; callers pass 0
	//   - rlm: propagated realm context; implementations validate it as current before changing state
	//   - positionId: position NFT token ID to increase
	//   - amount0DesiredStr: desired token0 amount, represented as a decimal string
	//   - amount1DesiredStr: desired token1 amount, represented as a decimal string
	//   - amount0MinStr: minimum acceptable token0 amount for slippage protection
	//   - amount1MinStr: minimum acceptable token1 amount for slippage protection
	//   - deadline: transaction expiration timestamp
	//
	// Returns:
	//   - positionId: position NFT token ID that received the liquidity
	//   - liquidity: liquidity amount added to the position (the delta), represented as a decimal string
	//   - amount0: actual token0 amount added, represented as a decimal string
	//   - amount1: actual token1 amount added, represented as a decimal string
	//   - poolKey: canonical pool key for the position
	IncreaseLiquidity(
		_ int,
		rlm realm,
		positionId uint64,
		amount0DesiredStr string,
		amount1DesiredStr string,
		amount0MinStr string,
		amount1MinStr string,
		deadline int64,
	) (uint64, string, string, string, string)

	// DecreaseLiquidity removes liquidity from a position.
	//
	// Parameters:
	//   - _: leading integer discriminator; callers pass 0
	//   - rlm: propagated realm context; implementations validate it as current before changing state
	//   - positionId: position NFT token ID to decrease
	//   - liquidityStr: liquidity amount to remove, represented as a decimal string
	//   - amount0MinStr: minimum acceptable token0 amount for slippage protection
	//   - amount1MinStr: minimum acceptable token1 amount for slippage protection
	//   - deadline: transaction expiration timestamp
	//
	// Returns:
	//   - positionId: position NFT token ID that had liquidity removed
	//   - liquidity: removed liquidity amount, represented as a decimal string
	//   - fee0: token0 fees collected, net of the withdrawal fee
	//   - fee1: token1 fees collected, net of the withdrawal fee
	//   - amount0: principal amount of token0 returned to the caller
	//   - amount1: principal amount of token1 returned to the caller
	//   - poolKey: canonical pool key for the position
	DecreaseLiquidity(
		_ int,
		rlm realm,
		positionId uint64,
		liquidityStr string,
		amount0MinStr string,
		amount1MinStr string,
		deadline int64,
	) (uint64, string, string, string, string, string, string)

	// Reposition changes the tick range of an existing position.
	//
	// Parameters:
	//   - _: leading integer discriminator; callers pass 0
	//   - rlm: propagated realm context; implementations validate it as current before changing state
	//   - positionId: position NFT token ID to reposition
	//   - tickLower: new lower tick boundary of the position's price range
	//   - tickUpper: new upper tick boundary of the position's price range
	//   - amount0DesiredStr: desired token0 amount for the new range, represented as a decimal string
	//   - amount1DesiredStr: desired token1 amount for the new range, represented as a decimal string
	//   - amount0MinStr: minimum acceptable token0 amount for slippage protection
	//   - amount1MinStr: minimum acceptable token1 amount for slippage protection
	//   - deadline: transaction expiration timestamp
	//
	// Returns:
	//   - positionId: position NFT token ID that was repositioned
	//   - liquidity: new liquidity amount, represented as a decimal string
	//   - tickLower: lower tick boundary applied to the position
	//   - tickUpper: upper tick boundary applied to the position
	//   - amount0: actual token0 amount added to the new range, represented as a decimal string
	//   - amount1: actual token1 amount added to the new range, represented as a decimal string
	Reposition(
		_ int,
		rlm realm,
		positionId uint64,
		tickLower int32,
		tickUpper int32,
		amount0DesiredStr string,
		amount1DesiredStr string,
		amount0MinStr string,
		amount1MinStr string,
		deadline int64,
	) (uint64, string, int32, int32, string, string)

	// CollectFee collects accumulated fees from a position.
	//
	// Parameters:
	//   - _: leading integer discriminator; callers pass 0
	//   - rlm: propagated realm context; implementations validate it as current before changing state
	//   - positionId: position NFT token ID whose fees are collected
	//
	// Returns:
	//   - positionId: position NFT token ID whose fees were collected
	//   - tokensCollected0: token0 fees paid out to the caller, net of the withdrawal fee
	//   - tokensCollected1: token1 fees paid out to the caller, net of the withdrawal fee
	//   - poolKey: canonical pool key for the position
	//   - totalAmount0: token0 fees collected before the withdrawal fee
	//   - totalAmount1: token1 fees collected before the withdrawal fee
	CollectFee(
		_ int,
		rlm realm,
		positionId uint64,
	) (uint64, string, string, string, string, string)

	// SetPositionOperator sets or removes the approved operator for a position.
	//
	// Parameters:
	//   - _: leading integer discriminator; callers pass 0
	//   - rlm: propagated realm context; implementations validate it as current before changing state
	//   - positionId: position NFT token ID whose operator is changed
	//   - operator: operator address to approve; the zero address removes the operator
	SetPositionOperator(
		_ int,
		rlm realm,
		positionId uint64,
		operator address,
	)
}

type IPositionGetter interface {
	// GetPositions returns a read-only view of all positions.
	//
	// Returns:
	//   - positions: read-only tree keyed by decimal position ID
	GetPositions() *rotree.ReadOnlyTree
	// IsBurned reports whether a position's empty-position marker is set.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose burned marker is queried
	//
	// Returns:
	//   - burned: true when the position's empty-position marker is set
	//   - err: non-nil when positionId cannot be resolved
	IsBurned(positionId uint64) (bool, error)
	// IsInRange reports whether a position's tick range contains the current pool tick.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose range is checked
	//
	// Returns:
	//   - inRange: true when the current pool tick lies within the position's tick range
	//   - err: non-nil when positionId cannot be resolved or the associated pool tick cannot be read
	IsInRange(positionId uint64) (bool, error)
	// GetPositionOperator returns the approved operator address for a position.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose operator is queried
	//
	// Returns:
	//   - operator: approved operator address; the zero address means no operator is set
	//   - err: non-nil when positionId cannot be resolved
	GetPositionOperator(positionId uint64) (address, error)
	// GetPositionPoolKey returns the pool key associated with a position.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose pool is queried
	//
	// Returns:
	//   - poolKey: canonical pool key used by the position
	//   - err: non-nil when positionId cannot be resolved
	GetPositionPoolKey(positionId uint64) (string, error)
	// GetPositionTickLower returns the lower tick boundary of a position.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose lower tick is queried
	//
	// Returns:
	//   - tickLower: lower tick boundary of the position's price range
	//   - err: non-nil when positionId cannot be resolved
	GetPositionTickLower(positionId uint64) (int32, error)
	// GetPositionTickUpper returns the upper tick boundary of a position.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose upper tick is queried
	//
	// Returns:
	//   - tickUpper: upper tick boundary of the position's price range
	//   - err: non-nil when positionId cannot be resolved
	GetPositionTickUpper(positionId uint64) (int32, error)
	// GetPositionLiquidity returns the stored liquidity amount of a position.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose liquidity is queried
	//
	// Returns:
	//   - liquidity: position liquidity represented as a decimal string
	//   - err: non-nil when positionId cannot be resolved
	GetPositionLiquidity(positionId uint64) (string, error)
	// GetPositionTokenBalances returns current token0 and token1 balances derived for a position.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose balances are queried
	//
	// Returns:
	//   - balance0: current token0 balance derived from liquidity, ticks, and pool price
	//   - balance1: current token1 balance derived from liquidity, ticks, and pool price
	//   - err: non-nil when positionId cannot be resolved
	GetPositionTokenBalances(positionId uint64) (int64, int64, error)
	// GetPositionFeeGrowthInside0LastX128 returns the last fee-growth checkpoint inside a position's range for token0.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose token0 fee-growth checkpoint is queried
	//
	// Returns:
	//   - feeGrowthInside0LastX128: token0 fee-growth checkpoint as a decimal string
	//   - err: non-nil when positionId cannot be resolved
	GetPositionFeeGrowthInside0LastX128(positionId uint64) (string, error)
	// GetPositionFeeGrowthInside1LastX128 returns the last fee-growth checkpoint inside a position's range for token1.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose token1 fee-growth checkpoint is queried
	//
	// Returns:
	//   - feeGrowthInside1LastX128: token1 fee-growth checkpoint as a decimal string
	//   - err: non-nil when positionId cannot be resolved
	GetPositionFeeGrowthInside1LastX128(positionId uint64) (string, error)
	// GetPositionFeeGrowthInsideLastX128 returns the last fee-growth checkpoints inside a position's range for both tokens.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose fee-growth checkpoints are queried
	//
	// Returns:
	//   - feeGrowthInside0LastX128: token0 fee-growth checkpoint as a decimal string
	//   - feeGrowthInside1LastX128: token1 fee-growth checkpoint as a decimal string
	//   - err: non-nil when positionId cannot be resolved
	GetPositionFeeGrowthInsideLastX128(positionId uint64) (string, string, error)
	// GetPositionTicks returns the lower and upper tick boundaries of a position.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose tick range is queried
	//
	// Returns:
	//   - tickLower: lower tick boundary of the position's price range
	//   - tickUpper: upper tick boundary of the position's price range
	//   - err: non-nil when positionId cannot be resolved
	GetPositionTicks(positionId uint64) (int32, int32, error)
	// GetPositionTokensOwed0 returns the token0 amount accrued and owed to a position.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose token0 debt is queried
	//
	// Returns:
	//   - tokensOwed0: token0 amount currently owed to the position
	//   - err: non-nil when positionId cannot be resolved
	GetPositionTokensOwed0(positionId uint64) (int64, error)
	// GetPositionTokensOwed1 returns the token1 amount accrued and owed to a position.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose token1 debt is queried
	//
	// Returns:
	//   - tokensOwed1: token1 amount currently owed to the position
	//   - err: non-nil when positionId cannot be resolved
	GetPositionTokensOwed1(positionId uint64) (int64, error)
	// GetPositionTokensOwed returns token0 and token1 amounts accrued and owed to a position.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose accrued token debt is queried
	//
	// Returns:
	//   - tokensOwed0: token0 amount currently owed to the position
	//   - tokensOwed1: token1 amount currently owed to the position
	//   - err: non-nil when positionId cannot be resolved
	GetPositionTokensOwed(positionId uint64) (int64, int64, error)
	// GetUnclaimedFee returns unclaimed fees for both tokens of a position.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose unclaimed fees are queried
	//
	// Returns:
	//   - fee0: unclaimed token0 fee amount as a uint256 value
	//   - fee1: unclaimed token1 fee amount as a uint256 value
	//   - err: non-nil when positionId or the associated pool fee-growth data cannot be resolved
	GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint, error)
	// GetPositionOwner returns the owner address of a position NFT.
	//
	// Parameters:
	//   - positionId: position NFT token ID whose owner is queried
	//
	// Returns:
	//   - owner: address that owns the position NFT
	//   - err: non-nil when the NFT owner lookup fails
	GetPositionOwner(positionId uint64) (address, error)
}

type IPositionStore interface {
	// HasPositionsStoreKey reports whether the positions tree exists in storage.
	//
	// Returns:
	//   - exists: true when the positions storage key is present
	HasPositionsStoreKey() bool
	// GetPositions returns the mutable positions tree.
	//
	// Returns:
	//   - positions: positions tree keyed by decimal position ID
	GetPositions() *bptree.BPTree
	// SetPositions stores the complete positions tree.
	//
	// Parameters:
	//   - _: leading integer discriminator; callers pass 0
	//   - rlm: propagated realm context; implementations require it to be current for storage writes
	//   - positions: positions tree to persist, keyed by decimal position ID
	//
	// Returns:
	//   - err: nil when the tree is stored; non-nil when the realm is spoofed or the write fails
	SetPositions(_ int, rlm realm, positions *bptree.BPTree) error

	// HasPositionNextIDStoreKey reports whether the next-position-ID value exists.
	//
	// Returns:
	//   - exists: true when the next-position-ID storage key is present
	HasPositionNextIDStoreKey() bool
	// GetPositionNextID returns the next position NFT ID to allocate.
	//
	// Returns:
	//   - nextID: next position ID stored for minting
	GetPositionNextID() uint64
	// SetPositionNextID stores the next position NFT ID.
	//
	// Parameters:
	//   - _: leading integer discriminator; callers pass 0
	//   - rlm: propagated realm context; implementations require it to be current for storage writes
	//   - nextID: next position ID to persist for the next mint
	//
	// Returns:
	//   - err: nil when nextID is stored; non-nil when the realm is spoofed or the write fails
	SetPositionNextID(_ int, rlm realm, nextID uint64) error

	// HasPosition reports whether an NFT ID is present in the positions tree.
	//
	// Parameters:
	//   - positionId: position NFT token ID to look up
	//
	// Returns:
	//   - exists: true when positionId has a stored position
	HasPosition(positionId uint64) bool
	// GetPosition loads a position by NFT ID.
	//
	// Parameters:
	//   - positionId: position NFT token ID to look up
	//
	// Returns:
	//   - position: stored position value, or the zero Position when absent
	//   - exists: true when positionId is present; false when no position is stored
	GetPosition(positionId uint64) (Position, bool)
	// SetPosition inserts or replaces a position in storage.
	//
	// Parameters:
	//   - _: leading integer discriminator; callers pass 0
	//   - rlm: propagated realm context; implementations require it to be current for storage writes
	//   - positionId: position NFT token ID used as the storage key
	//   - position: complete position value to persist
	//
	// Returns:
	//   - err: nil when the position tree is updated; non-nil when the realm is spoofed, storage is missing, or the write fails
	SetPosition(_ int, rlm realm, positionId uint64, position Position) error
	// RemovePosition deletes a position from storage.
	//
	// Parameters:
	//   - _: leading integer discriminator; callers pass 0
	//   - rlm: propagated realm context; implementations require it to be current for storage writes
	//   - positionId: position NFT token ID to remove
	//
	// Returns:
	//   - err: nil when the position tree is updated; non-nil when the realm is spoofed, storage is missing, or the write fails
	RemovePosition(_ int, rlm realm, positionId uint64) error
}
