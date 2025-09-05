package position

import (
	"encoding/base64"
	"std"

	"gno.land/p/nt/ufmt"
	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/rbac"
	"gno.land/r/gnoswap/referral"
	"gno.land/r/gnoswap/v1/common"
	pl "gno.land/r/gnoswap/v1/pool"
)

var (
	positionAddr = rbac.DefaultRoleAddresses[prabc.ROLE_POSITION]
	stakerAddr   = rbac.DefaultRoleAddresses[prabc.ROLE_STAKER]
)

const (
	ZERO_LIQUIDITY_FOR_FEE_COLLECTION = "0"
)

// Mint creates a new liquidity position NFT.
//
// Parameters:
//   - token0, token1: token contract paths
//   - fee: pool fee tier
//   - tickLower, tickUpper: price range boundaries
//   - amount0Desired, amount1Desired: desired token amounts
//   - amount0Min, amount1Min: minimum acceptable amounts
//   - deadline: transaction deadline
//   - mintTo: NFT recipient address
//   - caller: transaction initiator
//   - referrer: referral address
//
// Returns tokenId, liquidity, amount0, amount1.
// Only callable by users or staker contract.
// Note: Slippage protection via amount0Min/amount1Min.
func Mint(
	cur realm,
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	amount0Desired string,
	amount1Desired string,
	amount0Min string,
	amount1Min string,
	deadline int64,
	mintTo std.Address,
	caller std.Address,
	referrer string,
) (uint64, string, string, string) {
	halt.AssertIsNotHaltedPosition()

	previousRealm := std.PreviousRealm()
	if !previousRealm.IsUser() {
		access.AssertIsStaker(previousRealm.Address())
	} else {
		assertEqualsAddress(previousRealm.Address(), mintTo)
		assertEqualsAddress(previousRealm.Address(), caller)
	}

	assertIsNotExpired(deadline)

	referral.TryRegister(cross, caller, referrer)

	emission.MintAndDistributeGns(cross)

	mintInput := MintInput{
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
		panic(newErrorWithDetail(errInvalidInput, err.Error()))
	}

	// mint liquidity
	params := newMintParams(processedInput, mintInput)
	id, liquidity, amount0, amount1 := mint(params)

	// refund leftover wrapped tokens
	if processedInput.tokenPair.token0IsNative && processedInput.tokenPair.wrappedAmount > safeConvertToInt64(amount0) {
		err = unwrap(processedInput.tokenPair.wrappedAmount-safeConvertToInt64(amount0), caller)
		if err != nil {
			panic(newErrorWithDetail(errWrapUnwrap, err.Error()))
		}
	}

	if processedInput.tokenPair.token1IsNative && processedInput.tokenPair.wrappedAmount > safeConvertToInt64(amount1) {
		err = unwrap(processedInput.tokenPair.wrappedAmount-safeConvertToInt64(amount1), caller)
		if err != nil {
			panic(newErrorWithDetail(errWrapUnwrap, err.Error()))
		}
	}

	poolSqrtPriceX96 := pl.GetSlot0SqrtPriceX96(processedInput.poolPath)

	std.Emit(
		"Mint",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"tickLower", formatInt(processedInput.tickLower),
		"tickUpper", formatInt(processedInput.tickUpper),
		"poolPath", processedInput.poolPath,
		"mintTo", mintTo.String(),
		"caller", caller.String(),
		"lpPositionId", formatUint(id),
		"liquidity", liquidity.ToString(),
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
		"sqrtPriceX96", poolSqrtPriceX96.ToString(),
		"token0Balance", pl.GetBalanceToken0(processedInput.poolPath),
		"token1Balance", pl.GetBalanceToken1(processedInput.poolPath),
	)

	return id, liquidity.ToString(), amount0.ToString(), amount1.ToString()
}

// IncreaseLiquidity increases liquidity of an existing position.
//
// Adds more liquidity to existing NFT position.
// Maintains same price range as original position.
// Calculates optimal token ratio for current price.
//
// Parameters:
//   - positionId: NFT token ID to increase
//   - amount0DesiredStr: Desired token0 amount
//   - amount1DesiredStr: Desired token1 amount
//   - amount0MinStr: Minimum token0 (slippage protection)
//   - amount1MinStr: Minimum token1 (slippage protection)
//   - deadline: Transaction expiration timestamp
//
// Returns:
//   - positionId: Same NFT ID
//   - liquidity: Total liquidity after increase
//   - amount0: Token0 actually deposited
//   - amount1: Token1 actually deposited
//   - poolPath: Pool identifier
//
// Requirements:
//   - Caller must own the position NFT
//   - Position must have liquidity
//   - Sufficient token balances and approvals
func IncreaseLiquidity(
	cur realm,
	positionId uint64,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, string, string, string) {
	halt.AssertIsNotHaltedPosition()

	caller := std.PreviousRealm().Address()
	assertIsOwnerForToken(positionId, caller)

	assertValidNumberString(amount0DesiredStr)
	assertValidNumberString(amount1DesiredStr)
	assertValidNumberString(amount0MinStr)
	assertValidNumberString(amount1MinStr)
	assertIsNotExpired(deadline)

	emission.MintAndDistributeGns(cross)

	position := MustGetPosition(positionId)
	token0, token1, _ := splitOf(position.poolKey)
	err := validateTokenPath(token0, token1)
	if err != nil {
		panic(newErrorWithDetail(err, ufmt.Sprintf("token0(%s), token1(%s)", token0, token1)))
	}

	wrappedAmount := int64(0)
	if isWrappedToken(token0) {
		amount0DesiredInt := mustParseInt64(amount0DesiredStr)
		wrappedAmount, err = safeWrapNativeToken(amount0DesiredInt, caller)
		if err != nil {
			panic(err)
		}
	} else if isWrappedToken(token1) {
		amount1DesiredInt := mustParseInt64(amount1DesiredStr)
		wrappedAmount, err = safeWrapNativeToken(amount1DesiredInt, caller)
		if err != nil {
			panic(err)
		}
	}

	amount0Desired, amount1Desired, amount0Min, amount1Min := parseAmounts(amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr)
	increaseLiquidityParams := IncreaseLiquidityParams{
		positionId:     positionId,
		amount0Desired: amount0Desired,
		amount1Desired: amount1Desired,
		amount0Min:     amount0Min,
		amount1Min:     amount1Min,
		deadline:       deadline,
		caller:         caller,
	}

	_, liquidity, amount0, amount1, poolPath, err := increaseLiquidity(increaseLiquidityParams)
	if err != nil {
		panic(err)
	}

	if err := unwrapLeftoverWrappedToken(token0, wrappedAmount, safeConvertToInt64(amount0), caller); err != nil {
		panic(err)
	}
	if err := unwrapLeftoverWrappedToken(token1, wrappedAmount, safeConvertToInt64(amount1), caller); err != nil {
		panic(err)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"IncreaseLiquidity",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"caller", caller.String(),
		"lpPositionId", formatUint(positionId),
		"liquidity", liquidity.ToString(),
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
		"sqrtPriceX96", pl.GetSlot0SqrtPriceX96(poolPath).ToString(),
		"positionLiquidity", PositionGetPositionLiquidityStr(positionId),
		"token0Balance", pl.GetBalanceToken0(poolPath),
		"token1Balance", pl.GetBalanceToken1(poolPath),
	)

	return positionId, liquidity.ToString(), amount0.ToString(), amount1.ToString(), poolPath
}

// unwrapLeftoverWrappedToken unwraps leftover wrapped tokens to native tokens.
func unwrapLeftoverWrappedToken(token string, wrapped, amount int64, caller std.Address) error {
	unwrappable := isWrappedToken(token) && wrapped > amount
	if !unwrappable {
		return nil
	}

	err := unwrap(wrapped-amount, caller)
	if err != nil {
		return makeErrorWithDetails(errWrapUnwrap, err.Error())
	}

	return nil
}

// DecreaseLiquidity decreases liquidity of an existing position.
//
// Removes liquidity but keeps NFT ownership.
// Calculates tokens owed based on current price.
// Two-step: decrease then collect tokens.
//
// Parameters:
//   - positionId: NFT token ID
//   - liquidityStr: Amount of liquidity to remove
//   - amount0MinStr: Min token0 to receive (slippage)
//   - amount1MinStr: Min token1 to receive (slippage)
//   - deadline: Transaction expiration
//   - unwrapResult: Convert WUGNOT to GNOT if true
//
// Returns:
//   - positionId: Same NFT ID
//   - liquidity: Remaining liquidity
//   - fee0, fee1: Fees collected
//   - amount0, amount1: Principal collected
//   - poolPath: Pool identifier
//
// Note: Applies 1% withdrawal fee on collected amounts.
func DecreaseLiquidity(
	cur realm,
	positionId uint64,
	liquidityStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
	unwrapResult bool,
) (uint64, string, string, string, string, string, string) {
	halt.AssertIsNotHaltedPosition()
	halt.AssertIsNotHaltedWithdraw()

	caller := std.PreviousRealm().Address()
	assertIsOwnerForToken(positionId, caller)
	assertIsNotExpired(deadline)
	assertValidLiquidityAmount(liquidityStr)

	emission.MintAndDistributeGns(cross)

	amount0Min := u256.MustFromDecimal(amount0MinStr)
	amount1Min := u256.MustFromDecimal(amount1MinStr)
	decreaseLiquidityParams := DecreaseLiquidityParams{
		positionId:   positionId,
		liquidity:    liquidityStr,
		amount0Min:   amount0Min,
		amount1Min:   amount1Min,
		deadline:     deadline,
		unwrapResult: unwrapResult,
		caller:       caller,
	}

	positionId, liquidity, fee0, fee1, amount0, amount1, poolPath, err := decreaseLiquidity(decreaseLiquidityParams)
	if err != nil {
		panic(err)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"DecreaseLiquidity",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpPositionId", formatUint(positionId),
		"poolPath", poolPath,
		"decreasedLiquidity", liquidity,
		"feeAmount0", fee0,
		"feeAmount1", fee1,
		"amount0", amount0,
		"amount1", amount1,
		"unwrapResult", formatBool(unwrapResult),
		"sqrtPriceX96", pl.GetSlot0SqrtPriceX96(poolPath).ToString(),
		"positionLiquidity", PositionGetPositionLiquidityStr(positionId),
		"token0Balance", pl.GetBalanceToken0(poolPath),
		"token1Balance", pl.GetBalanceToken1(poolPath),
	)

	return positionId, liquidity, fee0, fee1, amount0, amount1, poolPath
}

// CollectFee collects swap fee from the position.
//
// Claims accumulated fees without removing liquidity.
// Useful for active positions earning ongoing fees.
// Applies protocol withdrawal fee.
//
// Parameters:
//   - positionId: NFT token ID
//   - unwrapResult: Convert WUGNOT to GNOT if true
//
// Returns:
//   - positionId: Same NFT ID
//   - fee0, fee1: Fees collected (after 1% protocol fee)
//   - amount0, amount1: Always "0" (no principal)
//   - poolPath: Pool identifier
//
// Requirements:
//   - Caller must be owner or approved operator
//   - Position must have accumulated fees
func CollectFee(
	cur realm,
	positionId uint64,
	unwrapResult bool,
) (uint64, string, string, string, string, string) {
	halt.AssertIsNotHaltedPosition()
	halt.AssertIsNotHaltedWithdraw()

	caller := std.PreviousRealm().Address()
	assertIsOwnerOrOperatorForToken(positionId, caller)

	return collectFee(positionId, unwrapResult, caller)
}

// collectFee performs fee collection and withdrawal fee calculation.
func collectFee(
	positionId uint64,
	unwrapResult bool,
	caller std.Address,
) (uint64, string, string, string, string, string) {
	emission.MintAndDistributeGns(cross)

	// verify position
	position := MustGetPosition(positionId)
	token0, token1, fee := splitOf(position.poolKey)

	pl.Burn(
		cross,
		token0,
		token1,
		fee,
		position.tickLower,
		position.tickUpper,
		ZERO_LIQUIDITY_FOR_FEE_COLLECTION, // burn '0' liquidity to collect fee
		caller,
	)

	currentFeeGrowth, err := getCurrentFeeGrowth(position, caller)
	if err != nil {
		panic(newErrorWithDetail(err, "failed to get current fee growth"))
	}

	tokensOwed0, tokensOwed1 := calculateFees(position, currentFeeGrowth)

	position.feeGrowthInside0LastX128 = u256.Zero().Set(currentFeeGrowth.feeGrowthInside0LastX128)
	position.feeGrowthInside1LastX128 = u256.Zero().Set(currentFeeGrowth.feeGrowthInside1LastX128)

	// collect fee
	amount0, amount1 := pl.Collect(
		cross,
		token0, token1, fee,
		caller,
		position.tickLower, position.tickUpper,
		tokensOwed0.ToString(), tokensOwed1.ToString(),
	)

	// sometimes there will be a few less uBase amount than expected due to rounding down in core, but we just subtract the full amount expected
	// instead of the actual amount so we can burn the token
	position.tokensOwed0 = u256.Zero().Sub(tokensOwed0, u256.MustFromDecimal(amount0))
	position.tokensOwed1 = u256.Zero().Sub(tokensOwed1, u256.MustFromDecimal(amount1))
	mustUpdatePosition(positionId, position)

	withdrawalFeeBps := pl.GetWithdrawalFee()
	amount0WithoutFee, fee0 := calculateAmountWithWithdrawalFee(amount0, withdrawalFeeBps)
	amount1WithoutFee, fee1 := calculateAmountWithWithdrawalFee(amount1, withdrawalFeeBps)

	poolAddr, ok := access.GetAddress(prabc.ROLE_POOL.String())
	if !ok {
		panic("pool address not found")
	}

	if isWrappedToken(token0) && unwrapResult {
		unwrapWithTransferFrom(poolAddr, caller, amount0WithoutFee)
	} else {
		common.TransferFrom(cross, token0, poolAddr, caller, amount0WithoutFee)
	}

	if isWrappedToken(token1) && unwrapResult {
		unwrapWithTransferFrom(poolAddr, caller, amount1WithoutFee)
	} else {
		common.TransferFrom(cross, token1, poolAddr, caller, amount1WithoutFee)
	}

	protocolFeeAddr, ok := access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	if !ok {
		panic("protocol fee address not found")
	}

	common.TransferFrom(cross, token0, poolAddr, protocolFeeAddr, fee0)
	common.TransferFrom(cross, token1, poolAddr, protocolFeeAddr, fee1)

	amount0WithoutFeeStr := formatInt(amount0WithoutFee)
	amount1WithoutFeeStr := formatInt(amount1WithoutFee)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"CollectSwapFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpPositionId", formatUint(positionId),
		"feeAmount0", amount0WithoutFeeStr,
		"feeAmount1", amount1WithoutFeeStr,
		"poolPath", position.poolKey,
		"unwrapResult", formatBool(unwrapResult),
	)

	std.Emit(
		"WithdrawalFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpTokenId", formatUint(positionId),
		"poolPath", position.poolKey,
		"feeAmount0", formatInt(fee0),
		"feeAmount1", formatInt(fee1),
		"amount0WithoutFee", amount0WithoutFeeStr,
		"amount1WithoutFee", amount1WithoutFeeStr,
	)

	return positionId, amount0WithoutFeeStr, amount1WithoutFeeStr, position.poolKey, amount0, amount1
}

var feeAmountDivisor = u256.NewUint(10000)

// calculateAmountWithWithdrawalFee calculates amount after deducting withdrawal fee.
func calculateAmountWithWithdrawalFee(amount string, fee uint64) (int64, int64) {
	if fee == 0 {
		return safeConvertToInt64(u256.MustFromDecimal(amount)), 0
	}

	amountUint := u256.MustFromDecimal(amount)
	feeUint := u256.NewUint(fee)

	feeAmount := u256.Zero().Mul(amountUint, feeUint)
	feeAmount = u256.Zero().Div(feeAmount, feeAmountDivisor)
	amountWithoutFee := u256.Zero().Sub(amountUint, feeAmount)

	return safeConvertToInt64(amountWithoutFee), safeConvertToInt64(feeAmount)
}

// SetPositionOperator sets an operator for a position.
// Only staker can call this function.
func SetPositionOperator(
	cur realm,
	id uint64,
	operator std.Address,
) {
	halt.AssertIsNotHaltedPosition()

	caller := std.PreviousRealm().Address()
	access.AssertIsStaker(caller)

	position := MustGetPosition(id)
	position.operator = operator
	mustUpdatePosition(id, position)
}

// computePositionKey generates a unique base64-encoded key for a liquidity position.
func computePositionKey(
	tickLower int32,
	tickUpper int32,
) string {
	currentRealmPath := std.CurrentRealm().PkgPath()
	key := ufmt.Sprintf("%s__%d__%d", currentRealmPath, tickLower, tickUpper)
	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}

// getCurrentFeeGrowth retrieves current fee growth values for a position.
func getCurrentFeeGrowth(position Position, owner std.Address) (FeeGrowthInside, error) {
	positionKey := computePositionKey(position.tickLower, position.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pl.GetPositionFeeGrowthInsideLastX128(position.poolKey, positionKey)

	feeGrowthInside := FeeGrowthInside{
		feeGrowthInside0LastX128: feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: feeGrowthInside1LastX128,
	}

	return feeGrowthInside, nil
}
