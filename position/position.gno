package position

import (
	"std"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	p "gno.land/r/pool"

	nft "gno.land/r/gnft"
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
) (uint64, bigint, bigint, bigint) {
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

	// nft.Mint(a2u(PrevRealmAddr()), grc721.TokenID(tokenId)) // owner, tokenId
	nft.Mint(a2u(GetOrigCaller()), grc721.TokenID(tokenId)) // owner, tokenId

	positionKey := positionKeyCompute(GetOrigPkgAddr(), params.tickLower, params.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.GetPoolPositionFeeGrowthInside0LastX128(positionKey), pool.GetPoolPositionFeeGrowthInside1LastX128(positionKey)

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

	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.GetPoolPositionFeeGrowthInside0LastX128(positionKey), pool.GetPoolPositionFeeGrowthInside1LastX128(positionKey)

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
	amount0Min bigint,
	amount1Min bigint,
	deadline bigint,
) (bigint, bigint) {
	decreaseLiquidityParams := DecreaseLiquidityParams{
		tokenId:    tokenId,
		liquidity:  liquidity,
		amount0Min: amount0Min,
		amount1Min: amount1Min,
		deadline:   deadline,
	}

	return decreaseLiquidity(decreaseLiquidityParams)
}

func decreaseLiquidity(params DecreaseLiquidityParams) (bigint, bigint) {
	isAuthorizedForToken(params.tokenId)
	checkDeadline(params.deadline)
	require(params.liquidity > 0, ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || liquidity(%s) > 0", params.liquidity))

	// verify tokenId
	require(exists(params.tokenId), ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || tokenId(%d) doesn't exist", params.tokenId))

	position := positions[params.tokenId]

	positionLiquidity := position.liquidity
	require(positionLiquidity >= params.liquidity, ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || positionLiquidity(%s) >= params.liquidity(%s)", positionLiquidity, params.liquidity))

	// r3v4_xxx
	// panic or remove entire liquidity
	pToken0, pToken1, pFee := poolKeyDivide(position.poolKey)
	pool := p.GetPoolFromPoolKey(position.poolKey)

	amount0, amount1 := p.Burn(pToken0, pToken1, pFee, position.tickLower, position.tickUpper, params.liquidity)

	require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || amount0(%s) >= params.amount0Min(%s) && amount1(%s) >= params.amount1Min(%s)", amount0, params.amount0Min, amount1, params.amount1Min))

	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.GetPoolPositionFeeGrowthInside0LastX128(positionKey), pool.GetPoolPositionFeeGrowthInside1LastX128(positionKey)

	// XXX check priority ?
	position.tokensOwed0 += (amount0 + (feeGrowthInside0LastX128-position.feeGrowthInside0LastX128)*position.liquidity/Q128)
	position.tokensOwed1 += (amount1 + (feeGrowthInside1LastX128-position.feeGrowthInside1LastX128)*position.liquidity/Q128)

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
	collectParams := CollectParams{
		tokenId:    tokenId,
		recipient:  recipient,
		amount0Max: amount0Max,
		amount1Max: amount1Max,
	}

	return collect(collectParams)
}

func collect(params CollectParams) (bigint, bigint) {
	// amount0, amount1

	isAuthorizedForToken(params.tokenId)
	require(params.amount0Max > 0 || params.amount1Max > 0, ufmt.Sprintf("[POSITION] position.gno__collect() || params.amount0Max(%s) > 0 || params.amount1Max(%s) > 0", params.amount0Max, params.amount1Max))

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
		feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.GetPoolPositionFeeGrowthInside0LastX128(positionKey), pool.GetPoolPositionFeeGrowthInside1LastX128(positionKey)

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
	nft.Burn(grc721.TokenID(tokenId))
}

func isAuthorizedForToken(tokenId uint64) {
	require(isApprovedOrOwner(PrevRealmAddr(), tokenId), ufmt.Sprintf("[POSITION] position.gno__isAuthorizedForToken() || caller(%s) is not approved or owner of tokenId(%s)", PrevRealmAddr(), tokenId))
}
