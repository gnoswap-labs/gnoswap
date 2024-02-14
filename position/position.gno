package position

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"

	pl "gno.land/r/demo/pool"

	"gno.land/r/demo/gnft"
)

var (
	positions map[uint64]Position = make(map[uint64]Position) // tokenId -> Position
	nextId    uint64              = 1
)

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

	pool := pl.GetPool(params.token0, params.token1, params.fee)
	liquidity, amount0, amount1 := addLiquidity(
		AddLiquidityParams{
			poolKey:        pl.GetPoolPath(params.token0, params.token1, params.fee),
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

	gnft.Mint(a2u(std.GetOrigCaller()), tid(tokenId)) // owner, tokenId

	positionKey := positionKeyCompute(GetOrigPkgAddr(), params.tickLower, params.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)

	position := Position{
		nonce:                    0,
		operator:                 std.PrevRealm().Addr(),
		poolKey:                  pl.GetPoolPath(params.token0, params.token1, params.fee),
		tickLower:                params.tickLower,
		tickUpper:                params.tickUpper,
		liquidity:                liquidity,
		feeGrowthInside0LastX128: feeGrowthInside0LastX128.Bigint(),
		feeGrowthInside1LastX128: feeGrowthInside1LastX128.Bigint(),
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
) (uint64, bigint, bigint, bigint) { // tokenId, liquidity, amount0, amount1
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

func increaseLiquidity(params IncreaseLiquidityParams) (uint64, bigint, bigint, bigint) {
	// verify tokenId exists
	require(exists(params.tokenId), ufmt.Sprintf("[POSITION] position.gno__increaseLiquidity() || tokenId(%d) doesn't exist", params.tokenId))

	// MUST BE OWNER TO INCREASE LIQUIDITY
	// can not be approved address > staked position can be modified
	owner := gnft.OwnerOf(tid(params.tokenId))
	require(owner == std.GetOrigCaller(), ufmt.Sprintf("[POSITION] position.gno__increaseLiquidity() || only owner can increase liquidity__owner(%s) == std.GetOrigCaller(%s)", owner, std.GetOrigCaller()))

	checkDeadline(params.deadline)

	position := positions[params.tokenId]
	liquidity, amount0, amount1 := addLiquidity(
		AddLiquidityParams{
			poolKey:        position.poolKey,
			tickLower:      position.tickLower,
			tickUpper:      position.tickUpper,
			amount0Desired: params.amount0Desired,
			amount1Desired: params.amount1Desired,
			amount0Min:     params.amount0Min,
			amount1Min:     params.amount1Min,
		},
	)

	pool := pl.GetPoolFromPoolPath(position.poolKey)

	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)

	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)

	position.tokensOwed0 += (feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128) * position.liquidity / consts.Q128
	position.tokensOwed1 += (feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128) * position.liquidity / consts.Q128

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
	position.liquidity += liquidity

	positions[params.tokenId] = position

	return params.tokenId, liquidity, amount0, amount1
}

// *IMPORTANT*
// DecreaseLiquidity() will return DECREASED amonut0, amount1
// HOWEVER, internally it also execute CollectFee() to collect fee which DOES NOT INCLUDE IN RETURN VALUE
func DecreaseLiquidity(
	tokenId uint64,
	liquidity bigint,
	amount0Min bigint,
	amount1Min bigint,
	deadline bigint,
) (uint64, bigint, bigint, bigint, string) { // tokenId, liquidity, amount0, amount1, poolPath
	decreaseLiquidityParams := DecreaseLiquidityParams{
		tokenId:    tokenId,
		liquidity:  liquidity,
		amount0Min: amount0Min,
		amount1Min: amount1Min,
		deadline:   deadline,
	}

	return decreaseLiquidity(decreaseLiquidityParams)
}

func decreaseLiquidity(params DecreaseLiquidityParams) (uint64, bigint, bigint, bigint, string) {
	// verify tokenId
	require(exists(params.tokenId), ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || tokenId(%d) doesn't exist", params.tokenId))

	// MUST BE OWNER TO DECREASE LIQUIDITY ( can not be approved address )
	owner := gnft.OwnerOf(tid(params.tokenId))
	require(owner == std.GetOrigCaller(), ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || only owner can decrease liquidity__owner(%s) == std.GetOrigCaller(%s)", owner, std.GetOrigCaller()))

	checkDeadline(params.deadline)

	require(params.liquidity >= 0, ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || liquidity(%d) >= 0", params.liquidity))

	// BEFORE DECREASE LIQUIDITY, COLLECT FEE FIRST
	CollectFee(params.tokenId)

	position := positions[params.tokenId]

	positionLiquidity := position.liquidity
	if positionLiquidity < params.liquidity {
		// if too many liquidity requested, decrease to entire liquidity
		params.liquidity = positionLiquidity
	}

	pToken0, pToken1, pFee := poolKeyDivide(position.poolKey)
	pool := pl.GetPoolFromPoolPath(position.poolKey)

	burnedAmount0, burnedAmount1 := pl.Burn(pToken0, pToken1, pFee, position.tickLower, position.tickUpper, params.liquidity)
	require(burnedAmount0 >= params.amount0Min && burnedAmount1 >= params.amount1Min, ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || burnedAmount0(%d) >= amount0Min(%d) && burnedAmount1(%d) >= amount1Min(%d)", burnedAmount0, params.amount0Min, burnedAmount1, params.amount1Min))

	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)

	tokensOwed0 += (feeGrowthInside0LastX128.Bigint() - position.feeGrowthInside0LastX128) * position.liquidity / Q128
	tokensOwed1 += (feeGrowthInside1LastX128.Bigint() - position.feeGrowthInside1LastX128) * position.liquidity / Q128

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128.Bigint()
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128.Bigint()

	amount0, amount1 := p.Collect(
		pToken0,
		pToken1,
		pFee,
		std.GetOrigCaller(),
		position.tickLower,
		position.tickUpper,
		burnedAmount0,
		burnedAmount1,
	)

	position.tokensOwed0 -= amount0
	position.tokensOwed1 -= amount1

	positions[params.tokenId] = position

	if position.isClear() {
		// burnNFT(params.tokenId) // actual burn
		burnPosition(params.tokenId) // just update flag
	}

	return params.tokenId, params.liquidity, amount0, amount1, position.poolKey
}

func CollectFee(tokenId uint64) (uint64, bigint, bigint, string) { // tokenId, tokensOwed0, tokensOwed1, poolPath
	// verify tokenId exists
	require(exists(tokenId), ufmt.Sprintf("[POSITION] position.gno__CollectFee() || tokenId(%d) doesn't exist", tokenId))

	// verify owner or approved
	isAuthorizedForToken(tokenId)

	position := positions[tokenId]

	token0, token1, fee := poolKeyDivide(position.poolKey)
	pl.Burn(
		token0,
		token1,
		fee,
		position.tickLower,
		position.tickUpper,
		0, // burn '0' liquidity to collect fee
	)

	tokensOwed0, tokensOwed1 := position.tokensOwed0, position.tokensOwed1
	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	pool := pl.GetPoolFromPoolPath(position.poolKey)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)

	position.tokensOwed0 += burnAmount0 + ((feeGrowthInside0LastX128.Bigint() - position.feeGrowthInside0LastX128) * position.liquidity / Q128)
	position.tokensOwed1 += burnAmount1 + ((feeGrowthInside1LastX128.Bigint() - position.feeGrowthInside1LastX128) * position.liquidity / Q128)

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128.Bigint()
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128.Bigint()

	position.liquidity = 0
	positions[tokenId] = position

	collectAmount0, collectAmount1 := p.Collect(
		pToken0,
		pToken1,
		pFee,
		GetOrigCaller(),
		position.tickLower,
		position.tickUpper,
		consts.MAX_UINT64, // r3v4_xxx: current grc20 handles amount by `uint64`
		consts.MAX_UINT64, // r3v4_xxx: current grc20 handles amount by `uint64`
	)

	position.tokensOwed0, position.tokensOwed1 = tokensOwed0-amount0, tokensOwed1-amount1
	positions[tokenId] = position

	// handle withdrawal fee
	withoutFee0, withoutFee1 := pl.HandleWithdrawalFee(tokenId, token0, amount0, token1, amount1)

	return tokenId, withoutFee0, withoutFee1, position.poolKey
}

func burnNFT(tokenId uint64) {
	isAuthorizedForToken(tokenId)

	position := positions[tokenId]

	require(position.isClear(), ufmt.Sprintf("[POSITION] position.gno__burnNFT() || position(tokenId:%d) isn't clear(liquidity:%d, tokensOwed0:%d, tokensOwed1:%d)", tokenId, position.liquidity, position.tokensOwed0, position.tokensOwed1))

	positions = deleteFromPositions(positions, tokenId)
	gnft.Burn(tid(tokenId))
}

func burnPosition(tokenId uint64) {
	position := positions[tokenId]
	require(position.isClear(), ufmt.Sprintf("[POSITION] position.gno__burnPosition() || position(tokenId:%d) isn't clear(liquidity:%d, tokensOwed0:%d, tokensOwed1:%d)", tokenId, position.liquidity, position.tokensOwed0, position.tokensOwed1))

	position.burned = true
	positions[tokenId] = position
}

func isAuthorizedForToken(tokenId uint64) {
	require(isApprovedOrOwner(std.PrevRealm().Addr(), tokenId), ufmt.Sprintf("[POSITION] position.gno__isAuthorizedForToken() || caller(%s) is not approved or owner of tokenId(%d)", std.PrevRealm().Addr(), tokenId))
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

func (p Position) isClear() bool {
	return p.liquidity == 0 && p.tokensOwed0 == 0 && p.tokensOwed1 == 0
}
