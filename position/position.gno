package position

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/gnft"
	"gno.land/r/demo/wugnot"

	u256 "gno.land/p/demo/uint256"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/consts"

	pl "gno.land/r/demo/pool"
)

var (
	positions map[uint64]Position = make(map[uint64]Position) // tokenId -> Position
	nextId    uint64              = 1                         // lp token id
)

// Mint creates a new position and mints liquidity tokens then return minted info
//
// Panics if any of the following conditions are met:
// - caller is not user or staker
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
	mintTo string,
) (uint64, string, string, string) { // tokenId, liquidity, amount0, amount1 ( *u256.Uint x3 )

	if common.GetLimitCaller() {
		// only user or staker can call
		isUserCalled := std.IsOriginCall()
		isStakerCalled := std.PrevRealm().Addr() == consts.STAKER_ADDR
		if !(isUserCalled || isStakerCalled) {
			panic("POSITION] position.gno__Mint() || only user or staker can call")
		}
	}

	// check if wugnot is being minted
	token0IsNative := false
	token1IsNative := false
	if token0 == consts.GNOT {
		token0 = consts.WRAPPED_WUGNOT
		token0IsNative = true
	} else if token1 == consts.GNOT {
		token1 = consts.WRAPPED_WUGNOT
		token1IsNative = true
	}

	if token1 < token0 {
		token0, token1 = token1, token0
		_amount0Desired, _amount1Desired = _amount1Desired, _amount0Desired
		_amount0Min, _amount1Min = _amount1Min, _amount0Min
		tickLower, tickUpper = -tickUpper, -tickLower
		token0IsNative, token1IsNative = token1IsNative, token0IsNative
	}

	amount0Desired := u256.MustFromDecimal(_amount0Desired)
	amount1Desired := u256.MustFromDecimal(_amount1Desired)
	amount0Min := u256.MustFromDecimal(_amount0Min)
	amount1Min := u256.MustFromDecimal(_amount1Min)

	// one of token amount can be 0 if position is out of range
	// check this condition by using DryMint()
	poolPath := ufmt.Sprintf("%s:%s:%d", token0, token1, fee)
	poolCurrentTick := pl.PoolGetSlot0Tick(poolPath)

	estimatedMintAmount0Str, estimatedMintAmount1Str := DryMint(
		poolCurrentTick,
		tickLower,
		tickUpper,
		_amount0Desired,
		_amount1Desired,
	)

	// if estmiated gnot amount is not 0, user should have been sent gnot to position
	ugnotSent := uint64(0)
	if (token0IsNative && estimatedMintAmount0Str != "0") || (token1IsNative && estimatedMintAmount1Str != "0") {
		// SEND GNOT: oneclick -> wugnot
		oldUserWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller()))

		sent := std.GetOrigSend()
		ugnotSent = uint64(sent.AmountOf("ugnot"))

		wrap(ugnotSent)

		newUserWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller()))

		if (newUserWugnotBalance - oldUserWugnotBalance) != ugnotSent {
			panic(ufmt.Sprintf("[POSITION] position.gno__Mint() || wugnot sent(%d) != wugnot received(%d)", ugnotSent, newUserWugnotBalance-oldUserWugnotBalance))
		}
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
		mintTo:         std.Address(mintTo),
	}

	tokenId, liquidity, amount0, amount1 := mint(mintParams)

	spendWugnot := uint64(0)
	if token0IsNative {
		spendWugnot = amount0.Uint64()
	} else if token1IsNative {
		spendWugnot = amount1.Uint64()
	}

	if token0IsNative || token1IsNative {
		leftOver := uint64(ugnotSent - spendWugnot)
		if leftOver > 0 {
			unwrap(leftOver)
		}
	}

	return tokenId, liquidity.ToString(), amount0.ToString(), amount1.ToString()
}

func mint(params MintParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint) {
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
	gnft.Mint(a2u(params.mintTo), tid(tokenId)) // owner, tokenId
	nextId++

	positionKey := positionKeyCompute(GetOrigPkgAddr(), params.tickLower, params.tickUpper)
	_feeGrowthInside0LastX128, _feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)
	feeGrowthInside0LastX128 := u256.MustFromDecimal(_feeGrowthInside0LastX128.ToString())
	feeGrowthInside1LastX128 := u256.MustFromDecimal(_feeGrowthInside1LastX128.ToString())

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

	return tokenId, liquidity, amount0, amount1
}

// IncreaseLiquidity increases liquidity of the existing position
//
// Panics if any of the following conditions are met:
// - position doesn't exist
// - caller is not owner of the position
// - deadline is passed
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

	tokneId, liquidity, amount0, amount1 := increaseLiquidity(increaseLiquidityParams)
	return tokenId, liquidity.ToString(), amount0.ToString(), amount1.ToString()
}

func increaseLiquidity(params IncreaseLiquidityParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint) {
	// verify tokenId exists
	if !exists(params.tokenId) {
		panic(ufmt.Sprintf("[POSITION] position.gno__increaseLiquidity() || tokenId(%d) doesn't exist", params.tokenId))
	}

	// MUST BE OWNER TO INCREASE LIQUIDITY
	// can not be approved address > staked position can't be modified
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
	_feeGrowthInside0LastX128, _feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)
	feeGrowthInside0LastX128 := u256.MustFromDecimal(_feeGrowthInside0LastX128.ToString())
	feeGrowthInside1LastX128 := u256.MustFromDecimal(_feeGrowthInside1LastX128.ToString())

	{
		value1 := new(u256.Uint).Sub(feeGrowthInside0LastX128, position.feeGrowthInside0LastX128)
		value2 := new(u256.Uint).Mul(value1, position.liquidity)
		value3 := new(u256.Uint).Div(value2, u256.MustFromDecimal(consts.Q128))
		position.tokensOwed0 = new(u256.Uint).Add(position.tokensOwed0, value3)
	}

	{
		value1 := new(u256.Uint).Sub(feeGrowthInside1LastX128, position.feeGrowthInside1LastX128)
		value2 := new(u256.Uint).Mul(value1, position.liquidity)
		value3 := new(u256.Uint).Div(value2, u256.MustFromDecimal(consts.Q128))
		position.tokensOwed1 = new(u256.Uint).Add(position.tokensOwed1, value3)
	}

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
	position.liquidity = new(u256.Uint).Add(position.liquidity, liquidity)

	positions[params.tokenId] = position

	return params.tokenId, liquidity, amount0, amount1
}

// DecreaseLiquidity decreases liquidity of the existing position
//
// Panics if any of the following conditions are met:
// - position doesn't exist
// - caller is not owner of the position
// - liquidityRatio is not in range 1 ~ 100
// - deadline is passed
func DecreaseLiquidity(
	tokenId uint64,
	liquidityRatio uint64,
	_amount0Min string, // uint256
	_amount1Min string, // uint256
	deadline int64,
	unwrapResult bool,
) (uint64, string, string, string, string, string, string) { // tokenId, liquidity, fee0, fee1, amount0, amount1, poolPath

	isNormalRange := liquidityRatio >= 1 && liquidityRatio <= 100
	if !isNormalRange {
		panic(ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || liquidityRatio(%d) should be in range 1 ~ 100", liquidityRatio))
	}

	amount0Min := u256.MustFromDecimal(_amount0Min)
	amount1Min := u256.MustFromDecimal(_amount1Min)
	decreaseLiquidityParams := DecreaseLiquidityParams{
		tokenId:        tokenId,
		liquidityRatio: liquidityRatio,
		amount0Min:     amount0Min,
		amount1Min:     amount1Min,
		deadline:       deadline,
		unwrapResult:   unwrapResult,
	}

	tokenId, liquidity, fee0, fee1, amount0, amount1, poolPath := decreaseLiquidity(decreaseLiquidityParams)

	return tokenId, liquidity.ToString(), fee0.ToString(), fee1.ToString(), amount0.ToString(), amount1.ToString(), poolPath
}

func decreaseLiquidity(params DecreaseLiquidityParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint, string) {
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

	// BEFORE DECREASE LIQUIDITY, COLLECT FEE FIRST
	_, fee0Str, fee1Str, _ := CollectFee(params.tokenId)
	fee0 := u256.MustFromDecimal(fee0Str)
	fee1 := u256.MustFromDecimal(fee1Str)

	position := positions[params.tokenId]

	positionLiquidity := position.liquidity
	liquidityToRemove := new(u256.Uint).Mul(positionLiquidity, u256.NewUint(params.liquidityRatio))
	liquidityToRemove = new(u256.Uint).Div(liquidityToRemove, u256.NewUint(100))

	if positionLiquidity.Lt(liquidityToRemove) || params.liquidityRatio == 100 {
		liquidityToRemove = positionLiquidity
	}

	pToken0, pToken1, pFee := poolKeyDivide(position.poolKey)
	pool := pl.GetPoolFromPoolPath(position.poolKey)

	// BURN HERE
	_burnedAmount0, _burnedAmount1 := pl.Burn(pToken0, pToken1, pFee, position.tickLower, position.tickUpper, liquidityToRemove.ToString())

	burnedAmount0 := u256.MustFromDecimal(_burnedAmount0)
	burnedAmount1 := u256.MustFromDecimal(_burnedAmount1)

	cond0 := burnedAmount0.Gte(params.amount0Min)
	cond1 := burnedAmount1.Gte(params.amount1Min)
	if !(cond0 && cond1) {
		panic(ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || burnedAmount0(%s) >= amount0Min(%s) && burnedAmount1(%s) >= amount1Min(%s)", burnedAmount0.ToString(), params.amount0Min.ToString(), burnedAmount1.ToString(), params.amount1Min.ToString()))
	}

	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	_feeGrowthInside0LastX128, _feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)
	feeGrowthInside0LastX128 := u256.MustFromDecimal(_feeGrowthInside0LastX128.ToString())
	feeGrowthInside1LastX128 := u256.MustFromDecimal(_feeGrowthInside1LastX128.ToString())

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

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
	position.liquidity = new(u256.Uint).Sub(positionLiquidity, liquidityToRemove)
	positions[params.tokenId] = position

	// GIVE BACK TO USER
	_amount0, _amount1 := pl.Collect(
		pToken0,
		pToken1,
		pFee,
		std.GetOrigCaller().String(),
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

	if !params.unwrapResult {
		return params.tokenId, liquidityToRemove, fee0, fee1, amount0, amount1, position.poolKey
	}

	var (
		unwrapAmount uint64
		unwrapFee    uint64
	)
	switch {
	case pToken0 == consts.WRAPPED_WUGNOT:
		unwrapAmount = amount0.Uint64()
		unwrapFee = fee0.Uint64()
	case pToken1 == consts.WRAPPED_WUGNOT:
		unwrapAmount = amount1.Uint64()
		unwrapFee = fee1.Uint64()
	}
	unwrap(unwrapAmount)
	unwrap(unwrapFee)

	return params.tokenId, liquidityToRemove, fee0, fee1, amount0, amount1, position.poolKey
}

// CollectFee collects swap fee from the position
//
// Panics if any of the following conditions are met:
// - position doesn't exist
// - caller is not owner or approved
func CollectFee(tokenId uint64) (uint64, string, string, string) { // tokenId, tokensOwed0, tokensOwed1, poolPath
	// verify tokenId
	if !exists(tokenId) {
		panic(ufmt.Sprintf("[POSITION] position.gno__CollectFee() || tokenId(%d) doesn't exist", tokenId))
	}

	// verify owner or approved
	isAuthorizedForToken(tokenId)

	// verify position
	position, exist := positions[tokenId]
	if !exist {
		panic(ufmt.Sprintf("[POSITION] position.gno__CollectFee() || position(tokenId:%d) doesn't exist", tokenId))
	}

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
	_feeGrowthInside0LastX128, _feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)
	feeGrowthInside0LastX128 := u256.MustFromDecimal(_feeGrowthInside0LastX128.ToString())
	feeGrowthInside1LastX128 := u256.MustFromDecimal(_feeGrowthInside1LastX128.ToString())

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
		std.GetOrigCaller().String(),
		position.tickLower,
		position.tickUpper,
		consts.MAX_UINT64,
		consts.MAX_UINT64,
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
