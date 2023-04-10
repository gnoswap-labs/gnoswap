package liquidity

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/grc/grc721"
	// core "gno.land/p/demo/pool"
)

var (
	poolIds         avl.Tree
	poolIdToPoolKey avl.Tree
	positions       avl.Tree
	nextId          bigint = 1
	nextPoolId      bigint = 1
	nft             = grc721.NewBasicNFT("Gnoswap V3 Positions NFT-V1", "GNO-V3-POS")
)

type Position struct {
	// the nonce for permits
	Nonce bigint
	// the address that is approved for spending this token
	Operator std.Address
	// the ID of the pool with which this token is connected
	PoolId bigint
	// the tick range of the position
	TickLower bigint
	TickUpper bigint
	// the liquidity of the position
	Liquidity bigint
	// the fee growth of the aggregate position as of the last action on the individual position
	FeeGrowthInside0Last bigint
	FeeGrowthInside1Last bigint
	// how many uncollected tokens are owed to the position, as of the last computation
	TokensOwed0 bigint
	TokensOwed1 bigint
}


func Init(
	_factory std.Address,
	_WETH9 std.Address,
	_tokenDescriptor_ std.Address
) {
	// XXX create new grc721
}



func Positions(tokenId string) (Position, PoolKey) {
	rawPosition, ok := positions.Get(tokenId)
	if !ok {
		panic("Invalid token ID")
	}
	position := rawPosition.(Position)
	rawPoolKey, ok := poolIdToPoolKey.Get(position.PoolId.String())
	if !ok {
		panic("Invalid pool key")
	}
	poolKey := rawPoolKey.(PoolKey)
}

func cachePoolKey(pool std.Address, poolKey PoolKey) bigint {
	poolId, ok := poolIds.Get(pool.String())
	if !ok {
		poolId = nextPoolId
		poolIds.Set(pool.String(), poolId)
		poolIdToPoolKey.Set(poolId.(bigint).String(), poolKey)
		nextPoolId = nextPoolId + 1
	}
	return poolId.(bigint)
}

func Mint(
	token0 std.Address, 
	token1 std.Address, 
	fee bigint, 
	tickLower bigint, 
	tickUpper bigint,
	amount0DesiredStr string, 
	amount1DesiredStr string, 
	amount0MinStr string, 
	amount1MinStr string, 
	recipient std.Address, 
	deadline uint64,
) string {
	CheckDeadline(deadline)

	amount0Desired, err := string(amount0DesiredStr)
	if err != nil {
		panic(err)
	}
	amount1Desired, err := string(amount1DesiredStr)
	if err != nil {
		panic(err)
	}
	amount0Min, err := string(amount0MinStr)
	if err != nil {
		panic(err)
	}
	amount1Min, err := string(amount1MinStr)
	if err != nil {
		panic(err)
	}

	// IUniswapV3Pool pool;
	// (liquidity, amount0, amount1, pool) = addLiquidity(
	// 	AddLiquidityParams({
	// 		token0: params.token0,
	// 		token1: params.token1,
	// 		fee: params.fee,
	// 		recipient: address(this),
	// 		tickLower: params.tickLower,
	// 		tickUpper: params.tickUpper,
	// 		amount0Desired: params.amount0Desired,
	// 		amount1Desired: params.amount1Desired,
	// 		amount0Min: params.amount0Min,
	// 		amount1Min: params.amount1Min
	// 	})
	// );
	addLiquidity(token0, token1, uint(fee), recipient, int(tickLower), int(tickUpper), amount0Desired, amount1Desired, amount0Min, amount1Min)

	// bytes32 positionKey = PositionKey.compute(address(this), params.tickLower, params.tickUpper);
	// (, bigdec feeGrowthInside0Last, bigdec feeGrowthInside1Last, , ) = pool.positions(positionKey);

	// _mint(params.recipient, (tokenId = _nextId++));
	tokenId := nextId.String()
	nft.Mint(recipient, grc721.TokenID(tokenId))

	// bytes32 positionKey = PositionKey.compute(address(this), params.tickLower, params.tickUpper);
	// (, bigdec feeGrowthInside0Last, bigdec feeGrowthInside1Last, , ) = pool.positions(positionKey);
	pkgaddr := GetOrigPkgAddr()
	positionKey := PositionKeyCompute(pkgaddr, tickLower, tickUpper)
	feeGrowthInside0Last := 0
	feeGrowthInside1Last := 0

	// uint80 poolId =
	// 	cachePoolKey(
	// 		address(pool),
	// 		PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee})
	// 	);
	poolId := 0

	// _positions[tokenId] = Position({
	// 	nonce: 0,
	// 	operator: address(0),
	// 	poolId: poolId,
	// 	tickLower: params.tickLower,
	// 	tickUpper: params.tickUpper,
	// 	liquidity: liquidity,
	// 	feeGrowthInside0Last: feeGrowthInside0Last,
	// 	feeGrowthInside1Last: feeGrowthInside1Last,
	// 	tokensOwed0: 0,
	// 	tokensOwed1: 0
	// });
	positions.Set(tokenId, Position{
		Nonce:                    0,
		Operator:                 zeroAddress,
		PoolId:                   poolId,
		TickLower:                0,
		TickUpper:                0,
		Liquidity:                0,
		FeeGrowthInside0Last: 0,
		FeeGrowthInside1Last: 0,
		TokensOwed0:              0,
		TokensOwed1:              0,
	})

	// emit IncreaseLiquidity(tokenId, liquidity, amount0, amount1);
	emit(&IncreaseLiquidityEvent{TokenId: tokenId})

	nextId = nextId++
	return tokenId
}

// modifier
func isAuthorizedForToken(tokenId string) {
	// require(_isApprovedOrOwner(msg.sender, tokenId), 'Not approved');
	// _;
	caller := GetOrigCaller()
	if !IsApprovedOrOwner(caller, tokenId) {
		panic("Not approved")
	}
}

func IsApprovedOrOwner(addr std.Address, tid string) bool {
	owner, err := nft.OwnerOf(grc721.TokenID(tid))
	if err != nil {
		return false
	}

	if addr == owner.(std.Address) || nft.IsApprovedForAll(owner.(std.Address), addr) {
		return true
	}

	_, err = nft.GetApproved(grc721.TokenID(tid))
	if err != nil {
		return false
	}

	return true
}

func TokenURI(tokenId string) string {
	// require(_exists(tokenId));
	// return INonfungibleTokenPositionDescriptor(_tokenDescriptor).tokenURI(this, tokenId);
	if !Exists(tokenId) {
		panic("Invalid tokenId")
	}
	return ""
}

func Exists(tid string) bool {
	_, err := nft.OwnerOf(grc721.TokenID(tid))
	return err == nil
}

func BaseURI() string {
	return ""
}

func IncreaseLiquidity(tokenId string, amount0Desired bigint, amount1Desired bigint,
	amount0Min bigint, amount1Min bigint, deadline uint64,
) {
	// Position storage position = _positions[params.tokenId];
	position, _ := positions.Get(tokenId)

	// PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
	poolKey, ok := poolIdToPoolKey.Get(position.PoolId.String())
	if !ok {
		panic("invalid position")
	}

	// IUniswapV3Pool pool;
	// (liquidity, amount0, amount1, pool) = addLiquidity(
	// 	AddLiquidityParams({
	// 		token0: poolKey.token0,
	// 		token1: poolKey.token1,
	// 		fee: poolKey.fee,
	// 		tickLower: position.tickLower,
	// 		tickUpper: position.tickUpper,
	// 		amount0Desired: params.amount0Desired,
	// 		amount1Desired: params.amount1Desired,
	// 		amount0Min: params.amount0Min,
	// 		amount1Min: params.amount1Min,
	// 		recipient: address(this)
	// 	})
	// );
	liquidity := 0
	amount0 := 0
	amount1 := 0

	// bytes32 positionKey = PositionKey.compute(address(this), position.tickLower, position.tickUpper);
	// (, bigdec feeGrowthInside0Last, bigdec feeGrowthInside1Last, , ) = pool.positions(positionKey);
	pkgaddr := std.GetOrigPkgAddr()
	positionKey := PositionKeyCompute(pkgaddr, position.TickLower, position.TickUpper)
	feeGrowthInside0Last := 0
	feeGrowthInside1Last := 0

	// XXX Find Q128
	// position.tokensOwed0 += uint128(
	// 	FullMath.mulDiv(
	// 		feeGrowthInside0Last - position.feeGrowthInside0Last,
	// 		position.liquidity,
	// 		FixedPoint128.Q128
	// 	)
	// );
	// position.tokensOwed1 += uint128(
	// 	FullMath.mulDiv(
	// 		feeGrowthInside1Last - position.feeGrowthInside1Last,
	// 		position.liquidity,
	// 		FixedPoint128.Q128
	// 	)
	// );
	fixedPoint,_ := bigint("340282366920938463463374607431768211456") /// xxx find origin value
	position.TokensOwed0 = position.TokenOwed0 + feeGrowthInside0Last - position.FeeGrowthInside0Last * position.Liquidity / fixedPoint
	position.TokensOwed1 = position.TokenOwed1 + feeGrowthInside1Last - position.FeeGrowthInside1Last * position.Liquidity / fixedPoint

	position.FeeGrowthInside0Last = feeGrowthInside0Last
	position.FeeGrowthInside1Last = feeGrowthInside1Last
	position.Liquidity = position.Liquidity + liquidity
}

func DecreaseLiquidity(tokenId string, liquidity bigint,
	amount0Min bigint, amount1Min bigint, deadline uint64,
) {
	if liquidity.IsZero() {
		panic("require liquidity > 0")
	}

	isAuthorizedForToken(tokenId)
	CheckDeadline(deadline)

	// require(params.liquidity > 0);
	// Position storage position = _positions[params.tokenId];
	position, _ := Positions(tokenId)

	// bigdec positionLiquidity = position.liquidity;
	// require(positionLiquidity >= params.liquidity);
	positionLiquidity := position.Liquidity
	if positionLiquidity < liquidity {
		panic("required positionLiquidity >= liquidity")
	}

	// PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
	// IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));
	// (amount0, amount1) = pool.burn(position.tickLower, position.tickUpper, params.liquidity);
	amount0 := 0
	amount1 := 0

	// require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, 'Price slippage check');
	if amount0.Cmp(amount0Min) < 0 || amount1.Cmp(amount1Min) < 0 {
		panic("Price slippage check")
	}

	// bytes32 positionKey = PositionKey.compute(address(this), position.tickLower, position.tickUpper);
	// // this is now updated to the current transaction
	// (, bigdec feeGrowthInside0Last, bigdec feeGrowthInside1Last, , ) = pool.positions(positionKey);
	pkgaddr := GetOrigPkgAddr()
	positionKey := PositionKeyCompute(pkgaddr, position.TickLower, position.TickUpper)
	feeGrowthInside0Last := 0
	feeGrowthInside1Last := 0
	fixedPoint128 = bigint("340282366920938463463374607431768211456")


	position.TokensOwed0 = position.TokensOwed0 + amount0 + (feeGrowthInside0Last - position.FeeGrowthInside0Last) * positionLiquidity / fixedPoint128
	position.TokensOwed1 = position.TokensOwed1 + amount1 + (feeGrowthInside1Last - position.FeeGrowthInside1Last) * positionLiquidity / fixedPoint128

	position.FeeGrowthInside0Last = feeGrowthInside0Last
	position.FeeGrowthInside1Last = feeGrowthInside1Last
	position.Liquidity = liquidity
}

func Collect(tokenId string, recipient std.Address, amount0Max bigint, amount1Max bigint) {
	// require(params.amount0Max > 0 || params.amount1Max > 0);
	if amount0Max == 0 && amount1Max == 0 {
		panic("require(params.amount0Max > 0 || params.amount1Max > 0)")
	}

	if recipient == zeroAddress {
		pkgaddr := std.GetOrigPkgAddr()
		recipient = pkgaddr
	}

	// Position storage position = _positions[params.tokenId];
	position, _ := positions.Get(tokenId)

	// PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
	poolKey, ok := poolIdToPoolKey.Get(position.PoolId.String())
	if !ok {
		panic("invalid position")
	}

	// IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));

	// (bigdec tokensOwed0, bigdec tokensOwed1) = (position.tokensOwed0, position.tokensOwed1);
	tokensOwed0 := position.TokensOwed0
	tokensOwed1 := position.TokensOwed1

	// // trigger an update of the position fees owed and fee growth snapshots if it has any liquidity
	if position.Liquidity > 0 {
		// 	pool.burn(position.tickLower, position.tickUpper, 0);
		// 	(, bigdec feeGrowthInside0Last, bigdec feeGrowthInside1Last, , ) =
		// 	pool.positions(PositionKey.compute(address(this), position.tickLower, position.tickUpper));
		feeGrowthInside0Last := 0
		feeGrowthInside1Last := 0
		fixedPoint128 = bigint("340282366920938463463374607431768211456")

		tokensOwed0 = feeGrowthInside0Last - position.FeeGrowthInside0Last * position.Liquidity / fixedPoint128
		tokensOwed1 = feeGrowthInside1Last - position.FeeGrowthInside1Last * position.Liquidity / fixedPoint128
		position.FeeGrowthInside0Last = feeGrowthInside0Last
		position.FeeGrowthInside1Last = feeGrowthInside1Last
	}

	// // compute the arguments to give to the pool#collect method
	// (bigdec amount0Collect, bigdec amount1Collect) =
	// 	(
	// 		params.amount0Max > tokensOwed0 ? tokensOwed0 : params.amount0Max,
	// 		params.amount1Max > tokensOwed1 ? tokensOwed1 : params.amount1Max
	// 	);
	amount0Collect := amount0Max
	if amount0Max > tokensOwed0 {
		amount0Collect = tokensOwed0
	}
	amount1Collect := amount1Max
	if amount1Max > tokensOwed1 > 0 {
		amount1Collect = tokensOwed1
	}

	// // the actual amounts collected are returned
	// (amount0, amount1) = pool.collect(
	// 	recipient,
	// 	position.tickLower,
	// 	position.tickUpper,
	// 	amount0Collect,
	// 	amount1Collect
	// );
	amount0 := 0
	amount1 := 0

	// // sometimes there will be a few less wei than expected due to rounding down in core, but we just subtract the full amount expected
	// // instead of the actual amount so we can burn the token
	// (position.tokensOwed0, position.tokensOwed1) = (tokensOwed0 - amount0Collect, tokensOwed1 - amount1Collect);
	position.TokensOwed0 = tokensOwed0.Sub(amount0Collect)
	position.TokensOwed1 = tokensOwed1.Sub(amount1Collect)

	// emit Collect(params.tokenId, recipient, amount0Collect, amount1Collect);
}

func Burn(tokenId string) {
	isAuthorizedForToken(tokenId)
	// Position storage position = _positions[tokenId];
	// require(position.liquidity == 0 && position.tokensOwed0 == 0 && position.tokensOwed1 == 0, 'Not cleared');

	// delete _positions[tokenId];
	positions.Remove(tokenId)

	// _burn(tokenId);
}

func getAndIncrementNonce(tokenId string) bigint {
	position, ok := positions.Get(tokenId)
	if ok {
		parsedPosition := position.(Position)
		oldNonce := parsedPosition.Nonce
		parsedPosition.Nonce = parsedPosition.Nonce + 1
		return oldNonce
	}

	return 0
}

func getApproved(tokenId string) std.Address {
	// require(_exists(tokenId), 'ERC721: approved query for nonexistent token');
	if !Exists(tokenId) {
		panic("GRC721: approved query for nonexistent token")
	}

	// return _positions[tokenId].operator;
	position, _ := Positions(tokenId)
	return position.Operator
}

func approve(to std.Address, tokenId string) {
	// _positions[tokenId].operator = to;
	position, _ := positions.Get(tokenId)
	position.Operator = to
	positions.Set(tokenId, position)

	// emit Approval(ownerOf(tokenId), to, tokenId);
}