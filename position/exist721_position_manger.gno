package position

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/grc/grc721"

	nft "gno.land/r/foo721"

	pool "gno.land/r/pool"
)

var (
	PoolAddr = pool.GetPoolAddress()

	poolIds         map[std.Address]bigint = make(map[std.Address]bigint)
	poolIdToPoolKey map[bigint]PoolKey = make(map[bigint]PoolKey)
	positions       map[string]Position = make(map[string]Position)
	nextId          bigint = 1
	nextPoolId      bigint = 1
)

type Position struct {
	nonce bigint

	operator std.Address
	
	poolId bigint
	
	tickLower bigint
	tickUpper bigint
	
	liquidity bigint
	
	feeGrowthInside0LastX128 bigint
	feeGrowthInside1LastX128 bigint
	
	tokensOwed0 bigint
	tokensOwed1 bigint
}

func (p Position) isClear() bool {
	return p.liquidity == 0 && p.tokensOwed0 == 0 && p.tokensOwed1 == 0
}



func Positions(tokenId string) (
	bigint, std.Address, std.Address, std.Address, bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint,
) {
	position := positions[tokenId]
	require(position.poolId != 0, "Invalid token ID")
	poolKey := poolIdToPoolKey[position.poolId]

	return position.nonce, position.operator,	poolKey.token0,	poolKey.token1,	poolKey.fee,	position.tickLower,	position.tickUpper,	position.liquidity,	position.feeGrowthInside0LastX128,	position.feeGrowthInside1LastX128,	position.tokensOwed0,	position.tokensOwed1
}

func CachePoolKey(pool std.Address, poolKey PoolKey) bigint {
	poolId, ok := poolIds[pool]
	if !ok {
		poolId = nextPoolId
		nextPoolId++ // nextPoolId = nextPoolId + 1
		poolIds[pool] = poolId
		poolIdToPoolKey[poolId] = poolKey
	}

	return poolId
}

func Mint(params MintParams) (string, bigint, bigint, bigint) {
	// tokenId, liquidity, amount0, amount1

	checkDeadline(params.deadline);
	liquidity, amount0, amount1 := addLiquidity(
		AddLiquidityParams{
			token0: params.token0,
			token1: params.token1,
			fee: params.fee,
			recipient: GetOrigPkgAddr(),
			tickLower: params.tickLower,
			tickUpper: params.tickUpper,
			amount0Desired: params.amount0Desired,
			amount1Desired: params.amount1Desired,
			amount0Min: params.amount0Min,
			amount1Min: params.amount1Min,
		},
	)

	tokenId := string(nextId)
	nextId++ // nextId = nextId + 1
	
	// XXX GetRealmCaller PR is going on
	// spoof orig caller
	_orig := GetOrigCaller()
	std.TestSetOrigCaller(GetOrigPkgAddr())
	nft.Mint(a2u(_orig), grc721.TokenID(tokenId))
	std.TestSetOrigCaller(_orig)

	positionKey := PositionKeyCompute(GetOrigPkgAddr(), params.tickLower, params.tickUpper)
	// _p := pool.positions[positionKey]
	// _p := pool.GetPoolPosition(positionKey)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.GetPoolPositionFeeGrowthInside0LastX128(positionKey),pool.GetPoolPositionFeeGrowthInside1LastX128(positionKey)

	poolId := CachePoolKey(
		PoolAddr,
		PoolKey{token0: params.token0, token1: params.token1, fee: params.fee},
	)

	positions[tokenId] = Position{
		nonce: 0,
		operator: zeroAddress,
		poolId: poolId,
		tickLower: params.tickLower,
		tickUpper: params.tickUpper,
		liquidity: liquidity,
		feeGrowthInside0LastX128: feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: feeGrowthInside1LastX128,
		tokensOwed0: 0,
		tokensOwed1: 0,
	}

	return tokenId, liquidity, amount0, amount1
}


// liquidity, amount0, amount1
func IncreaseLiquidity(params IncreaseLiquidityParams) (bigint, bigint, bigint) {
	checkDeadline(params.deadline)

	// verify tokenId
	require(Exists(string(params.tokenId)), "Invalid token ID")

	position := positions[string(params.tokenId)]
	poolKey := poolIdToPoolKey[position.poolId]

	liquidity, amount0, amount1 := addLiquidity(
		AddLiquidityParams{
			token0: poolKey.token0,
			token1: poolKey.token1,
			fee: poolKey.fee,
			tickLower: position.tickLower,
			tickUpper: position.tickUpper,
			amount0Desired: params.amount0Desired,
			amount1Desired: params.amount1Desired,
			amount0Min: params.amount0Min,
			amount1Min: params.amount1Min,
			recipient: GetOrigPkgAddr(),
		},
	)

	positionKey := PositionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	// _p := pool.positions[positionKey]
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.GetPoolPositionFeeGrowthInside0LastX128(positionKey), pool.GetPoolPositionFeeGrowthInside1LastX128(positionKey)

	position.tokensOwed0 += (feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128) * position.liquidity / Q128
	position.tokensOwed1 += (feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128) * position.liquidity / Q128

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
	position.liquidity += liquidity
	
	return liquidity, amount0, amount1
}


func DecreaseLiquidity(params DecreaseLiquidityParams) (bigint, bigint) {
	isAuthorizedForToken(string(params.tokenId))
	checkDeadline(params.deadline)
	require(params.liquidity > 0, "Cannot remove 0 liquidity")

	// verify tokenId
	require(Exists(string(params.tokenId)), "Invalid token ID")

	position := positions[string(params.tokenId)]
	positionLiquidity := position.liquidity
	require(positionLiquidity >= params.liquidity, "Cannot withdraw more liquidity than is in the position")

	poolKey := poolIdToPoolKey[position.poolId]
	// pool := PoolAddressComputeAddress(factory, poolKey)

	// XXX GetRealmCaller PR is going on
	// spoof orig caller
	_orig := GetOrigCaller()
	std.TestSetOrigCaller(GetOrigPkgAddr())
	amount0, amount1 := pool.Burn(position.tickLower, position.tickUpper, params.liquidity)
	std.TestSetOrigCaller(_orig)

	require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, "PM_Price slippage check")
	
	positionKey := PositionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	// _p := pool.positions[positionKey]
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.GetPoolPositionFeeGrowthInside0LastX128(positionKey), pool.GetPoolPositionFeeGrowthInside1LastX128(positionKey)

	// XXX check priority ?
	position.tokensOwed0 += (amount0 + (feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128) * position.liquidity / Q128)
	position.tokensOwed1 += (amount1 + (feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128) * position.liquidity / Q128)

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128

	position.liquidity = positionLiquidity - params.liquidity
	
	// update position
	positions[string(params.tokenId)] = position

	return amount0, amount1
}

func Collect(params CollectParams) (bigint, bigint) {
	// amount0, amount1

	isAuthorizedForToken(string(params.tokenId))
	require(params.amount0Max > 0 || params.amount1Max > 0, "At least one token should be collected")

	var recipient std.Address
	if (params.recipient == zeroAddress) {
		recipient = GetOrigPkgAddr()
	} else {
		recipient = params.recipient
	}

	position := positions[string(params.tokenId)]
	poolKey := poolIdToPoolKey[position.poolId]
	// pool := PoolAddressComputeAddress(factory, poolKey)

	tokensOwed0, tokensOwed1 := position.tokensOwed0, position.tokensOwed1

	if (position.liquidity) > 0 {
		// XXX GetRealmCaller PR is going on
		// spoof orig caller
		_orig := GetOrigCaller()
		std.TestSetOrigCaller(GetOrigPkgAddr())
		pool.Burn(position.tickLower, position.tickUpper, 0)
		std.TestSetOrigCaller(_orig)

		positionKey := PositionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
		// _p := pool.positions[positionKey]
		feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.GetPoolPositionFeeGrowthInside0LastX128(positionKey), pool.GetPoolPositionFeeGrowthInside1LastX128(positionKey)

		tokensOwed0 += (feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128) * position.liquidity / Q128
		tokensOwed1 += (feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128) * position.liquidity / Q128
		

		position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
		position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
	}

	var amount0Collect, amount1Collect bigint
	if (params.amount0Max > tokensOwed0) {
		amount0Collect = tokensOwed0
	} else {
		amount0Collect = params.amount0Max
	}

	if (params.amount1Max > tokensOwed1) {
		amount1Collect = tokensOwed1
	} else {
		amount1Collect = params.amount1Max
	}

	_orig := GetOrigCaller()
	std.TestSetOrigCaller(GetOrigPkgAddr())
	amount0, amount1 := pool.Collect(
		recipient,
		position.tickLower,
		position.tickUpper,
		amount0Collect,
		amount1Collect,
	)
	std.TestSetOrigCaller(_orig)

	position.tokensOwed0, position.tokensOwed1 = tokensOwed0 - amount0Collect, tokensOwed1 - amount1Collect

	// update position
	positions[string(params.tokenId)] = position

	// burn nft if position is clear
	if position.isClear() {
		burn(string(params.tokenId))
	}
	return amount0, amount1
}

func burn(tokenId string) {
	isAuthorizedForToken(tokenId)

	position := positions[tokenId]
	require(position.isClear(), "Not cleared")
	delete(positions, tokenId)

	// XXX GetRealmCaller PR is going on
	_orig := std.GetOrigCaller()
	std.TestSetOrigCaller(std.GetOrigPkgAddr())
	nft.Burn(grc721.TokenID(tokenId))
	std.TestSetOrigCaller(_orig)
}


func isAuthorizedForToken(tokenId string) {
	require(isApprovedOrOwner(GetOrigCaller(), tokenId), "Not approved")
}

// XXX for grc721 permit
// func _getAndIncrementNonce(tokenId string) bigint {
// 	return positions[tokenId].nonce++
// }

// func _approve(to std.Address, tokenId string) {
// 	positions[tokenId].operator = to
// }