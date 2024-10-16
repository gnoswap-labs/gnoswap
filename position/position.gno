package position

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v2/gnft"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	en "gno.land/r/gnoswap/v2/emission"
	pl "gno.land/r/gnoswap/v2/pool"
)

var (
	positions map[uint64]Position = make(map[uint64]Position) // tokenId -> Position
	nextId    uint64              = 1                         // lp token id
)

// Mint creates a new liquidity position and mints liquidity tokens.
//
// This function allows users to provide liquidity to a pool by specifying the token pair,
// fee tier, price range (via ticks), and desired token amounts. It handles both GRC20 tokens
// and native GNOT (which is wrapped to WUGNOT internally).
//
// Panics:
//   - If the caller is not authorized (when caller limitation is enabled).
//   - If there's a mismatch between sent and received WUGNOT amounts.
//   - If the minting operation fails or returns unexpected results.
//
// Note: This function automatically sorts the token pair if they are provided in the wrong order.
// It also handles the conversion between GNOT and WUGNOT transparently for the user.
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
	mintTo std.Address,
	caller std.Address,
) (uint64, string, string, string) { // tokenId, liquidity, amount0, amount1 ( *u256.Uint x3 )
	common.IsHalted()
	en.MintAndDistributeGns()

	if common.GetLimitCaller() {
		// only user or staker can call
		isUserCalled := std.PrevRealm().PkgPath() == ""
		isStakerCalled := std.PrevRealm().Addr() == consts.STAKER_ADDR
		if !(isUserCalled || isStakerCalled) {
			panic("POSITION] position.gno__Mint() || only user or staker can call")
		}
	}

	token0, token1, token0IsNative, token1IsNative := processTokens(token0, token1)
	userWugnotBalance := wugnot.BalanceOf(a2u(caller))

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

	handleNativeToken(token0IsNative, token1IsNative, caller)

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
		mintTo:         mintTo,
		caller:         caller,
	}

	tokenId, liquidity, amount0, amount1 := mint(mintParams)

	handleLeftoverNativeToken(token0IsNative, token1IsNative, userWugnotBalance, caller)

	poolSqrtPriceX96 := pl.PoolGetSqrtPriceX96(poolPath)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"Mint",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"tickLower", ufmt.Sprintf("%d", tickLower),
		"tickUpper", ufmt.Sprintf("%d", tickUpper),
		"poolPath", poolPath,
		"internal_lpTokenId", ufmt.Sprintf("%d", tokenId),
		"internal_liquidity", liquidity.ToString(),
		"internal_amount0", amount0.ToString(),
		"internal_amount1", amount1.ToString(),
		"internal_sqrtPriceX96", poolSqrtPriceX96.ToString(),
	)

	return tokenId, liquidity.ToString(), amount0.ToString(), amount1.ToString()
}

func processTokens(token0, token1 string) (string, string, bool, bool) {
	token0IsNative := false
	token1IsNative := false
	if token0 == consts.GNOT {
		token0 = consts.WRAPPED_WUGNOT
		token0IsNative = true
	} else if token1 == consts.GNOT {
		token1 = consts.WRAPPED_WUGNOT
		token1IsNative = true
	}
	return token0, token1, token0IsNative, token1IsNative
}

func handleNativeToken(token0IsNative, token1IsNative bool, caller std.Address) {
	if token0IsNative || token1IsNative {
		oldUserWugnotBalance := wugnot.BalanceOf(a2u(caller))
		sent := std.GetOrigSend()
		ugnotSent := uint64(sent.AmountOf("ugnot"))
		if ugnotSent > 0 {
			wrap(ugnotSent, caller)
			newUserWugnotBalance := wugnot.BalanceOf(a2u(caller))
			if (newUserWugnotBalance - oldUserWugnotBalance) != ugnotSent {
				panic(ufmt.Sprintf("[POSITION] position.gno__Mint() || ugnot sent(%d) != ugnot received(%d)", ugnotSent, newUserWugnotBalance-oldUserWugnotBalance))
			}
		}
	}
}

func handleLeftoverNativeToken(token0IsNative, token1IsNative bool, userWugnotBalance uint64, caller std.Address) {
	if token0IsNative || token1IsNative {
		userWugnotAfterMint := wugnot.BalanceOf(a2u(caller))
		leftOver := userWugnotAfterMint - userWugnotBalance
		if leftOver > 0 {
			unwrap(leftOver, caller)
		}
	}
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
			caller:         params.caller,
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
		operator:                 params.caller,
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
	common.IsHalted()
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

	userOldWugnotBalance := wugnot.BalanceOf(a2u(std.PrevRealm().Addr())) // before wrap, user's origin wugnot balance
	if isToken0Wugnot || isToken1Wugnot {
		sent := std.GetOrigSend()
		ugnotSent := uint64(sent.AmountOf("ugnot"))
		wrap(ugnotSent, std.PrevRealm().Addr())
	}

	// INCREASE
	_, liquidity, amount0, amount1, poolPath := increaseLiquidity(increaseLiquidityParams)

	// unwrap left
	if isToken0Wugnot || isToken1Wugnot {
		userNewWugnotBalance := wugnot.BalanceOf(a2u(std.PrevRealm().Addr()))

		leftOver := userNewWugnotBalance - userOldWugnotBalance
		unwrap(leftOver, std.PrevRealm().Addr())
	}

	poolSqrtPriceX96 := pl.PoolGetSqrtPriceX96(poolPath)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"IncreaseLiquidity",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"internal_poolPath", poolPath,
		"internal_liquidity", liquidity.ToString(),
		"internal_amount0", amount0.ToString(),
		"internal_amount1", amount1.ToString(),
		"internal_sqrtPriceX96", poolSqrtPriceX96.ToString(),
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
	if owner != std.PrevRealm().Addr() {
		panic(ufmt.Sprintf("[POSITION] position.gno__increaseLiquidity() || only owner can increase liquidity__owner(%s) == std.PrevRealm().Addr()(%s)", owner, std.PrevRealm().Addr()))
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
			caller:         std.PrevRealm().Addr(),
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
// - position has 0 liquidity
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
	common.IsHalted()
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

	poolSqrtPriceX96 := pl.PoolGetSqrtPriceX96(poolPath)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"DecreaseLiquidity",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"liquidityRatio", ufmt.Sprintf("%d", liquidityRatio),
		"internal_poolPath", poolPath,
		"internal_liquidity", liquidity.ToString(),
		"internal_fee0", fee0.ToString(),
		"internal_fee1", fee1.ToString(),
		"internal_amount0", amount0.ToString(),
		"internal_amount1", amount1.ToString(),
		"internal_unwrapResult", ufmt.Sprintf("%t", unwrapResult),
		"internal_sqrtPriceX96", poolSqrtPriceX96.ToString(),
	)

	return tokenId, liquidity.ToString(), fee0.ToString(), fee1.ToString(), amount0.ToString(), amount1.ToString(), poolPath
}

// decreaseLiquidity reduces the liquidity of a given position and collects the corresponding tokens.
//
// Panics:
//   - If the token ID doesn't exist.
//   - If the position has already been burned.
//   - If the caller is not the owner of the position.
//   - If the deadline has passed.
//   - If the received amounts are less than the specified minimums.
//
// Note: This function handles both GRC20 tokens and native GNOT (wrapped as WUGNOT).
// If unwrapResult is true and the position involves WUGNOT, any leftover WUGNOT will be
// unwrapped to GNOT at the end of the operation.
func decreaseLiquidity(params DecreaseLiquidityParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint, string) {
	userOldWugnotBalance := wugnot.BalanceOf(a2u(std.PrevRealm().Addr())) // before unwrap

	verifyTokenIdAndOwnership(params.tokenId)
	checkDeadline(params.deadline)

	// BEFORE DECREASE LIQUIDITY, COLLECT FEE FIRST
	_, fee0Str, fee1Str, _, _, _ := CollectFee(params.tokenId, params.unwrapResult)
	fee0 := u256.MustFromDecimal(fee0Str)
	fee1 := u256.MustFromDecimal(fee1Str)

	position := positions[params.tokenId]
	positionLiquidity := position.liquidity

	if positionLiquidity.IsZero() {
		panic(ufmt.Sprintf("[POSITION] position.gno__decreaseLiquidity() || position(tokenId:%d) has 0 liquidity", params.tokenId))
	}

	liquidityToRemove := calculateLiquidityToRemove(positionLiquidity, params.liquidityRatio)

	pToken0, pToken1, pFee := poolKeyDivide(position.poolKey)
	pool := pl.GetPoolFromPoolPath(position.poolKey)

	// BURN HERE
	_burnedAmount0, _burnedAmount1 := pl.Burn(pToken0, pToken1, pFee, position.tickLower, position.tickUpper, liquidityToRemove.ToString())

	burnedAmount0 := u256.MustFromDecimal(_burnedAmount0)
	burnedAmount1 := u256.MustFromDecimal(_burnedAmount1)

	verifyBurnedAmounts(burnedAmount0, burnedAmount1, params.amount0Min, params.amount1Min)

	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	_feeGrowthInside0LastX128, _feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)
	feeGrowthInside0LastX128 := u256.MustFromDecimal(_feeGrowthInside0LastX128.ToString())
	feeGrowthInside1LastX128 := u256.MustFromDecimal(_feeGrowthInside1LastX128.ToString())

	position.tokensOwed0 = updateTokensOwed(
		feeGrowthInside0LastX128,
		position.feeGrowthInside0LastX128,
		position.liquidity,
		burnedAmount0,
		position.tokensOwed0,
	)

	position.tokensOwed1 = updateTokensOwed(
		feeGrowthInside1LastX128,
		position.feeGrowthInside1LastX128,
		position.liquidity,
		burnedAmount1,
		position.tokensOwed1,
	)

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
	position.liquidity = new(u256.Uint).Sub(positionLiquidity, liquidityToRemove)
	positions[params.tokenId] = position

	// GIVE BACK TO USER
	_amount0, _amount1 := pl.Collect(
		pToken0,
		pToken1,
		pFee,
		std.PrevRealm().Addr(),
		position.tickLower,
		position.tickUpper,
		_burnedAmount0,
		_burnedAmount1,
	)

	amount0 := u256.MustFromDecimal(_amount0)
	amount1 := u256.MustFromDecimal(_amount1)

	overflow := false
	position.tokensOwed0, overflow = new(u256.Uint).SubOverflow(position.tokensOwed0, amount0)
	if overflow {
		position.tokensOwed0 = u256.Zero()
	}
	position.tokensOwed1, overflow = new(u256.Uint).SubOverflow(position.tokensOwed1, amount1)
	if overflow {
		position.tokensOwed1 = u256.Zero()
	}
	positions[params.tokenId] = position

	if position.isClear() {
		// burnNFT(params.tokenId) // actual burn
		burnPosition(params.tokenId) // just update flag
	}

	// NO UNWRAP
	if !params.unwrapResult {
		return params.tokenId, liquidityToRemove, fee0, fee1, amount0, amount1, position.poolKey
	}

	handleUnwrap(pToken0, pToken1, params.unwrapResult, userOldWugnotBalance, std.PrevRealm().Addr())

	return params.tokenId, liquidityToRemove, fee0, fee1, amount0, amount1, position.poolKey
}

// Repositiomn adjusts the position of an existing liquidity token
// by changing its price range and liquidity amount.
func Reposition(
	tokenId uint64,
	tickLower int32,
	tickUpper int32,
	_amount0Desired string, // uint256
	_amount1Desired string, // uint256
	_amount0Min string, // *u256.Uint
	_amount1Min string, // *u256.Uint
) (uint64, string, int32, int32, string, string) { // tokenId, liquidity, tickLower, tickUpper, amount0, amount1
	common.IsHalted()
	en.MintAndDistributeGns()

	// verify tokenId exists
	if !exists(tokenId) {
		panic(ufmt.Sprintf("[POSITION] position.gno__Reposition() || tokenId(%d) doesn't exist", tokenId))
	}

	// MUST BE OWNER TO REPOSITION
	// can not be approved address > staked position can't be modified
	owner := gnft.OwnerOf(tid(tokenId))
	if owner != std.PrevRealm().Addr() {
		panic(ufmt.Sprintf("[POSITION] position.gno__Reposition() || only owner can reposition__owner(%s) == std.PrevRealm().Addr()(%s)", owner, std.PrevRealm().Addr()))
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

		wrap(ugnotSent, std.PrevRealm().Addr())
	}

	liquidity, amount0, amount1 := addLiquidity(
		AddLiquidityParams{
			poolKey:        position.poolKey,
			tickLower:      tickLower,
			tickUpper:      tickUpper,
			amount0Desired: u256.MustFromDecimal(_amount0Desired),
			amount1Desired: u256.MustFromDecimal(_amount1Desired),
			amount0Min:     u256.MustFromDecimal(_amount0Min),
			amount1Min:     u256.MustFromDecimal(_amount1Min),
			caller:         std.PrevRealm().Addr(),
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
	// OBS: do not reset feeGrowthInside1LastX128 and feeGrowthInside1LastX128 to zero
	// if so, ( decrease 100% -> reposition )
	// > at this point, that position will have unclaimedFee which isn't intended
	// position.feeGrowthInside0LastX128 = u256.Zero()
	// position.feeGrowthInside1LastX128 = u256.Zero()

	position.tokensOwed0 = u256.Zero()
	position.tokensOwed1 = u256.Zero()
	position.burned = false

	positions[tokenId] = position

	poolSqrtPriceX96 := pl.PoolGetSqrtPriceX96(position.poolKey)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"Reposition",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"tickLower", ufmt.Sprintf("%d", tickLower),
		"tickUpper", ufmt.Sprintf("%d", tickUpper),
		"liquidity", liquidity.ToString(),
		"internal_amount0", amount0.ToString(),
		"internal_amount1", amount1.ToString(),
		"internal_oldTickLower", ufmt.Sprintf("%d", oldTickLower),
		"internal_oldTickUpper", ufmt.Sprintf("%d", oldTickUpper),
		"internal_poolPath", position.poolKey,
		"internal_sqrtPriceX96", poolSqrtPriceX96.ToString(),
	)

	return tokenId, liquidity.ToString(), tickLower, tickUpper, amount0.ToString(), amount1.ToString()
}

// CollectFee collects swap fee from the position
//
// Panics:
//   - position doesn't exist
//   - caller is not owner or approved
func CollectFee(tokenId uint64, unwrapResult bool) (uint64, string, string, string, string, string) { // tokenId, afterFee0, afterFee1, poolPath, origFee0, origFee1
	common.IsHalted()
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

	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	pool := pl.GetPoolFromPoolPath(position.poolKey)
	_feeGrowthInside0LastX128, _feeGrowthInside1LastX128 := pool.PoolGetPositionFeeGrowthInside0LastX128(positionKey), pool.PoolGetPositionFeeGrowthInside1LastX128(positionKey)
	feeGrowthInside0LastX128 := u256.MustFromDecimal(_feeGrowthInside0LastX128.ToString())
	feeGrowthInside1LastX128 := u256.MustFromDecimal(_feeGrowthInside1LastX128.ToString())

	tokensOwed0 := position.tokensOwed0
	tokensOwed1 := position.tokensOwed1

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
	userWugnot := wugnot.BalanceOf(a2u(std.PrevRealm().Addr()))

	amount0, amount1 := pl.Collect(
		token0,
		token1,
		fee,
		std.PrevRealm().Addr(),
		position.tickLower,
		position.tickUpper,
		tokensOwed0.ToString(),
		tokensOwed1.ToString(),
	)

	// sometimes there will be a few less uBase amount than expected due to rounding down in core, but we just subtract the full amount expected
	// instead of the actual amount so we can burn the token
	position.tokensOwed0 = new(u256.Uint).Sub(tokensOwed0, u256.MustFromDecimal(amount0))
	position.tokensOwed1 = new(u256.Uint).Sub(tokensOwed1, u256.MustFromDecimal(amount1))

	positions[tokenId] = position

	// handle withdrawal fee
	withoutFee0, withoutFee1 := pl.HandleWithdrawalFee(tokenId, token0, amount0, token1, amount1, position.poolKey, std.PrevRealm().Addr())

	// UNWRAP
	pToken0, pToken1, _ := poolKeyDivide(position.poolKey)
	if (pToken0 == consts.WUGNOT_PATH || pToken1 == consts.WUGNOT_PATH) && unwrapResult {
		userNewWugnot := wugnot.BalanceOf(a2u(std.PrevRealm().Addr()))
		unwrapAmount := userNewWugnot - userWugnot

		if unwrapAmount > 0 {
			unwrap(unwrapAmount, std.PrevRealm().Addr())
		}
	}

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"CollectSwapFee",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"internal_fee0", withoutFee0,
		"internal_fee1", withoutFee1,
		"internal_poolPath", position.poolKey,
		"internal_unwrapResult", ufmt.Sprintf("%t", unwrapResult),
	)

	return tokenId, withoutFee0, withoutFee1, position.poolKey, amount0, amount1
}

func calculateTokensOwed(
	feeGrowthInsideLastX128 *u256.Uint,
	positionFeeGrowthInsideLastX128 *u256.Uint,
	positionLiquidity *u256.Uint,
) *u256.Uint {
	diff := new(u256.Uint).Sub(feeGrowthInsideLastX128, positionFeeGrowthInsideLastX128)
	return u256.MulDiv(diff, positionLiquidity, u256.MustFromDecimal(consts.Q128))
}

func updateTokensOwed(
	feeGrowthInsideLastX128 *u256.Uint,
	positionFeeGrowthInsideLastX128 *u256.Uint,
	positionLiquidity *u256.Uint,
	burnedAmount *u256.Uint,
	tokensOwed *u256.Uint,
) *u256.Uint {
	additionalTokensOwed := calculateTokensOwed(feeGrowthInsideLastX128, positionFeeGrowthInsideLastX128, positionLiquidity)
	add := new(u256.Uint).Add(burnedAmount, additionalTokensOwed)
	return new(u256.Uint).Add(tokensOwed, add)
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

func verifyTokenIdAndOwnership(tokenId uint64) {
	if !exists(tokenId) {
		panic(ufmt.Sprintf("[POSITION] position.gno__verifyTokenIdAndOwnership() || tokenId(%d) doesn't exist", tokenId))
	}
	owner := gnft.OwnerOf(tid(tokenId))
	if owner != std.PrevRealm().Addr() {
		panic(ufmt.Sprintf("[POSITION] position.gno__verifyTokenIdAndOwnership() || only owner can decrease liquidity__owner(%s) == std.PrevRealm().Addr()(%s)", owner, std.PrevRealm().Addr()))
	}
}

func calculateLiquidityToRemove(positionLiquidity *u256.Uint, liquidityRatio uint64) *u256.Uint {
	liquidityToRemove := new(u256.Uint).Mul(positionLiquidity, u256.NewUint(liquidityRatio))
	liquidityToRemove = new(u256.Uint).Div(liquidityToRemove, u256.NewUint(100))
	if positionLiquidity.Lt(liquidityToRemove) || liquidityRatio == 100 {
		return positionLiquidity
	}
	return liquidityToRemove
}

func verifyBurnedAmounts(burnedAmount0, burnedAmount1, amount0Min, amount1Min *u256.Uint) {
	if !(burnedAmount0.Gte(amount0Min) && burnedAmount1.Gte(amount1Min)) {
		panic(ufmt.Sprintf("[POSITION] position.gno__verifyBurnedAmounts() || burnedAmount0(%s) >= amount0Min(%s) && burnedAmount1(%s) >= amount1Min(%s)", burnedAmount0.ToString(), amount0Min.ToString(), burnedAmount1.ToString(), amount1Min.ToString()))
	}
}

func handleUnwrap(pToken0, pToken1 string, unwrapResult bool, userOldWugnotBalance uint64, to std.Address) {
	if (pToken0 == consts.WRAPPED_WUGNOT || pToken1 == consts.WRAPPED_WUGNOT) && unwrapResult {
		userNewWugnotBalance := wugnot.BalanceOf(a2u(to))
		leftOver := userNewWugnotBalance - userOldWugnotBalance
		unwrap(leftOver, to)
	}
}
