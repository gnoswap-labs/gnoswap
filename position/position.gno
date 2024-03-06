package position

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/gnft"

	u256 "gno.land/p/big/uint256"

	"gno.land/r/demo/consts"

	pl "gno.land/r/demo/pool"
)

var (
	positions map[uint64]Position = make(map[uint64]Position) // tokenId -> Position
	nextId    uint64              = 1
)

func Mint(
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	_amount0Desired string, // *u256.Uint
	_amount1Desired string, // *u256.Uint
	_amount0Min string, // *u256.Uint
	_amount1Min string, // *u256.Uint
	deadline int64,
) (uint64, string, string, string) { // tokenId, liquidity, amount0, amount1 ( *u256.Uint x3 )
	if token1 < token0 {
		token0, token1 = token1, token0
		_amount0Desired, _amount1Desired = _amount1Desired, _amount0Desired
		_amount0Min, _amount1Min = _amount1Min, _amount0Min
		tickLower, tickUpper = -tickUpper, -tickLower
	}

	amount0Desired := u256.MustFromDecimal(_amount0Desired)
	amount1Desired := u256.MustFromDecimal(_amount1Desired)
	amount0Min := u256.MustFromDecimal(_amount0Min)
	amount1Min := u256.MustFromDecimal(_amount1Min)

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

func mint(params MintParams) (uint64, string, string, string) {
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
	println("amount0", amount0.ToString())
	println("amount1", amount1.ToString())
	panic("FIX 0")

	tokenId := nextId
	nextId++

	gnft.Mint(a2u(std.GetOrigCaller()), tid(tokenId)) // owner, tokenId

	positionKey := positionKeyCompute(GetOrigPkgAddr(), params.tickLower, params.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)

	position := Position{
		nonce:                    u256.Zero(),
		operator:                 std.PrevRealm().Addr(),
		poolKey:                  pl.GetPoolPath(params.token0, params.token1, params.fee),
		tickLower:                params.tickLower,
		tickUpper:                params.tickUpper,
		liquidity:                liquidity,
		feeGrowthInside0LastX128: feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: feeGrowthInside1LastX128,
		tokensOwed0:              u256.Zero(),
		tokensOwed1:              u256.Zero(),
	}
	positions[tokenId] = position

	return tokenId, liquidity.ToString(), amount0.ToString(), amount1.ToString()
}

func IncreaseLiquidity(
	tokenId uint64,
	_amount0Desired string, // uint256
	_amount1Desired string, // uint256
	_amount0Min string, // uint256
	_amount1Min string, // uint256
	deadline int64,
) (uint64, string, string, string) { // tokenId, liquidity, amount0, amount1

	amount0Desired := u256.MustFromDecimal(_amount0Desired)
	amount1Desired := u256.MustFromDecimal(_amount1Desired)
	amount0Min := u256.MustFromDecimal(_amount0Min)
	amount1Min := u256.MustFromDecimal(_amount1Min)

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

func increaseLiquidity(params IncreaseLiquidityParams) (uint64, string, string, string) {
	// verify tokenId exists
	if !exists(params.tokenId) {
		panic(ufmt.Sprintf("[POSITION] position.gno__increaseLiquidity() || tokenId(%d) doesn't exist", params.tokenId))
	}

	// MUST BE OWNER TO INCREASE LIQUIDITY
	// can not be approved address > staked position can be modified
	owner := gnft.OwnerOf(tid(params.tokenId))
	if owner != std.GetOrigCaller() {
		panic(ufmt.Sprintf("[POSITION] position.gno__increaseLiquidity() || only owner can increase liquidity__owner(%s) == std.GetOrigCaller(%s)", owner, std.GetOrigCaller()))
	}

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

	{
		value1 := new(u256.Uint).Sub(feeGrowthInside0LastX128.Clone(), position.feeGrowthInside0LastX128.Clone())
		value2 := new(u256.Uint).Mul(value1, position.liquidity)
		value3 := new(u256.Uint).Div(value2, u256.MustFromDecimal(consts.Q128))
		position.tokensOwed0 = new(u256.Uint).Add(position.tokensOwed0, value3)
	}

	{
		value1 := new(u256.Uint).Sub(feeGrowthInside1LastX128.Clone(), position.feeGrowthInside1LastX128.Clone())
		value2 := new(u256.Uint).Mul(value1, position.liquidity)
		value3 := new(u256.Uint).Div(value2, u256.MustFromDecimal(consts.Q128))
		position.tokensOwed1 = new(u256.Uint).Add(position.tokensOwed1, value3)
	}

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
	position.liquidity = new(u256.Uint).Add(position.liquidity, liquidity)

	positions[params.tokenId] = position

	return params.tokenId, liquidity.ToString(), amount0.ToString(), amount1.ToString()
}

// *IMPORTANT*
// DecreaseLiquidity() will return DECREASED amonut0, amount1
// HOWEVER, internally it also execute CollectFee() to collect fee which DOES NOT INCLUDE IN RETURN VALUE
func DecreaseLiquidity(
	tokenId uint64,
	_liquidity string, // uint128
	_amount0Min string, // uint256
	_amount1Min string, // uint256
	deadline int64,
) (uint64, string, string, string, string) { // tokenId, liquidity, amount0, amount1, poolPath
	liquidity := u256.MustFromDecimal(_liquidity)
	amount0Min := u256.MustFromDecimal(_amount0Min)
	amount1Min := u256.MustFromDecimal(_amount1Min)

	decreaseLiquidityParams := DecreaseLiquidityParams{
		tokenId:    tokenId,
		liquidity:  liquidity,
		amount0Min: amount0Min,
		amount1Min: amount1Min,
		deadline:   deadline,
	}

	return decreaseLiquidity(decreaseLiquidityParams)
}

func decreaseLiquidity(params DecreaseLiquidityParams) (uint64, string, string, string, string) {
	// verify tokenId
	if !exists(params.tokenId) {
		panic(ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || tokenId(%d) doesn't exist", params.tokenId))
	}

	// MUST BE OWNER TO DECREASE LIQUIDITY ( can not be approved address )
	owner := gnft.OwnerOf(tid(params.tokenId))
	if owner != std.GetOrigCaller() {
		panic(ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || only owner can decrease liquidity__owner(%s) == std.GetOrigCaller(%s)", owner, std.GetOrigCaller()))
	}

	checkDeadline(params.deadline)

	if params.liquidity.Lt(u256.Zero()) {
		panic(ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || liquidity(%d) >= 0", params.liquidity))
	}

	// BEFORE DECREASE LIQUIDITY, COLLECT FEE FIRST
	CollectFee(params.tokenId)

	position := positions[params.tokenId]

	positionLiquidity := position.liquidity
	if positionLiquidity.Lt(params.liquidity) {
		// if too many liquidity requested, decrease to entire liquidity
		params.liquidity = positionLiquidity
	}

	pToken0, pToken1, pFee := poolKeyDivide(position.poolKey)
	pool := pl.GetPoolFromPoolPath(position.poolKey)

	// BURN HERE
	_burnedAmount0, _burnedAmount1 := pl.Burn(pToken0, pToken1, pFee, position.tickLower, position.tickUpper, params.liquidity.Clone().ToString())

	burnedAmount0 := u256.MustFromDecimal(_burnedAmount0)
	burnedAmount1 := u256.MustFromDecimal(_burnedAmount1)

	cond0 := burnedAmount0.Gte(params.amount0Min)
	cond1 := burnedAmount1.Gte(params.amount1Min)
	if !(cond0 && cond1) {
		panic(ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || burnedAmount0(%s) >= amount0Min(%s) && burnedAmount1(%s) >= amount1Min(%s)", burnedAmount0.ToString(), params.amount0Min.ToString(), burnedAmount1.ToString(), params.amount1Min.ToString()))
	}

	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)
	{
		value1 := new(u256.Uint).Sub(feeGrowthInside0LastX128, position.feeGrowthInside0LastX128)
		value2 := new(u256.Uint).Mul(value1, position.liquidity)
		value3 := new(u256.Uint).Div(value2, u256.MustFromDecimal(consts.Q128))
		value4 := new(u256.Uint).Add(burnedAmount0, value3)

		position.tokensOwed0 = new(u256.Uint).Add(position.tokensOwed0, value4)
	}

	{
		value1 := new(u256.Uint).Sub(feeGrowthInside1LastX128, position.feeGrowthInside1LastX128)
		value2 := new(u256.Uint).Mul(value1, position.liquidity)
		value3 := new(u256.Uint).Div(value2, u256.MustFromDecimal(consts.Q128))
		value4 := new(u256.Uint).Add(burnedAmount1, value3)

		position.tokensOwed1 = new(u256.Uint).Add(position.tokensOwed1, value4)
	}

	// positions[params.tokenId].feeGrowthInside0LastX128 = feeGrowthInside0LastX128 // r3v4_xxx: panic: unexpected zero object id
	// r3v4_xxx: weird hacky patch
	if feeGrowthInside0LastX128.IsZero() {
		position.feeGrowthInside0LastX128 = u256.Zero()
	} else {
		_cloneMustFromDecimal := u256.MustFromDecimal(feeGrowthInside0LastX128.ToString())
		position.feeGrowthInside0LastX128 = _cloneMustFromDecimal
	}

	if feeGrowthInside1LastX128.IsZero() {
		position.feeGrowthInside1LastX128 = u256.Zero()
	} else {
		_cloneMustFromDecimal := u256.MustFromDecimal(feeGrowthInside1LastX128.ToString())
		position.feeGrowthInside1LastX128 = _cloneMustFromDecimal
	}

	position.liquidity = new(u256.Uint).Sub(positionLiquidity, params.liquidity)
	positions[params.tokenId] = position

	// GIVE BACK TO USER
	_amount0, _amount1 := pl.Collect(
		pToken0,
		pToken1,
		pFee,
		std.GetOrigCaller(),
		position.tickLower,
		position.tickUpper,
		_burnedAmount0,
		_burnedAmount1,
	)
	amount0 := u256.MustFromDecimal(_amount0)
	amount1 := u256.MustFromDecimal(_amount1)

	position.tokensOwed0 = new(u256.Uint).Sub(position.tokensOwed0, amount0)
	position.tokensOwed1 = new(u256.Uint).Sub(position.tokensOwed1, amount1)

	positions[params.tokenId] = position

	if position.isClear() {
		// burnNFT(params.tokenId) // actual burn
		burnPosition(params.tokenId) // just update flag
	}

	return params.tokenId, params.liquidity.ToString(), _amount0, _amount1, position.poolKey
}

func CollectFee(tokenId uint64) (uint64, string, string, string) { // tokenId, tokensOwed0, tokensOwed1, poolPath
	// verify tokenId
	if !exists(tokenId) {
		panic(ufmt.Sprintf("[POSITION] position.gno__CollectFee() || tokenId(%d) doesn't exist", tokenId))
	}

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
		"0", // burn '0' liquidity to collect fee
	)

	tokensOwed0, tokensOwed1 := position.tokensOwed0, position.tokensOwed1

	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	pool := pl.GetPoolFromPoolPath(position.poolKey)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)

	{
		value1 := new(u256.Uint).Sub(feeGrowthInside0LastX128, position.feeGrowthInside0LastX128)
		value2 := new(u256.Uint).Mul(value1, position.liquidity)
		value3 := new(u256.Uint).Div(value2, u256.MustFromDecimal(consts.Q128))
		tokensOwed0 = new(u256.Uint).Add(tokensOwed0, value3)
	}

	{
		value1 := new(u256.Uint).Sub(feeGrowthInside1LastX128, position.feeGrowthInside1LastX128)
		value2 := new(u256.Uint).Mul(value1, position.liquidity)
		value3 := new(u256.Uint).Div(value2, u256.MustFromDecimal(consts.Q128))
		tokensOwed1 = new(u256.Uint).Add(tokensOwed1, value3)
	}

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128

	amount0, amount1 := pl.Collect(
		token0,
		token1,
		fee,
		std.GetOrigCaller(),
		position.tickLower,
		position.tickUpper,
		consts.MAX_UINT64, // string, r3v4_xxx: current grc20 handles amount by `uint64`
		consts.MAX_UINT64, // string, r3v4_xxx: current grc20 handles amount by `uint64`
	)

	amount0Uint := u256.MustFromDecimal(amount0)
	amount1Uint := u256.MustFromDecimal(amount1)

	position.tokensOwed0 = new(u256.Uint).Sub(tokensOwed0, amount0Uint)
	position.tokensOwed1 = new(u256.Uint).Sub(tokensOwed1, amount1Uint)
	positions[tokenId] = position

	// handle withdrawal fee
	withoutFee0, withoutFee1 := pl.HandleWithdrawalFee(tokenId, token0, amount0, token1, amount1)

	return tokenId, withoutFee0, withoutFee1, position.poolKey
}

func burnNFT(tokenId uint64) {
	isAuthorizedForToken(tokenId)

	position := positions[tokenId]

	if !(position.isClear()) {
		panic(ufmt.Sprintf("[POSITION] position.gno__burnNFT() || position(tokenId:%d) isn't clear(liquidity:%d, tokensOwed0:%d, tokensOwed1:%d)", tokenId, position.liquidity, position.tokensOwed0, position.tokensOwed1))
	}
	delete(positions, tokenId)
	gnft.Burn(tid(tokenId))
}

func burnPosition(tokenId uint64) {
	position := positions[tokenId]
	if !(position.isClear()) {
		panic(ufmt.Sprintf("[POSITION] position.gno__burnPosition() || position(tokenId:%d) isn't clear(liquidity:%d, tokensOwed0:%d, tokensOwed1:%d)", tokenId, position.liquidity, position.tokensOwed0, position.tokensOwed1))
	}

	position.burned = true
	positions[tokenId] = position
}

func isAuthorizedForToken(tokenId uint64) {
	if !(isApprovedOrOwner(std.PrevRealm().Addr(), tokenId)) {
		panic(ufmt.Sprintf("[POSITION] position.gno__isAuthorizedForToken() || caller(%s) is not approved or owner of tokenId(%d)", std.PrevRealm().Addr(), tokenId))
	}

}
