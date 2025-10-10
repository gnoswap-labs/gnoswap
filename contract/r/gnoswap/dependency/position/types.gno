package position

// Position interface defines all public methods that must be implemented by position contract versions.
// This allows for upgradeable position implementations while maintaining backwards compatibility.
type Position interface {
	// Mint creates a new liquidity position NFT.
	Mint(
		cur realm,
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
		caller address,
		referrer string,
	) (uint64, string, string, string)

	// IncreaseLiquidity increases liquidity of an existing position.
	IncreaseLiquidity(
		cur realm,
		positionId uint64,
		amount0DesiredStr string,
		amount1DesiredStr string,
		amount0MinStr string,
		amount1MinStr string,
		deadline int64,
	) (uint64, string, string, string, string)

	// DecreaseLiquidity decreases liquidity of an existing position.
	DecreaseLiquidity(
		cur realm,
		positionId uint64,
		liquidityStr string,
		amount0MinStr string,
		amount1MinStr string,
		deadline int64,
		unwrapResult bool,
	) (uint64, string, string, string, string, string, string)

	// CollectFee collects swap fee from the position.
	CollectFee(
		cur realm,
		positionId uint64,
		unwrapResult bool,
	) (uint64, string, string, string, string, string)

	// SetPositionOperator sets an operator for a position.
	SetPositionOperator(
		cur realm,
		id uint64,
		operator address,
	)

	// Reposition creates a new position with liquidity from an existing position.
	Reposition(
		cur realm,
		tokenId uint64,
		targetTokenId uint64,
		removeRatio uint64,
		amount0Min string,
		amount1Min string,
		swapDirection string,
		swapAmount string,
		swapAmountMin string,
		deadline int64,
		unwrapResult bool,
	) (uint64, string, string, string, string)

	// GetNextPositionId returns the next position ID to be minted.
	GetNextPositionId() uint64

	// PositionGetPositionLiquidityStr returns liquidity as string for a position.
	PositionGetPositionLiquidityStr(positionId uint64) string

	// MustGetPosition returns position or panics if not found.
	MustGetPosition(positionId uint64) Position

	// ApiGetPosition returns position data as JSON.
	ApiGetPosition(positionId uint64) string

	// ApiGetPositions returns all positions as JSON.
	ApiGetPositions() string

	// Getter functions
	GetNextPositionId() uint64
	PositionGetPositionOperator(positionId uint64) address
	PositionGetPositionPoolKey(positionId uint64) string
	PositionGetPositionTickLower(positionId uint64) int32
	PositionGetPositionTickUpper(positionId uint64) int32
	PositionGetPositionLiquidityStr(positionId uint64) string
	PositionGetPositionOwner(positionId uint64) address
	PositionIsInRange(positionId uint64) bool
}

// UpdateRequest contains parameters for updating the position implementation.
type UpdateRequest struct {
	Position     Position // New position implementation
	AllowedImpls []string // Realms allowed to update implementation
}
