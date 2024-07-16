package position

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/gnft"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/consts"

	en "gno.land/r/gnoswap/emission"
	pl "gno.land/r/gnoswap/pool"
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
	en.MintAndDistributeGns()

	if common.GetLimitCaller() {
		// only user or staker can call
		isUserCalled := std.IsOriginCall()
		isStakerCalled := std.PrevRealm().Addr() == consts.STAKER_ADDR
		if !(isUserCalled || isStakerCalled) {
			panic("POSITION] position.gno__Mint() || only user or staker can call")
		}
	}

	// check if native ugnot is being minted
	token0IsNative := false
	token1IsNative := false
	if token0 == consts.GNOT {
		token0 = consts.WRAPPED_WUGNOT
		token0IsNative = true
	} else if token1 == consts.GNOT {
		token1 = consts.WRAPPED_WUGNOT
		token1IsNative = true
	}
	userWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller()))

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

	if token0IsNative || token1IsNative {
		// SEND GNOT: position -> wugnot
		oldUserWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller()))

		sent := std.GetOrigSend()
		ugnotSent := uint64(sent.AmountOf("ugnot"))
		if ugnotSent > 0 {
			wrap(ugnotSent)

			newUserWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller()))
			if (newUserWugnotBalance - oldUserWugnotBalance) != ugnotSent {
				panic(ufmt.Sprintf("[POSITION] position.gno__Mint() || wugnot sent(%d) != wugnot received(%d)", ugnotSent, newUserWugnotBalance-oldUserWugnotBalance))
			}
		} else {
			// no ugnot sent
			// can be happen depending on current position range
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

	if token0IsNative || token1IsNative {
		// if this is larger than before mint, unwrap rest
		userWugnotAfterMint := wugnot.BalanceOf(a2u(std.GetOrigCaller()))
		leftOver := userWugnotAfterMint - userWugnotBalance
		if leftOver > 0 {
			unwrap(leftOver)
		}
	}

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_tickLower", int32ToStr(tickLower),
		"p_tickUpper", int32ToStr(tickUpper),
		"poolPath", poolPath,
		"tokenId", uint64ToStr(tokenId),
		"liquidity", liquidity.ToString(),
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
	)

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
		operator:                 std.GetOrigCaller(),
		poolKey:                  pl.GetPoolPath(params.token0, params.token1, params.fee),
		tickLower:                params.tickLower,
		tickUpper:                params.tickUpper,
		liquidity:                liquidity,
		feeGrowthInside0LastX128: feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: feeGrowthInside1LastX128,
		tokensOwed0:              u256.Zero(),
		tokensOwed1:              u256.Zero(),
		burned:                   false,
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
) (uint64, string, string, string, string) { // tokenId, liquidity, amount0, amount1, poolPath
	en.MintAndDistributeGns()

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

	// wrap if target pool has wugnot
	position := positions[tokenId]
	pToken0, pToken1, _ := poolKeyDivide(position.poolKey)

	isToken0Wugnot := pToken0 == consts.WRAPPED_WUGNOT
	isToken1Wugnot := pToken1 == consts.WRAPPED_WUGNOT

	userOldWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller())) // before wrap, user's origin wugnot balance
	if isToken0Wugnot || isToken1Wugnot {
		sent := std.GetOrigSend()
		ugnotSent := uint64(sent.AmountOf("ugnot"))
		wrap(ugnotSent)
	}

	// INCREASE
	_, liquidity, amount0, amount1, poolPath := increaseLiquidity(increaseLiquidityParams)

	// unwrap left
	if isToken0Wugnot || isToken1Wugnot {
		userNewWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller()))

		leftOver := userNewWugnotBalance - userOldWugnotBalance
		unwrap(leftOver)
	}

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_tokenId", uint64ToStr(tokenId),
		"poolPath", poolPath,
		"liquidity", liquidity.ToString(),
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
	)

	return tokenId, liquidity.ToString(), amount0.ToString(), amount1.ToString(), poolPath
}

func increaseLiquidity(params IncreaseLiquidityParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint, string) {
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
		diff := new(u256.Uint).Sub(feeGrowthInside0LastX128, position.feeGrowthInside0LastX128)
		mulDiv := u256.MulDiv(diff, position.liquidity, u256.MustFromDecimal(consts.Q128))

		position.tokensOwed0 = new(u256.Uint).Add(position.tokensOwed0, mulDiv)
	}

	{
		diff := new(u256.Uint).Sub(feeGrowthInside1LastX128, position.feeGrowthInside1LastX128)
		mulDiv := u256.MulDiv(diff, position.liquidity, u256.MustFromDecimal(consts.Q128))

		position.tokensOwed1 = new(u256.Uint).Add(position.tokensOwed1, mulDiv)
	}

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
	position.liquidity = new(u256.Uint).Add(position.liquidity, liquidity)
	position.burned = false

	positions[params.tokenId] = position

	return params.tokenId, liquidity, amount0, amount1, position.poolKey
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
	en.MintAndDistributeGns()

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

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_tokenId", uint64ToStr(tokenId),
		"p_liquidityRatio", uint64ToStr(liquidityRatio),
		"poolPath", poolPath,
		"liquidity", liquidity.ToString(),
		"fee0", fee0.ToString(),
		"fee1", fee1.ToString(),
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
	)

	return tokenId, liquidity.ToString(), fee0.ToString(), fee1.ToString(), amount0.ToString(), amount1.ToString(), poolPath
}

func decreaseLiquidity(params DecreaseLiquidityParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint, string) {
	userOldWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller())) // before unwrap

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
		diff := new(u256.Uint).Sub(feeGrowthInside0LastX128, position.feeGrowthInside0LastX128)
		mulDiv := u256.MulDiv(diff, position.liquidity, u256.MustFromDecimal(consts.Q128))
		add := new(u256.Uint).Add(burnedAmount0, mulDiv)

		position.tokensOwed0 = new(u256.Uint).Add(position.tokensOwed0, add)
	}

	{
		diff := new(u256.Uint).Sub(feeGrowthInside1LastX128, position.feeGrowthInside1LastX128)
		mulDiv := u256.MulDiv(diff, position.liquidity, u256.MustFromDecimal(consts.Q128))
		add := new(u256.Uint).Add(burnedAmount1, mulDiv)

		position.tokensOwed1 = new(u256.Uint).Add(position.tokensOwed1, add)
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

	// NO UNWRAP
	if !params.unwrapResult {
		return params.tokenId, liquidityToRemove, fee0, fee1, amount0, amount1, position.poolKey
	}

	if (pToken0 == consts.WRAPPED_WUGNOT || pToken1 == consts.WRAPPED_WUGNOT) && params.unwrapResult {
		userNewWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller()))

		leftOver := userNewWugnotBalance - userOldWugnotBalance
		unwrap(leftOver)
	}

	return params.tokenId, liquidityToRemove, fee0, fee1, amount0, amount1, position.poolKey
}

func Reposition(
	tokenId uint64,
	tickLower int32,
	tickUpper int32,
	_amount0Desired string, // uint256
	_amount1Desired string, // uint256
) (uint64, string, int32, int32, string, string) { // tokenId, liquidity, tickLower, tickUpper, amount0, amount1
	en.MintAndDistributeGns()

	// verify tokenId exists
	if !exists(tokenId) {
		panic(ufmt.Sprintf("[POSITION] position.gno__Reposition() || tokenId(%d) doesn't exist", tokenId))
	}

	// MUST BE OWNER TO REPOSITION
	// can not be approved address > staked position can't be modified
	owner := gnft.OwnerOf(tid(tokenId))
	if owner != std.GetOrigCaller() {
		panic(ufmt.Sprintf("[POSITION] position.gno__Reposition() || only owner can reposition__owner(%s) == std.GetOrigCaller(%s)", owner, std.GetOrigCaller()))
	}

	// position should be burned to reposition
	position := positions[tokenId]
	oldTickLower := position.tickLower
	oldTickUpper := position.tickUpper

	if !(position.isClear()) {
		panic(ufmt.Sprintf("[POSITION] position.gno__Reposition() || position(tokenId:%d) isn't clear(liquidity:%d, tokensOwed0:%d, tokensOwed1:%d)", tokenId, position.liquidity, position.tokensOwed0, position.tokensOwed1))
	}

	token0, token1, _ := poolKeyDivide(position.poolKey)
	// check if gnot pool
	token0IsNative := false
	token1IsNative := false
	if token0 == consts.WRAPPED_WUGNOT {
		token0IsNative = true
	} else if token1 == consts.WRAPPED_WUGNOT {
		token1IsNative = true
	}

	ugnotSent := uint64(0)
	if token0IsNative || token1IsNative {
		// WRAP IT
		sent := std.GetOrigSend()
		ugnotSent = uint64(sent.AmountOf("ugnot"))

		wrap(ugnotSent)
	}

	liquidity, amount0, amount1 := addLiquidity(
		AddLiquidityParams{
			poolKey:        position.poolKey,
			tickLower:      tickLower,
			tickUpper:      tickUpper,
			amount0Desired: u256.MustFromDecimal(_amount0Desired),
			amount1Desired: u256.MustFromDecimal(_amount1Desired),
			amount0Min:     u256.Zero(),
			amount1Min:     u256.Zero(),
		},
	)

	pool := pl.GetPoolFromPoolPath(position.poolKey)
	positionKey := positionKeyCompute(GetOrigPkgAddr(), tickLower, tickUpper)
	_feeGrowthInside0LastX128, _feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)
	feeGrowthInside0LastX128 := u256.MustFromDecimal(_feeGrowthInside0LastX128.ToString())
	feeGrowthInside1LastX128 := u256.MustFromDecimal(_feeGrowthInside1LastX128.ToString())

	position.tickLower = tickLower
	position.tickUpper = tickUpper
	position.liquidity = liquidity
	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
	position.tokensOwed0 = u256.Zero()
	position.tokensOwed1 = u256.Zero()
	position.burned = false

	positions[tokenId] = position

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_tickLower", int32ToStr(tickLower),
		"p_tickUpper", int32ToStr(tickUpper),
		"p_tokenId", uint64ToStr(tokenId),
		"poolPath", position.poolKey,
		"liquidity", liquidity.ToString(),
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
		"old_tickLower", int32ToStr(oldTickLower),
		"old_tickUpper", int32ToStr(oldTickUpper),
	)

	return tokenId, liquidity.ToString(), tickLower, tickUpper, amount0.ToString(), amount1.ToString()
}

// CollectFee collects swap fee from the position
//
// Panics if any of the following conditions are met:
// - position doesn't exist
// - caller is not owner or approved
func CollectFee(tokenId uint64) (uint64, string, string, string) { // tokenId, tokensOwed0, tokensOwed1, poolPath
	en.MintAndDistributeGns()

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
		diff := new(u256.Uint).Sub(feeGrowthInside0LastX128, position.feeGrowthInside0LastX128)
		mulDiv := u256.MulDiv(diff, position.liquidity, u256.MustFromDecimal(consts.Q128))

		tokensOwed0 = new(u256.Uint).Add(tokensOwed0, mulDiv)
	}

	{
		diff := new(u256.Uint).Sub(feeGrowthInside1LastX128, position.feeGrowthInside1LastX128)
		mulDiv := u256.MulDiv(diff, position.liquidity, u256.MustFromDecimal(consts.Q128))

		tokensOwed1 = new(u256.Uint).Add(tokensOwed1, mulDiv)
	}

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128

	// check user wugnot amount
	// need this value to unwrap fee
	userWugnot := wugnot.BalanceOf(a2u(std.GetOrigCaller()))

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

	positions[tokenId] = position

	// handle withdrawal fee
	withoutFee0, withoutFee1 := pl.HandleWithdrawalFee(tokenId, token0, amount0, token1, amount1)

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_tokenId", uint64ToStr(tokenId),
		"fee0", withoutFee0,
		"fee1", withoutFee1,
		"poolPath", position.poolKey,
	)

	// UNWRAP
	pToken0, pToken1, _ := poolKeyDivide(position.poolKey)
	if pToken0 == consts.WUGNOT_PATH || pToken1 == consts.WUGNOT_PATH {
		userNewWugnot := wugnot.BalanceOf(a2u(std.GetOrigCaller()))
		unwrapAmount := userNewWugnot - userWugnot

		if unwrapAmount > 0 {
			unwrap(unwrapAmount)
		}
	}

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
