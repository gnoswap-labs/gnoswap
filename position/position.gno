package position

import (
	"encoding/base64"
	"std"
	"strconv"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v1/gnft"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
)

var (
	positions = avl.NewTree() // tokenId[uint64] -> Position
	nextId    = uint64(1)
)

// nextId is the next tokenId to be minted
func getNextId() uint64 {
	return nextId
}

// region: Mint

type MintInput struct {
	token0         string
	token1         string
	fee            uint32
	tickLower      int32
	tickUpper      int32
	amount0Desired string
	amount1Desired string
	amount0Min     string
	amount1Min     string
	deadline       int64
	mintTo         std.Address
	caller         std.Address
}

type TokenPair struct {
	token0         string
	token1         string
	token0IsNative bool
	token1IsNative bool
}

type ProcessedMintInput struct {
	tokenPair      TokenPair
	amount0Desired *u256.Uint
	amount1Desired *u256.Uint
	amount0Min     *u256.Uint
	amount1Min     *u256.Uint
	tickLower      int32
	tickUpper      int32
	poolPath       string
}

// Mint creates a new liquidity position and mints liquidity tokens.
// It also handles the conversion between GNOT and WUGNOT transparently for the user.
// Returns minted tokenId, liquidity, amount0, amount1
// ref: https://docs.gnoswap.io/contracts/position/position.gno#mint
func Mint(
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
	mintTo std.Address,
	caller std.Address,
) (uint64, string, string, string) {
	common.IsHalted()
	en.MintAndDistributeGns()

	prev := std.PrevRealm()
	if err := assertCallerPermission(prev); err != nil {
		panic(addDetailToError(errNoPermission, err.Error()))
	}

	caller, mintTo = upgradeCallerIfUserCalled(caller, mintTo, prev)

	token0, token1, token0IsNative, token1IsNative := processTokens(token0, token1)
	userWugnotBalance := wugnot.BalanceOf(a2u(caller))

	if token1 < token0 {
		token0, token1 = token1, token0
		amount0DesiredStr, amount1DesiredStr = amount1DesiredStr, amount0DesiredStr
		amount0MinStr, amount1MinStr = amount1MinStr, amount0MinStr
		tickLower, tickUpper = -tickUpper, -tickLower
		token0IsNative, token1IsNative = token1IsNative, token0IsNative
	}

	amount0Desired := u256.MustFromDecimal(amount0DesiredStr)
	amount1Desired := u256.MustFromDecimal(amount1DesiredStr)
	amount0Min := u256.MustFromDecimal(amount0MinStr)
	amount1Min := u256.MustFromDecimal(amount1MinStr)

	// one of token amount can be 0 if position is out of range
	// check this condition by using DryMint()
	poolPath := ufmt.Sprintf("%s:%s:%d", token0, token1, fee)

	err := handleNativeToken(token0IsNative, token1IsNative, caller)
	if err != nil {
		panic(addDetailToError(errWrapUnwrap, err.Error()))
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
		mintTo:         mintTo,
		caller:         caller,
	}

	processedInput, err := processMintInput(mintInput)
	if err != nil {
		panic(addDetailToError(errInvalidInput, err.Error()))
	}

	// XXX (@notJoon): This seems has a dependency in the execution order
	userWugnotBalance := wugnot.BalanceOf(a2u(caller))

	if err := handleNativeToken(
		processedInput.tokenPair.token0IsNative,
		processedInput.tokenPair.token1IsNative,
		caller,
	); err != nil {
		panic(addDetailToError(errWrapUnwrap, err.Error()))
	}

	// perform mint operation
	mintParams := newMintParams(processedInput, mintInput)
	tokenId, liquidity, amount0, amount1 := mint(mintParams)

	handleLeftoverNativeToken(
		processedInput.tokenPair.token0IsNative,
		processedInput.tokenPair.token1IsNative,
		userWugnotBalance,
		caller,
	)

	poolSqrtPriceX96 := pl.PoolGetSlot0SqrtPriceX96(processedInput.poolPath)

	prevAddr, prevPkgPath := getPrevAsString()

	std.Emit(
		"Mint",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"tickLower", ufmt.Sprintf("%d", processedInput.tickLower),
		"tickUpper", ufmt.Sprintf("%d", processedInput.tickUpper),
		"poolPath", processedInput.poolPath,
		"mintTo", mintTo.String(),
		"caller", caller.String(),
		"internal_lpTokenId", ufmt.Sprintf("%d", tokenId),
		"internal_liquidity", liquidity.ToString(),
		"internal_amount0", amount0.ToString(),
		"internal_amount1", amount1.ToString(),
		"internal_sqrtPriceX96", poolSqrtPriceX96,
	)

	return tokenId, liquidity.ToString(), amount0.ToString(), amount1.ToString()
}

func assertCallerPermission(prev std.Realm) error {
	isUserCalled := prev.PkgPath() == ""
	isStakerCalled := prev.Addr() == consts.STAKER_ADDR

	if !common.GetLimitCaller() {
		return nil
	}

	if !(isUserCalled || isStakerCalled) {
		return ufmt.Errorf(
			"only user or staker can call, but called from %s", prev.Addr().String(),
		)
	}

	return nil
}

func upgradeCallerIfUserCalled(caller, mintTo std.Address, prev std.Realm) (std.Address, std.Address) {
	// user called
	if prev.PkgPath() == "" {
		caller = prev.Addr()
		mintTo = prev.Addr()
	}

	return caller, mintTo
}

func processMintInput(input MintInput) (ProcessedMintInput, error) {
	var result ProcessedMintInput

	// process tokens
	token0, token1, token0IsNative, token1IsNative := processTokens(input.token0, input.token1)
	pair := TokenPair{
		token0:         token0,
		token1:         token1,
		token0IsNative: token0IsNative,
		token1IsNative: token1IsNative,
	}

	// parse amounts
	amount0Desired, amount1Desired, amount0Min, amount1Min := parseAmounts(input.amount0Desired, input.amount1Desired, input.amount0Min, input.amount1Min)

	tickLower, tickUpper := input.tickLower, input.tickUpper

	// swap if token1 < token0
	if token1 < token0 {
		pair.token0, pair.token1 = pair.token1, pair.token0
		amount0Desired, amount1Desired = amount1Desired, amount0Desired
		amount0Min, amount1Min = amount1Min, amount0Min
		tickLower, tickUpper = -tickUpper, -tickLower
		pair.token0IsNative, pair.token1IsNative = pair.token1IsNative, pair.token0IsNative
	}

	poolPath := renderPoolPath(pair.token0, pair.token1, input.fee)

	result = ProcessedMintInput{
		tokenPair:      pair,
		amount0Desired: amount0Desired.Clone(),
		amount1Desired: amount1Desired.Clone(),
		amount0Min:     amount0Min.Clone(),
		amount1Min:     amount1Min.Clone(),
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		poolPath:       poolPath,
	}

	return result, nil
}

func parseAmounts(amount0Desired, amount1Desired, amount0Min, amount1Min string) (*u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint) {
	return u256.MustFromDecimal(amount0Desired), u256.MustFromDecimal(amount1Desired), u256.MustFromDecimal(amount0Min), u256.MustFromDecimal(amount1Min)
}

func renderPoolPath(token0, token1 string, fee uint32) string {
	return ufmt.Sprintf("%s:%s:%d", token0, token1, fee)
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

func hasNativeToken(token0IsNative, token1IsNative bool) bool {
	return token0IsNative || token1IsNative
}

func handleNativeToken(token0IsNative, token1IsNative bool, caller std.Address) error {
	if !hasNativeToken(token0IsNative, token1IsNative) {
		return nil
	}

	oldUserWugnotBalance := wugnot.BalanceOf(a2u(caller))
	sent := std.GetOrigSend()
	ugnotSent := uint64(sent.AmountOf("ugnot"))

	if ugnotSent <= 0 {
		return nil
	}

	if err := wrap(ugnotSent, caller); err != nil {
		return err
	}

	newUserWugnotBalance := wugnot.BalanceOf(a2u(caller))
	diff := newUserWugnotBalance - oldUserWugnotBalance

	if diff != ugnotSent {
		return ufmt.Errorf("amount of ugnot (%d) is not equal to amount of wugnot. (diff: %d)", ugnotSent, diff)
	}

	return nil
}

func handleLeftoverNativeToken(token0IsNative, token1IsNative bool, userWugnotBalance uint64, caller std.Address) {
	if !hasNativeToken(token0IsNative, token1IsNative) {
		return
	}

	userWugnotAfterMint := wugnot.BalanceOf(a2u(caller))

	leftOver := userWugnotAfterMint - userWugnotBalance
	if leftOver > 0 {
		unwrap(leftOver, caller)
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
	gnft.Mint(a2u(params.mintTo), tokenIdFrom(tokenId)) // owner, tokenId
	nextId++

	positionKey := positionKeyCompute(GetOrigPkgAddr(), params.tickLower, params.tickUpper)
	_feeGrowthInside0LastX128 := pool.PositionFeeGrowthInside0LastX128(positionKey)
	_feeGrowthInside1LastX128 := pool.PositionFeeGrowthInside1LastX128(positionKey)
	feeGrowthInside0LastX128 := u256.MustFromDecimal(_feeGrowthInside0LastX128.ToString())
	feeGrowthInside1LastX128 := u256.MustFromDecimal(_feeGrowthInside1LastX128.ToString())

	position := Position{
		nonce:                    u256.Zero(),
		operator:                 consts.ZERO_ADDRESS,
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
	updated := setPosition(tokenId, position)
	if updated {
		panic(addDetailToError(
			errPositionExist,
			ufmt.Sprintf("tokenId(%d) already exists", tokenId),
		))
	}

	return tokenId, liquidity, amount0, amount1
}

////////////////////////////

// region: IncreaseLiquidity

// IncreaseLiquidity increases liquidity of the existing position
// Returns tokenId, liquidity, amount0, amount1, poolPath
// ref: https://docs.gnoswap.io/contracts/position/position.gno#increaseliquidity
func IncreaseLiquidity(
	tokenId uint64,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, string, string, string) {
	common.IsHalted()
	en.MintAndDistributeGns()

	amount0Desired := u256.MustFromDecimal(amount0DesiredStr)
	amount1Desired := u256.MustFromDecimal(amount1DesiredStr)
	amount0Min := u256.MustFromDecimal(amount0MinStr)
	amount1Min := u256.MustFromDecimal(amount1MinStr)
	increaseLiquidityParams := IncreaseLiquidityParams{
		tokenId:        tokenId,
		amount0Desired: amount0Desired,
		amount1Desired: amount1Desired,
		amount0Min:     amount0Min,
		amount1Min:     amount1Min,
		deadline:       deadline,
	}

	// wrap if target pool has wugnot
	position := MustGetPosition(tokenId)
	pToken0, pToken1, _ := splitOf(position.poolKey)

	isToken0Wugnot := pToken0 == consts.WRAPPED_WUGNOT
	isToken1Wugnot := pToken1 == consts.WRAPPED_WUGNOT

	userOldWugnotBalance := wugnot.BalanceOf(a2u(std.PrevRealm().Addr())) // before wrap, user's origin wugnot balance
	if isToken0Wugnot || isToken1Wugnot {
		sent := std.GetOrigSend()
		ugnotSent := uint64(sent.AmountOf("ugnot"))
		if err := wrap(ugnotSent, std.PrevRealm().Addr()); err != nil {
			panic(addDetailToError(
				errWrapUnwrap,
				ufmt.Sprintf("wrap error: %s", err.Error()),
			))
		}
	}

	// increase liquidity
	_, liquidity, amount0, amount1, poolPath := increaseLiquidity(increaseLiquidityParams)

	// unwrap left
	if isToken0Wugnot || isToken1Wugnot {
		userNewWugnotBalance := wugnot.BalanceOf(a2u(std.PrevRealm().Addr()))

		leftOver := userNewWugnotBalance - userOldWugnotBalance
		unwrap(leftOver, std.PrevRealm().Addr())
	}

	poolSqrtPriceX96 := pl.PoolGetSlot0SqrtPriceX96(poolPath)

	prevAddr, prevPkgPath := getPrevAsString()

	std.Emit(
		"IncreaseLiquidity",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"internal_poolPath", poolPath,
		"internal_liquidity", liquidity.ToString(),
		"internal_amount0", amount0.ToString(),
		"internal_amount1", amount1.ToString(),
		"internal_sqrtPriceX96", poolSqrtPriceX96,
	)

	return tokenId, liquidity.ToString(), amount0.ToString(), amount1.ToString(), poolPath
}

func increaseLiquidity(params IncreaseLiquidityParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint, string) {
	// verify tokenId exists
	if !exists(params.tokenId) {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("tokenId(%d) doesn't exist", params.tokenId),
		))
	}

	// MUST BE OWNER TO INCREASE LIQUIDITY
	// can not be approved address ≈ staked position can't be modified
	owner := gnft.OwnerOf(tokenIdFrom(params.tokenId))
	caller := std.PrevRealm().Addr()
	if owner != caller {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("only owner(%s) can increase liquidity for tokenId(%d), but called from %s", owner, params.tokenId, caller),
		))
	}

	checkDeadline(params.deadline)

	position := MustGetPosition(params.tokenId)
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
	_feeGrowthInside0LastX128 := pool.PositionFeeGrowthInside0LastX128(positionKey)
	_feeGrowthInside1LastX128 := pool.PositionFeeGrowthInside1LastX128(positionKey)
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

	updated := setPosition(params.tokenId, position)
	if !updated {
		panic(addDetailToError(
			errPositionDoesNotExist,
			ufmt.Sprintf("can not increase liquidity for non-existent position(%d)", params.tokenId),
		))
	}

	return params.tokenId, liquidity, amount0, amount1, position.poolKey
}

// DecreaseLiquidity decreases liquidity of the existing position
// It also handles the conversion between GNOT and WUGNOT transparently for the user.
// Returns tokenId, liquidity, fee0, fee1, amount0, amount1, poolPath
// ref: https://docs.gnoswap.io/contracts/position/position.gno#decreaseliquidity
func DecreaseLiquidity(
	tokenId uint64,
	liquidityRatio uint64,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
	unwrapResult bool,
) (uint64, string, string, string, string, string, string) {
	common.IsHalted()
	en.MintAndDistributeGns()

	isNormalRange := liquidityRatio >= 1 && liquidityRatio <= 100
	if !isNormalRange {
		panic(addDetailToError(
			errOutOfRange,
			ufmt.Sprintf("liquidityRatio(%d) should be in range 1 ~ 100", liquidityRatio),
		))
	}

	amount0Min := u256.MustFromDecimal(amount0MinStr)
	amount1Min := u256.MustFromDecimal(amount1MinStr)
	decreaseLiquidityParams := DecreaseLiquidityParams{
		tokenId:        tokenId,
		liquidityRatio: liquidityRatio,
		amount0Min:     amount0Min,
		amount1Min:     amount1Min,
		deadline:       deadline,
		unwrapResult:   unwrapResult,
	}

	tokenId, liquidity, fee0, fee1, amount0, amount1, poolPath := decreaseLiquidity(decreaseLiquidityParams)

	poolSqrtPriceX96 := pl.PoolGetSlot0SqrtPriceX96(poolPath)

	prevAddr, prevPkgPath := getPrevAsString()

	std.Emit(
		"DecreaseLiquidity",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"liquidityRatio", ufmt.Sprintf("%d", liquidityRatio),
		"internal_poolPath", poolPath,
		"internal_liquidity", liquidity.ToString(),
		"internal_fee0", fee0.ToString(),
		"internal_fee1", fee1.ToString(),
		"internal_amount0", amount0.ToString(),
		"internal_amount1", amount1.ToString(),
		"internal_unwrapResult", ufmt.Sprintf("%t", unwrapResult),
		"internal_sqrtPriceX96", poolSqrtPriceX96,
	)

	return tokenId, liquidity.ToString(), fee0.ToString(), fee1.ToString(), amount0.ToString(), amount1.ToString(), poolPath
}

// decreaseLiquidity reduces the liquidity of a given position and collects the corresponding tokens.
// If unwrapResult is true and the position involves WUGNOT, any leftover WUGNOT will be
// unwrapped to GNOT at the end of the operation.
// Returns tokenId, liquidity, fee0, fee1, amount0, amount1, poolPath
func decreaseLiquidity(params DecreaseLiquidityParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint, string) {
	userOldWugnotBalance := wugnot.BalanceOf(a2u(std.PrevRealm().Addr())) // before unwrap

	verifyTokenIdAndOwnership(params.tokenId)
	checkDeadline(params.deadline)

	// BEFORE DECREASE LIQUIDITY, COLLECT FEE FIRST
	_, fee0Str, fee1Str, _, _, _ := CollectFee(params.tokenId, params.unwrapResult)
	fee0 := u256.MustFromDecimal(fee0Str)
	fee1 := u256.MustFromDecimal(fee1Str)

	position := MustGetPosition(params.tokenId)
	positionLiquidity := position.liquidity

	if positionLiquidity.IsZero() {
		panic(addDetailToError(
			errZeroLiquidity,
			ufmt.Sprintf("position(tokenId:%d) has 0 liquidity", params.tokenId),
		))
	}

	liquidityToRemove := calculateLiquidityToRemove(positionLiquidity, params.liquidityRatio)

	pToken0, pToken1, pFee := splitOf(position.poolKey)
	pool := pl.GetPoolFromPoolPath(position.poolKey)

	// BURN HERE
	_burnedAmount0, _burnedAmount1 := pl.Burn(pToken0, pToken1, pFee, position.tickLower, position.tickUpper, liquidityToRemove.ToString())

	burnedAmount0 := u256.MustFromDecimal(_burnedAmount0)
	burnedAmount1 := u256.MustFromDecimal(_burnedAmount1)

	verifyBurnedAmounts(burnedAmount0, burnedAmount1, params.amount0Min, params.amount1Min)

	positionKey := positionKeyCompute(GetOrigPkgAddr(), position.tickLower, position.tickUpper)
	_feeGrowthInside0LastX128 := pool.PositionFeeGrowthInside0LastX128(positionKey)
	_feeGrowthInside1LastX128 := pool.PositionFeeGrowthInside1LastX128(positionKey)
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
	updated := setPosition(params.tokenId, position)
	if !updated {
		panic(addDetailToError(
			errPositionDoesNotExist,
			ufmt.Sprintf("can not decrease liquidity for non-existent position(%d)", params.tokenId),
		))
	}

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
	setPosition(params.tokenId, position)

	if position.isClear() {
		burnPosition(params.tokenId) // just update flag (we don't want to burn actual position)
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
// Returns tokenId, liquidity, tickLower, tickUpper, amount0, amount1
// ref: https://docs.gnoswap.io/contracts/position/position.gno#reposition
func Reposition(
	tokenId uint64,
	tickLower int32,
	tickUpper int32,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
) (uint64, string, int32, int32, string, string) {
	common.IsHalted()
	en.MintAndDistributeGns()

	// verify tokenId exists
	if !exists(tokenId) {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("tokenId(%d) doesn't exist", tokenId),
		))
	}

	// MUST BE OWNER TO REPOSITION
	// can not be approved address > staked position can't be modified
	owner := gnft.OwnerOf(tokenIdFrom(tokenId))
	caller := std.PrevRealm().Addr()
	if owner != caller {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("only owner(%s) can reposition for tokenId(%d), but called from %s", owner, tokenId, caller),
		))
	}

	// position should be burned to reposition
	position := MustGetPosition(tokenId)
	oldTickLower := position.tickLower
	oldTickUpper := position.tickUpper

	if !(position.isClear()) {
		panic(addDetailToError(
			errNotClear,
			ufmt.Sprintf("position(%d) isn't clear(liquidity:%s, tokensOwed0:%s, tokensOwed1:%s)", tokenId, position.liquidity.ToString(), position.tokensOwed0.ToString(), position.tokensOwed1.ToString()),
		))
	}

	token0, token1, _ := splitOf(position.poolKey)
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

		if err := wrap(ugnotSent, std.PrevRealm().Addr()); err != nil {
			panic(addDetailToError(
				errWrapUnwrap,
				ufmt.Sprintf("wrap error: %s", err.Error()),
			))
		}
	}

	liquidity, amount0, amount1 := addLiquidity(
		AddLiquidityParams{
			poolKey:        position.poolKey,
			tickLower:      tickLower,
			tickUpper:      tickUpper,
			amount0Desired: u256.MustFromDecimal(amount0DesiredStr),
			amount1Desired: u256.MustFromDecimal(amount1DesiredStr),
			amount0Min:     u256.MustFromDecimal(amount0MinStr),
			amount1Min:     u256.MustFromDecimal(amount1MinStr),
			caller:         std.PrevRealm().Addr(),
		},
	)

	pool := pl.GetPoolFromPoolPath(position.poolKey)
	positionKey := positionKeyCompute(GetOrigPkgAddr(), tickLower, tickUpper)
	_feeGrowthInside0LastX128 := pool.PositionFeeGrowthInside0LastX128(positionKey)
	_feeGrowthInside1LastX128 := pool.PositionFeeGrowthInside1LastX128(positionKey)
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

	updated := setPosition(tokenId, position)
	if !updated {
		panic(addDetailToError(
			errPositionDoesNotExist,
			ufmt.Sprintf("can not reposition non-existent position(%d)", tokenId),
		))
	}

	poolSqrtPriceX96 := pl.PoolGetSlot0SqrtPriceX96(position.poolKey)

	prevAddr, prevPkgPath := getPrevAsString()

	std.Emit(
		"Reposition",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"tickLower", ufmt.Sprintf("%d", tickLower),
		"tickUpper", ufmt.Sprintf("%d", tickUpper),
		"liquidity", liquidity.ToString(),
		"internal_amount0", amount0.ToString(),
		"internal_amount1", amount1.ToString(),
		"internal_oldTickLower", ufmt.Sprintf("%d", oldTickLower),
		"internal_oldTickUpper", ufmt.Sprintf("%d", oldTickUpper),
		"internal_poolPath", position.poolKey,
		"internal_sqrtPriceX96", poolSqrtPriceX96,
	)

	return tokenId, liquidity.ToString(), tickLower, tickUpper, amount0.ToString(), amount1.ToString()
}

// CollectFee collects swap fee from the position
// Returns tokenId, afterFee0, afterFee1, poolPath, origFee0, origFee1
// ref: https://docs.gnoswap.io/contracts/position/position.gno#collectfee
func CollectFee(tokenId uint64, unwrapResult bool) (uint64, string, string, string, string, string) {
	common.IsHalted()
	en.MintAndDistributeGns()

	// verify tokenId
	if !exists(tokenId) {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("tokenId(%d) doesn't exist", tokenId),
		))
	}

	// verify owner or approved
	isAuthorizedForToken(tokenId)

	// verify position
	position := MustGetPosition(tokenId)

	token0, token1, fee := splitOf(position.poolKey)

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
	_feeGrowthInside0LastX128 := pool.PositionFeeGrowthInside0LastX128(positionKey)
	_feeGrowthInside1LastX128 := pool.PositionFeeGrowthInside1LastX128(positionKey)
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

	updated := setPosition(tokenId, position)
	if !updated {
		panic(addDetailToError(
			errPositionDoesNotExist,
			ufmt.Sprintf("can not collect fee for non-existent position(%d)", tokenId),
		))
	}

	// handle withdrawal fee
	withoutFee0, withoutFee1 := pl.HandleWithdrawalFee(tokenId, token0, amount0, token1, amount1, position.poolKey, std.PrevRealm().Addr())

	// UNWRAP
	pToken0, pToken1, _ := splitOf(position.poolKey)
	if (pToken0 == consts.WUGNOT_PATH || pToken1 == consts.WUGNOT_PATH) && unwrapResult {
		userNewWugnot := wugnot.BalanceOf(a2u(std.PrevRealm().Addr()))
		unwrapAmount := userNewWugnot - userWugnot

		if unwrapAmount > 0 {
			unwrap(unwrapAmount, std.PrevRealm().Addr())
		}
	}

	prevAddr, prevPkgPath := getPrevAsString()

	std.Emit(
		"CollectSwapFee",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
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

func burnPosition(tokenId uint64) {
	position := MustGetPosition(tokenId)
	if !(position.isClear()) {
		panic(addDetailToError(
			errNotClear,
			ufmt.Sprintf("position(%d) isn't clear(liquidity:%s, tokensOwed0:%s, tokensOwed1:%s)", tokenId, position.liquidity.ToString(), position.tokensOwed0.ToString(), position.tokensOwed1.ToString()),
		))
	}

	position.burned = true
	updated := setPosition(tokenId, position)
	if !updated {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("can not burn non-existent position(%d)", tokenId),
		))
	}
}

func isAuthorizedForToken(tokenId uint64) {
	if !(isOwnerOrOperator(std.PrevRealm().Addr(), tokenId)) {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not approved or owner of tokenId(%d)", std.PrevRealm().Addr(), tokenId),
		))
	}
}

func verifyTokenIdAndOwnership(tokenId uint64) {
	if !exists(tokenId) {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("tokenId(%d) doesn't exist", tokenId),
		))
	}

	owner := gnft.OwnerOf(tokenIdFrom(tokenId))
	caller := std.PrevRealm().Addr()
	if owner != caller {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("only owner(%s) can decrease liquidity(tokenId:%d), but called from %s", owner, tokenId, caller),
		))
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
		panic(addDetailToError(
			errSlippage,
			ufmt.Sprintf("burnedAmount0(%s) >= amount0Min(%s) && burnedAmount1(%s) >= amount1Min(%s)", burnedAmount0.ToString(), amount0Min.ToString(), burnedAmount1.ToString(), amount1Min.ToString()),
		))
	}
}

func handleUnwrap(pToken0, pToken1 string, unwrapResult bool, userOldWugnotBalance uint64, to std.Address) {
	if (pToken0 == consts.WRAPPED_WUGNOT || pToken1 == consts.WRAPPED_WUGNOT) && unwrapResult {
		userNewWugnotBalance := wugnot.BalanceOf(a2u(to))
		leftOver := userNewWugnotBalance - userOldWugnotBalance
		unwrap(leftOver, to)
	}
}

func SetPositionOperator(tokenId uint64, operator std.Address) {
	caller := std.PrevRealm().PkgPath()
	if caller != consts.STAKER_PATH {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not staker", caller),
		))
	}

	position := MustGetPosition(tokenId)
	position.operator = operator
	updated := setPosition(tokenId, position)
	if !updated {
		panic(addDetailToError(
			errPositionDoesNotExist,
			ufmt.Sprintf("can not set operator for non-existent position(%d)", tokenId),
		))
	}
}

// MustGetPosition returns a position for a given tokenId
// panics if position doesn't exist
func MustGetPosition(tokenId uint64) Position {
	position, exist := GetPosition(tokenId)
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("position with tokenId(%d) doesn't exist", tokenId),
		))
	}
	return position
}

// GetPosition returns a position for a given tokenId
// Returns false if position doesn't exist
func GetPosition(tokenId uint64) (Position, bool) {
	tokenIdStr := strconv.FormatUint(tokenId, 10)
	iPosition, exist := positions.Get(tokenIdStr)
	if !exist {
		return Position{}, false
	}

	return iPosition.(Position), true
}

// setPosition sets a position for a given tokenId
// Returns true if position is newly created, false if position already exists and just updated.
func setPosition(tokenId uint64, position Position) bool {
	tokenIdStr := strconv.FormatUint(tokenId, 10)
	return positions.Set(tokenIdStr, position)
}

// removePosition removes a position for a given tokenId
func removePosition(tokenId uint64) {
	tokenIdStr := strconv.FormatUint(tokenId, 10)
	positions.Remove(tokenIdStr)
}

func positionKeyCompute(
	owner std.Address,
	tickLower int32,
	tickUpper int32,
) string {
	key := ufmt.Sprintf("%s__%d__%d", owner.String(), tickLower, tickUpper)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}

func positionKeyCompute(
	owner std.Address,
	tickLower int32,
	tickUpper int32,
) string {
	key := ufmt.Sprintf("%s__%d__%d", owner.String(), tickLower, tickUpper)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}
