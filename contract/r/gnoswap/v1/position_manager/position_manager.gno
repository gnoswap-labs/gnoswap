package position_manager

import (
	"std"
	"strconv"
	"time"

	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/common"
	pl "gno.land/r/gnoswap/v1/pool"
)

var (
	positionAddr = rbac.DefaultRoleAddresses[prabc.ROLE_POSITION]
	poolAddr = rbac.DefaultRoleAddresses[prabc.ROLE_POOL]
	
	// Position data
	positions map[int64]*Position
	
	// Pool mapping
	poolPositionIds map[string]int64
	
	// Counter for new IDs
	nextTokenId int64 = 1
	nextPoolId int64 = 1
	
	// Fixed constants
	Q128 = u256.MustFromDecimal("340282366920938463463374607431768211456")
)

// Position represents a liquidity position NFT
type Position struct {
	id                       int64        // position ID
	operator                 std.Address  // approved address for spending
	poolPath                 string       // pool path
	tickLower                int32        // lower tick of position
	tickUpper                int32        // upper tick of position
	liquidity                *u256.Uint   // position liquidity
	feeGrowthInside0LastX128 *u256.Uint   // fee growth at last action
	feeGrowthInside1LastX128 *u256.Uint   // fee growth at last action
	tokensOwed0              *u256.Uint   // uncollected token0
	tokensOwed1              *u256.Uint   // uncollected token1
}

// PoolKey represents a unique pool identifier
type PoolKey struct {
	token0 string // token0 path
	token1 string // token1 path
	fee    uint32 // fee tier
}

// MintParams represents parameters for minting a new position
type MintParams struct {
	token0         string
	token1         string
	fee            uint32
	tickLower      int32
	tickUpper      int32
	amount0Desired string
	amount1Desired string
	amount0Min     string
	amount1Min     string
	deadline       int64
	recipient      std.Address
}

// IncreaseLiquidityParams represents parameters for increasing liquidity
type IncreaseLiquidityParams struct {
	tokenId        int64
	amount0Desired string
	amount1Desired string
	amount0Min     string
	amount1Min     string
	deadline       int64
}

// DecreaseLiquidityParams represents parameters for decreasing liquidity
type DecreaseLiquidityParams struct {
	tokenId    int64
	liquidity  string
	amount0Min string
	amount1Min string
	deadline   int64
}

// CollectParams represents parameters for collecting fees
type CollectParams struct {
	tokenId    int64
	recipient  std.Address
	amount0Max string
	amount1Max string
}

func init() {
	positions = make(map[int64]*Position)
	poolPositionIds = make(map[string]int64)
}

// Mint creates a new position NFT
func Mint(params MintParams) (int64, string, string, string) {
	halt.AssertIsNotHaltedPosition()

	assertDeadline(params.deadline)
	
	caller := std.PreviousRealm().Address()
	if !std.PreviousRealm().IsUser() {
		panic(errOnlyUserCanCall)
	}
	
	// Get or create pool
	poolPath := pl.GetPoolPath(params.token0, params.token1, params.fee)
	poolPositionIds[poolPath] = nextTokenId
	nextTokenId++
	
	// Mint position through position contract
	pl.Mint(
		cross,
		params.token0,
		params.token1,
		params.fee,
		params.recipient,
		params.tickLower,
		params.tickUpper,
		params.liquidityAmount,
		caller,
	)
	
	// Get fee growth from pool

	positionKey := computePositionKey(params.tickLower, params.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pl.GetPositionFeeGrowthInsideLastX128(poolPath, positionKey)
	
	// Create position record
	positions[tokenId] = &Position{
		id:                       int64(tokenId),
		operator:                 std.Address(""),
		poolPath:                 poolPath,
		tickLower:                params.tickLower,
		tickUpper:                params.tickUpper,
		liquidity:                u256.MustFromDecimal(liquidity),
		feeGrowthInside0LastX128: u256.MustFromDecimal(feeGrowthInside0),
		feeGrowthInside1LastX128: u256.MustFromDecimal(feeGrowthInside1),
		tokensOwed0:              u256.Zero(),
		tokensOwed1:              u256.Zero(),
	}
	
	// Mint NFT to recipient
	nft.Mint(params.recipient, tokenId)
	
	std.Emit(
		"IncreaseLiquidity",
		"tokenId", strconv.FormatUint(tokenId, 10),
		"liquidity", liquidity,
		"amount0", amount0,
		"amount1", amount1,
	)
	
	return tokenId, liquidity, amount0, amount1
}

// IncreaseLiquidity adds liquidity to an existing position
func IncreaseLiquidity(params IncreaseLiquidityParams) (string, string, string) {
	halt.AssertIsNotHaltedPosition()
	assertDeadline(params.deadline)
	
	position := positions[params.tokenId]
	if position == nil {
		panic(errPositionDoesNotExist)
	}
	
	// Check ownership
	owner := nft.OwnerOf(params.tokenId)
	caller := std.PreviousRealm().Address()
	if owner != caller && position.operator != caller {
		panic(errNotAuthorized)
	}
	
	// Increase liquidity through position contract
	_, liquidity, amount0, amount1 := pos.IncreaseLiquidity(
		params.tokenId,
		params.amount0Desired,
		params.amount1Desired,
		params.amount0Min,
		params.amount1Min,
		params.deadline,
		caller,
	)
	
	// Update fee accumulation
	poolPath := common.GetPoolPath(poolKey.token0, poolKey.token1, poolKey.fee)
	feeGrowthInside0, feeGrowthInside1 := pl.GetFeeGrowthInside(
		poolPath,
		position.tickLower,
		position.tickUpper,
	)
	
	feeGrowth0 := u256.MustFromDecimal(feeGrowthInside0)
	feeGrowth1 := u256.MustFromDecimal(feeGrowthInside1)
	
	// Calculate fees owed
	if position.liquidity.Gt(u256.Zero()) {
		tokensOwed0 := calculateTokensOwed(
			feeGrowth0,
			position.feeGrowthInside0LastX128,
			position.liquidity,
		)
		tokensOwed1 := calculateTokensOwed(
			feeGrowth1,
			position.feeGrowthInside1LastX128,
			position.liquidity,
		)
		
		position.tokensOwed0 = new(u256.Uint).Add(position.tokensOwed0, tokensOwed0)
		position.tokensOwed1 = new(u256.Uint).Add(position.tokensOwed1, tokensOwed1)
	}
	
	// Update position
	position.feeGrowthInside0LastX128 = feeGrowth0
	position.feeGrowthInside1LastX128 = feeGrowth1
	position.liquidity = new(u256.Uint).Add(
		position.liquidity,
		u256.MustFromDecimal(liquidity),
	)
	
	std.Emit(
		"IncreaseLiquidity",
		"tokenId", strconv.FormatUint(params.tokenId, 10),
		"liquidity", liquidity,
		"amount0", amount0,
		"amount1", amount1,
	)
	
	return liquidity, amount0, amount1
}

// DecreaseLiquidity removes liquidity from a position
func DecreaseLiquidity(params DecreaseLiquidityParams) (string, string) {
	halt.AssertIsNotHaltedPosition()
	assertDeadline(params.deadline)
	
	position := positions[params.tokenId]
	if position == nil {
		panic(errPositionDoesNotExist)
	}
	
	// Check ownership
	owner := nft.OwnerOf(params.tokenId)
	caller := std.PreviousRealm().Address()
	if owner != caller && position.operator != caller {
		panic(errNotAuthorized)
	}
	
	liquidityDelta := u256.MustFromDecimal(params.liquidity)
	if liquidityDelta.IsZero() {
		panic(errZeroLiquidity)
	}
	
	if position.liquidity.Lt(liquidityDelta) {
		panic(errInsufficientLiquidity)
	}
	
	// Decrease liquidity through position contract
	amount0, amount1 := pos.DecreaseLiquidity(
		params.tokenId,
		params.liquidity,
		params.amount0Min,
		params.amount1Min,
		params.deadline,
		false, // unwrapResult
		caller,
	)
	
	// Update fee accumulation
	poolKey := poolKeysByPoolId[position.poolId]
	poolPath := common.GetPoolPath(poolKey.token0, poolKey.token1, poolKey.fee)
	feeGrowthInside0, feeGrowthInside1 := pl.GetFeeGrowthInside(
		poolPath,
		position.tickLower,
		position.tickUpper,
	)
	
	feeGrowth0 := u256.MustFromDecimal(feeGrowthInside0)
	feeGrowth1 := u256.MustFromDecimal(feeGrowthInside1)
	
	// Calculate fees owed
	tokensOwed0 := calculateTokensOwed(
		feeGrowth0,
		position.feeGrowthInside0LastX128,
		position.liquidity,
	)
	tokensOwed1 := calculateTokensOwed(
		feeGrowth1,
		position.feeGrowthInside1LastX128,
		position.liquidity,
	)
	
	// Update position
	position.tokensOwed0 = new(u256.Uint).Add(
		new(u256.Uint).Add(position.tokensOwed0, u256.MustFromDecimal(amount0)),
		tokensOwed0,
	)
	position.tokensOwed1 = new(u256.Uint).Add(
		new(u256.Uint).Add(position.tokensOwed1, u256.MustFromDecimal(amount1)),
		tokensOwed1,
	)
	
	position.feeGrowthInside0LastX128 = feeGrowth0
	position.feeGrowthInside1LastX128 = feeGrowth1
	position.liquidity = new(u256.Uint).Sub(position.liquidity, liquidityDelta)
	
	std.Emit(
		"DecreaseLiquidity",
		"tokenId", strconv.FormatUint(params.tokenId, 10),
		"liquidity", params.liquidity,
		"amount0", amount0,
		"amount1", amount1,
	)
	
	return amount0, amount1
}

// Collect collects accumulated fees for a position
func Collect(params CollectParams) (string, string) {
	position := positions[params.tokenId]
	if position == nil {
		panic(errPositionDoesNotExist)
	}
	
	// Check ownership
	owner := nft.OwnerOf(params.tokenId)
	caller := std.PreviousRealm().Address()
	if owner != caller && position.operator != caller {
		panic(errNotAuthorized)
	}
	
	recipient := params.recipient
	if recipient == std.Address("") {
		recipient = caller
	}
	
	amount0Max := u256.MustFromDecimal(params.amount0Max)
	amount1Max := u256.MustFromDecimal(params.amount1Max)
	
	if amount0Max.IsZero() && amount1Max.IsZero() {
		panic(errMustCollectSomething)
	}
	
	// Update fees if position has liquidity
	if position.liquidity.Gt(u256.Zero()) {
		poolKey := poolKeysByPoolId[position.poolId]
		poolPath := common.GetPoolPath(poolKey.token0, poolKey.token1, poolKey.fee)
		
		// Trigger fee update by burning 0 liquidity
		pl.Burn(
			poolPath,
			position.tickLower,
			position.tickUpper,
			"0",
			caller,
		)
		
		feeGrowthInside0, feeGrowthInside1 := pl.GetFeeGrowthInside(
			poolPath,
			position.tickLower,
			position.tickUpper,
		)
		
		feeGrowth0 := u256.MustFromDecimal(feeGrowthInside0)
		feeGrowth1 := u256.MustFromDecimal(feeGrowthInside1)
		
		tokensOwed0 := calculateTokensOwed(
			feeGrowth0,
			position.feeGrowthInside0LastX128,
			position.liquidity,
		)
		tokensOwed1 := calculateTokensOwed(
			feeGrowth1,
			position.feeGrowthInside1LastX128,
			position.liquidity,
		)
		
		position.tokensOwed0 = new(u256.Uint).Add(position.tokensOwed0, tokensOwed0)
		position.tokensOwed1 = new(u256.Uint).Add(position.tokensOwed1, tokensOwed1)
		
		position.feeGrowthInside0LastX128 = feeGrowth0
		position.feeGrowthInside1LastX128 = feeGrowth1
	}
	
	// Calculate actual amounts to collect
	amount0Collect := position.tokensOwed0
	if amount0Max.Lt(amount0Collect) {
		amount0Collect = amount0Max
	}
	
	amount1Collect := position.tokensOwed1
	if amount1Max.Lt(amount1Collect) {
		amount1Collect = amount1Max
	}
	
	// Collect through position contract
	amount0, amount1 := pos.Collect(
		params.tokenId,
		recipient,
		amount0Collect.ToString(),
		amount1Collect.ToString(),
	)
	
	// Update tokens owed
	position.tokensOwed0 = new(u256.Uint).Sub(position.tokensOwed0, amount0Collect)
	position.tokensOwed1 = new(u256.Uint).Sub(position.tokensOwed1, amount1Collect)
	
	std.Emit(
		"Collect",
		"tokenId", strconv.FormatUint(params.tokenId, 10),
		"recipient", recipient.String(),
		"amount0", amount0,
		"amount1", amount1,
	)
	
	return amount0, amount1
}

// Burn destroys a position NFT
func Burn(tokenId int64) {
	position := positions[tokenId]
	if position == nil {
		panic(errPositionDoesNotExist)
	}
	
	// Check ownership
	owner := nft.OwnerOf(tokenId)
	caller := std.PreviousRealm().Address()
	if owner != caller {
		panic(errNotAuthorized)
	}
	
	// Check position is empty
	if !position.liquidity.IsZero() || !position.tokensOwed0.IsZero() || !position.tokensOwed1.IsZero() {
		panic(errPositionNotCleared)
	}
	
	// Remove position data
	delete(positions, tokenId)
	
	// Burn NFT
	nft.Burn(tokenId)
	
	std.Emit(
		"Burn",
		"tokenId", strconv.FormatUint(tokenId, 10),
	)
}

// Positions returns position details
func Positions(tokenId int64) (
	nonce uint96,
	operator std.Address,
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidity string,
	feeGrowthInside0LastX128 string,
	feeGrowthInside1LastX128 string,
	tokensOwed0 string,
	tokensOwed1 string,
) {
	position := positions[tokenId]
	if position == nil {
		panic(errInvalidTokenId)
	}
	
	poolKey := poolKeysByPoolId[position.poolId]
	
	return position.nonce,
		position.operator,
		poolKey.token0,
		poolKey.token1,
		poolKey.fee,
		position.tickLower,
		position.tickUpper,
		position.liquidity.ToString(),
		position.feeGrowthInside0LastX128.ToString(),
		position.feeGrowthInside1LastX128.ToString(),
		position.tokensOwed0.ToString(),
		position.tokensOwed1.ToString()
}

// Helper functions

func cachePoolKey(poolPath string, key PoolKey) uint80 {
	poolId, exists := poolIds[poolPath]
	if !exists {
		poolId = nextPoolId
		nextPoolId++
		poolIds[poolPath] = poolId
		poolKeysByPoolId[poolId] = key
	}
	return poolId
}

func calculateTokensOwed(
	feeGrowthInsideX128 *u256.Uint,
	feeGrowthInsideLastX128 *u256.Uint,
	liquidity *u256.Uint,
) *u256.Uint {
	feeGrowthDelta := new(u256.Uint).Sub(feeGrowthInsideX128, feeGrowthInsideLastX128)
	return new(u256.Uint).Div(
		new(u256.Uint).Mul(feeGrowthDelta, liquidity),
		Q128,
	)
}

func assertDeadline(deadline int64) {
	if deadline > 0 && deadline < int64(time.Now().Unix()) {
		panic(errTransactionExpired)
	}
}