package position

import (
	"std"

	"gno.land/p/demo/ufmt"

	p "gno.land/r/demo/pool"

	nft "gno.land/r/demo/gnft"
)

var (
	positions map[uint64]Position = make(map[uint64]Position) // tokenId -> Position
	nextId    uint64              = 1
)

func (p Position) isClear() bool {
	return p.liquidity == 0 && p.tokensOwed0 == 0 && p.tokensOwed1 == 0
}

func Mint(
	token0 string,
	token1 string,
	fee uint16,
	tickLower int32,
	tickUpper int32,
	amount0Desired bigint,
	amount1Desired bigint,
	amount0Min bigint,
	amount1Min bigint,
	deadline bigint,
) (uint64, bigint, bigint, bigint) { // tokenId, liquidity, amount0, amount1
	if token1 < token0 {
		token0, token1 = token1, token0
		amount0Desired, amount1Desired = amount1Desired, amount0Desired
		amount0Min, amount1Min = amount1Min, amount0Min
		tickLower, tickUpper = -tickUpper, -tickLower
	}

	mintParams := MintParams{
		token0:         token0,
		token1:         token1,
		fee:            fee,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		amount0Desired: amount0Desired,
		amount1Desired: amount1Desired,
		amount0Min:     amount0Min,
		amount1Min:     amount1Min,
		deadline:       deadline,
	}

	return mint(mintParams)
}

func mint(params MintParams) (uint64, bigint, bigint, bigint) {
	checkDeadline(params.deadline)

	pool := p.GetPool(params.token0, params.token1, params.fee)
	liquidity, amount0, amount1 := addLiquidity(
		AddLiquidityParams{
			poolKey:        p.GetPoolKey(params.token0, params.token1, params.fee),
			recipient:      GetOrigPkgAddr(), // hardcoded
			tickLower:      params.tickLower,
			tickUpper:      params.tickUpper,
			amount0Desired: params.amount0Desired,
			amount1Desired: params.amount1Desired,
			amount0Min:     params.amount0Min,
			amount1Min:     params.amount1Min,
		},
	)

	tokenId := nextId
	nextId++ // nextId = nextId + 1

	nft.Mint(a2u(GetOrigCaller()), tid(tokenId)) // owner, tokenId

	positionKey := positionKeyCompute(GetOrigPkgAddr(), params.tickLower, params.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)

	position := Position{
		nonce:                    0,
		operator:                 PrevRealmAddr(),
		poolKey:                  p.GetPoolKey(params.token0, params.token1, params.fee),
		tickLower:                params.tickLower,
		tickUpper:                params.tickUpper,
		liquidity:                liquidity,
		feeGrowthInside0LastX128: feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: feeGrowthInside1LastX128,
		tokensOwed0:              0,
		tokensOwed1:              0,
	}
	positions[tokenId] = position

	return tokenId, liquidity, amount0, amount1
}

func IncreaseLiquidity(
	tokenId uint64,
	amount0Desired bigint,
	amount1Desired bigint,
	amount0Min bigint,
	amount1Min bigint,
	deadline bigint,
) (bigint, bigint, bigint) {
	increaseLiquidityParams := IncreaseLiquidityParams{
		tokenId:        tokenId,
		amount0Desired: amount0Desired,
		amount1Desired: amount1Desired,
		amount0Min:     amount0Min,
		amount1Min:     amount1Min,
		deadline:       deadline,
	}

	return increaseLiquidity(increaseLiquidityParams)
}

func increaseLiquidity(params IncreaseLiquidityParams) (bigint, bigint, bigint) {
	checkDeadline(params.deadline)

	// verify tokenId
	require(exists(params.tokenId), ufmt.Sprintf("[POSITION] position.gno__increaseLiquidity() || tokenId(%d) doesn't exist", params.tokenId))

	position := positions[params.tokenId]

	liquidity, amount0, amount1 := addLiquidity(
		AddLiquidityParams{
			poolKey:        position.poolKey,
			recipient:      GetOrigPkgAddr(),
			tickLower:      position.tickLower,
			tickUpper:      position.tickUpper,
			amount0Desired: params.amount0Desired,
			amount1Desired: params.amount1Desired,
			amount0Min:     params.amount0Min,
			amount1Min:     params.amount1Min,
		},
	)

	pool := p.GetPoolFromPoolKey(position.poolKey)

	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)

	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)

	position.tokensOwed0 += (feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128) * position.liquidity / Q128
	position.tokensOwed1 += (feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128) * position.liquidity / Q128

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
	position.liquidity += liquidity

	positions[params.tokenId] = position

	return liquidity, amount0, amount1
}

func DecreaseLiquidity(
	tokenId uint64,
	liquidity bigint,
	deadline bigint,
) (bigint, bigint) {
	decreaseLiquidityParams := DecreaseLiquidityParams{
		tokenId:   tokenId,
		liquidity: liquidity,
		deadline:  deadline,
	}

	return decreaseLiquidity(decreaseLiquidityParams)
}

func decreaseLiquidity(params DecreaseLiquidityParams) (bigint, bigint) {
	isAuthorizedForToken(params.tokenId)
	checkDeadline(params.deadline)
	require(params.liquidity >= 0, ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || liquidity(%d) >= 0", params.liquidity))

	// verify tokenId
	require(exists(params.tokenId), ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || tokenId(%d) doesn't exist", params.tokenId))

	position := positions[params.tokenId]

	positionLiquidity := position.liquidity
	if positionLiquidity < params.liquidity {
		// remove entire liquidity
		params.liquidity = positionLiquidity
	}

	pToken0, pToken1, pFee := poolKeyDivide(position.poolKey)
	pool := p.GetPoolFromPoolKey(position.poolKey)

	amount0, amount1 := p.Burn(pToken0, pToken1, pFee, position.tickLower, position.tickUpper, params.liquidity)

	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)

	position.tokensOwed0 += amount0 + ((feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128) * position.liquidity / Q128)
	position.tokensOwed1 += amount1 + ((feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128) * position.liquidity / Q128)

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128

	position.liquidity = positionLiquidity - params.liquidity

	positions[params.tokenId] = position

	return amount0, amount1
}

func Collect(
	tokenId uint64,
	recipient std.Address,
	amount0Max bigint,
	amount1Max bigint,
) (bigint, bigint) {
	isAuthorizedForToken(tokenId)
	require(amount0Max > 0 || amount1Max > 0, ufmt.Sprintf("[POSITION] position.gno__Collect() || amount0Max(%s) > 0 || amount1Max(%s) > 0", amount0Max, amount1Max))

	collectParams := CollectParams{
		tokenId:    tokenId,
		recipient:  recipient,
		amount0Max: amount0Max,
		amount1Max: amount1Max,
	}

	return collect(collectParams)
}

func collect(params CollectParams) (bigint, bigint) {
	var recipient std.Address
	if params.recipient == ZERO_ADDRESS {
		recipient = GetOrigPkgAddr()
	} else {
		recipient = params.recipient
	}

	position := positions[params.tokenId]
	tokensOwed0, tokensOwed1 := position.tokensOwed0, position.tokensOwed1

	pToken0, pToken1, pFee := poolKeyDivide(position.poolKey)
	pool := p.GetPoolFromPoolKey(position.poolKey)

	if (position.liquidity) > 0 {
		p.Burn(pToken0, pToken1, pFee, position.tickLower, position.tickUpper, 0)

		positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
		feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)

		tokensOwed0 += (feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128) * position.liquidity / Q128
		tokensOwed1 += (feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128) * position.liquidity / Q128

		position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
		position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
	}

	var amount0Collect, amount1Collect bigint
	if params.amount0Max > tokensOwed0 {
		amount0Collect = tokensOwed0
	} else {
		amount0Collect = params.amount0Max
	}

	if params.amount1Max > tokensOwed1 {
		amount1Collect = tokensOwed1
	} else {
		amount1Collect = params.amount1Max
	}

	amount0, amount1 := p.Collect(
		pToken0,
		pToken1,
		pFee,
		recipient,
		position.tickLower,
		position.tickUpper,
		amount0Collect,
		amount1Collect,
	)

	position.tokensOwed0, position.tokensOwed1 = tokensOwed0-amount0Collect, tokensOwed1-amount1Collect

	positions[params.tokenId] = position

	// burn nft if position is clear
	if position.isClear() {
		burn(params.tokenId)
	}
	return amount0, amount1
}

func burn(tokenId uint64) {
	isAuthorizedForToken(tokenId)

	position := positions[tokenId]

	require(position.isClear(), ufmt.Sprintf("[POSITION] position.gno__burn() || position(tokenId:%d) isn't clear(has something)", tokenId))

	delete(positions, tokenId)
	nft.Burn(tid(tokenId))
}

func isAuthorizedForToken(tokenId uint64) {
	require(isApprovedOrOwner(PrevRealmAddr(), tokenId), ufmt.Sprintf("[POSITION] position.gno__isAuthorizedForToken() || caller(%s) is not approved or owner of tokenId(%d)", PrevRealmAddr(), tokenId))
}
