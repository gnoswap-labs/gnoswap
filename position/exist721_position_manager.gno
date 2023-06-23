package position

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	p "gno.land/r/pool"

	nft "gno.land/r/gnft"
)

var (
	// poolIds         map[std.Address]bigint = make(map[std.Address]bigint)
	// poolIdToPoolKey map[bigint]PoolKey = make(map[bigint]PoolKey)
	// nextPoolId bigint = 1

	// positions       map[string]Position = make(map[string]Position)
	positions avl.Tree // tokenId -> Position
	nextId    bigint   = 1
)

func (p Position) isClear() bool {
	return p.liquidity == 0 && p.tokensOwed0 == 0 && p.tokensOwed1 == 0
}

func Mint(
	token0 string,
	token1 string,
	fee bigint,
	tickLower bigint,
	tickUpper bigint,
	amount0Desired bigint,
	amount1Desired bigint,
	amount0Min bigint,
	amount1Min bigint,
	deadline bigint,
) (string, bigint, bigint, bigint) {
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

// tokenId, liquidity, amount0, amount1
func mint(params MintParams) (string, bigint, bigint, bigint) {
	checkDeadline(params.deadline)

	pool := p.GetPool(params.token0, params.token1, params.fee)
	liquidity, amount0, amount1 := addLiquidity(
		AddLiquidityParams{
			poolKey:        p.GetPoolKey(params.token0, params.token1, params.fee),
			recipient:      GetOrigPkgAddr(),
			tickLower:      params.tickLower,
			tickUpper:      params.tickUpper,
			amount0Desired: params.amount0Desired,
			amount1Desired: params.amount1Desired,
			amount0Min:     params.amount0Min,
			amount1Min:     params.amount1Min,
		},
	)

	tokenId := string(nextId)
	nextId++ // nextId = nextId + 1

	// XXX grc721 should use PrevRealm()
	_orig := GetOrigCaller()
	std.TestSetOrigCaller(GetOrigPkgAddr())
	nft.Mint(a2u(_orig), grc721.TokenID(tokenId)) // owner, tokenId
	std.TestSetOrigCaller(_orig)

	positionKey := PositionKeyCompute(GetOrigPkgAddr(), params.tickLower, params.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.GetPoolPositionFeeGrowthInside0LastX128(positionKey), pool.GetPoolPositionFeeGrowthInside1LastX128(positionKey)

	position := Position{
		nonce:                    0,
		operator:                 GetOrigCaller(),
		poolKey:                  p.GetPoolKey(params.token0, params.token1, params.fee),
		tickLower:                params.tickLower,
		tickUpper:                params.tickUpper,
		liquidity:                liquidity,
		feeGrowthInside0LastX128: feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: feeGrowthInside1LastX128,
		tokensOwed0:              0,
		tokensOwed1:              0,
	}
	positions.Set(tokenId, position)

	return tokenId, liquidity, amount0, amount1
}

func IncreaseLiquidity(
	tokenId bigint,
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
	require(Exists(string(params.tokenId)), "Invalid token ID")

	// position := positions[string(params.tokenId)]
	_position, ok := positions.Get(string(params.tokenId))
	var position Position
	if ok {
		position = _position.(Position)
	} else {
		position = Position{}
	}

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

	positionKey := PositionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	// _p := p.positions[positionKey]
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.GetPoolPositionFeeGrowthInside0LastX128(positionKey), pool.GetPoolPositionFeeGrowthInside1LastX128(positionKey)

	position.tokensOwed0 += (feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128) * position.liquidity / Q128
	position.tokensOwed1 += (feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128) * position.liquidity / Q128

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
	position.liquidity += liquidity

	return liquidity, amount0, amount1
}

func DecreaseLiquidity(
	tokenId bigint,
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
	isAuthorizedForToken(string(params.tokenId))
	checkDeadline(params.deadline)
	require(params.liquidity > 0, "Cannot remove 0 liquidity")

	// verify tokenId
	require(Exists(string(params.tokenId)), "Invalid token ID")

	// position := positions[string(params.tokenId)]
	_position, ok := positions.Get(string(params.tokenId))
	var position Position
	if ok {
		position = _position.(Position)
	} else {
		position = Position{}
	}

	positionLiquidity := position.liquidity
	require(positionLiquidity >= params.liquidity, ufmt.Sprintf("Cannot withdraw more liquidity(%s) than is in the position(%s)", params.liquidity, positionLiquidity))

	// XXX grc20 should use PrevRealm()
	_orig := GetOrigCaller()
	std.TestSetOrigCaller(GetOrigPkgAddr())

	pToken0, pToken1, pFee := poolKeyDivide(position.poolKey)
	pool := p.GetPoolFromPoolKey(position.poolKey)

	amount0, amount1 := p.Burn(pToken0, pToken1, pFee, position.tickLower, position.tickUpper, params.liquidity)
	std.TestSetOrigCaller(_orig)

	require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, "PM_Price slippage check")

	positionKey := PositionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	// _p := p.positions[positionKey]
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.GetPoolPositionFeeGrowthInside0LastX128(positionKey), pool.GetPoolPositionFeeGrowthInside1LastX128(positionKey)

	// XXX check priority ?
	position.tokensOwed0 += (amount0 + (feeGrowthInside0LastX128-position.feeGrowthInside0LastX128)*position.liquidity/Q128)
	position.tokensOwed1 += (amount1 + (feeGrowthInside1LastX128-position.feeGrowthInside1LastX128)*position.liquidity/Q128)

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128

	position.liquidity = positionLiquidity - params.liquidity

	// update position
	// positions[string(params.tokenId)] = position
	positions.Set(string(params.tokenId), position)

	return amount0, amount1
}

func Collect(
	tokenId bigint,
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

	isAuthorizedForToken(string(params.tokenId))
	require(params.amount0Max > 0 || params.amount1Max > 0, "At least one token should be collected")

	var recipient std.Address
	if params.recipient == zeroAddress {
		recipient = GetOrigPkgAddr()
	} else {
		recipient = params.recipient
	}

	// position := positions[string(params.tokenId)]
	_position, ok := positions.Get(string(params.tokenId))
	var position Position
	if ok {
		position = _position.(Position)
	} else {
		position = Position{}
	}

	tokensOwed0, tokensOwed1 := position.tokensOwed0, position.tokensOwed1
	pToken0, pToken1, pFee := poolKeyDivide(position.poolKey)
	pool := p.GetPoolFromPoolKey(position.poolKey)

	if (position.liquidity) > 0 {
		// XXX grc20 should use PrevRealm()
		_orig := GetOrigCaller()
		std.TestSetOrigCaller(GetOrigPkgAddr())
		p.Burn(pToken0, pToken1, pFee, position.tickLower, position.tickUpper, 0)
		std.TestSetOrigCaller(_orig)

		positionKey := PositionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
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

	_orig := GetOrigCaller()
	std.TestSetOrigCaller(GetOrigPkgAddr())
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
	std.TestSetOrigCaller(_orig)

	position.tokensOwed0, position.tokensOwed1 = tokensOwed0-amount0Collect, tokensOwed1-amount1Collect

	// update position
	// positions[string(params.tokenId)] = position
	positions.Set(string(params.tokenId), position)

	// burn nft if position is clear
	if position.isClear() {
		burn(string(params.tokenId))
	}
	return amount0, amount1
}

func burn(tokenId string) {
	isAuthorizedForToken(tokenId)

	// position := positions[tokenId]
	_position, ok := positions.Get(tokenId)
	var position Position
	if ok {
		position = _position.(Position)
	} else {
		position = Position{}
	}

	require(position.isClear(), "Not cleared")

	// delete(positions, tokenId)
	positions.Remove(tokenId)

	// XXX grc721 should use PrevRealm()
	_orig := std.GetOrigCaller()
	std.TestSetOrigCaller(GetOrigPkgAddr())
	nft.Burn(grc721.TokenID(tokenId))
	std.TestSetOrigCaller(_orig)
}

func isAuthorizedForToken(tokenId string) {
	require(isApprovedOrOwner(GetOrigCaller(), tokenId), "Not approved")
}
