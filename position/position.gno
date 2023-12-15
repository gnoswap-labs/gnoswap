package position

import (
	"std"

	"gno.land/p/demo/ufmt"

	p "gno.land/r/demo/pool"

	"gno.land/r/demo/gnft"
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

	gnft.Mint(a2u(GetOrigCaller()), tid(tokenId)) // owner, tokenId

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

func Burn(tokenId uint64) {
} (bigint, bigint, string) {
	// verify tokenId
	require(exists(tokenId), ufmt.Sprintf("[POSITION] position.gno__Burn() || tokenId(%d) doesn't exist", tokenId))

	// MUST BE OWNER TO BURN ( can not be approved address )
	owner := gnft.OwnerOf(tid(tokenId))
	require(owner == GetOrigCaller(), ufmt.Sprintf("[POSITION] position.gno__Burn() || only owner(%s) can burn tokenId(%d), caller(%s)", owner, tokenId, GetOrigCaller()))

	position := positions[tokenId]
	positionLiquidity := position.liquidity

	pool := p.GetPoolFromPoolKey(position.poolKey) // poolKey == poolPath

	pToken0, pToken1, pFee := poolKeyDivide(position.poolKey)
	burnAmount0, burnAmount1 := p.Burn(pToken0, pToken1, pFee, position.tickLower, position.tickUpper, positionLiquidity)

	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)

	position.tokensOwed0 += burnAmount0 + ((feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128) * position.liquidity / Q128)
	position.tokensOwed1 += burnAmount1 + ((feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128) * position.liquidity / Q128)

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128

	position.liquidity = 0
	positions[tokenId] = position


	collectAmount0, collectAmount1 := p.Collect(
		pToken0,
		pToken1,
		pFee,
		GetOrigCaller(),
		position.tickLower,
		position.tickUpper,
		position.tokensOwed0,
		position.tokensOwed1,
	)

	position.tokensOwed0 = 0
	position.tokensOwed1 = 0

	positions[tokenId] = position

	// MUST BE BURN NFT
	burnNFT(tokenId)

}


func CollectFee(tokenId uint64) {
	// verify tokenId
	require(exists(tokenId), ufmt.Sprintf("[POSITION] position.gno__CollectFee() || tokenId(%d) doesn't exist", tokenId))

	isAuthorizedForToken(tokenId)
	require(owner == GetOrigCaller(), ufmt.Sprintf("[POSITION] position.gno__CollectFee() || only owner(%s) can collect fee of tokenId(%d), caller(%s)", owner, tokenId, GetOrigCaller()))

	position := positions[tokenId]
	tokensOwed0, tokensOwed1 := position.tokensOwed0, position.tokensOwed1

	pToken0, pToken1, pFee := poolKeyDivide(position.poolKey)
	p.Burn(pToken0, pToken1, pFee, position.tickLower, position.tickUpper, 0) // burn '0' liquidity to collect fee

	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	pool := p.GetPoolFromPoolKey(position.poolKey)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)

	tokensOwed0 += (feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128) * position.liquidity / Q128
	tokensOwed1 += (feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128) * position.liquidity / Q128

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128

	amount0, amount1 := p.Collect(
		pToken0,
		pToken1,
		pFee,
		GetOrigCaller(),
		position.tickLower,
		position.tickUpper,
		tokensOwed0,
		tokensOwed1,
	)

	position.tokensOwed0, position.tokensOwed1 = tokensOwed-amount0, tokensOwed1-amount1
	positions[tokenId] = position
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

func burnNFT(tokenId uint64) {
	isAuthorizedForToken(tokenId)

	position := positions[tokenId]

	require(position.isClear(), ufmt.Sprintf("[POSITION] position.gno__burnNFT() || position(tokenId:%d) isn't clear(liquidity:%d, tokensOwed0:%d, tokensOwed1:)", tokenId, position.liquidity, position.tokensOwed0, position.tokensOwed1))

	positions = deleteFromPositions(positions, tokenId)
	gnft.Burn(tid(tokenId))
}

func isAuthorizedForToken(tokenId uint64) {
	require(isApprovedOrOwner(PrevRealmAddr(), tokenId), ufmt.Sprintf("[POSITION] position.gno__isAuthorizedForToken() || caller(%s) is not approved or owner of tokenId(%d)", PrevRealmAddr(), tokenId))
}

func deleteFromPositions(m map[uint64]Position, key uint64) map[uint64]Position {
	if _, ok := m[key]; ok {
		newMap := make(map[uint64]Position)
		for k, v := range m {
			if k != key {
				newMap[k] = v
			}
		}

		return newMap
	}

	return m
}
