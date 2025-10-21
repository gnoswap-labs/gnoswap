package v1

import (
	"chain"
	"chain/runtime"
	"encoding/base64"

	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/position"
	pf "gno.land/r/gnoswap/protocol_fee"
	"gno.land/r/gnoswap/rbac"
	"gno.land/r/gnoswap/referral"
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
func (p *positionV1) Mint(
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
	mintTo address,
	caller address,
	referrer string,
) (uint64, string, string, string) {
	halt.AssertIsNotHaltedPositionWithVersion(1)

	previousRealm := runtime.PreviousRealm()
	if !previousRealm.IsUser() {
		access.AssertIsStakerWithVersion(1, previousRealm.Address())
	} else {
		assertEqualsAddress(previousRealm.Address(), mintTo)
		assertEqualsAddress(previousRealm.Address(), caller)
	}

	// assert that the user has sent the correct amount of native coin
	assertIsValidUserCoinSendWithTokenPair(token0, token1, amount0Desired, amount1Desired)
	assertIsNotExpired(deadline)

	success := referral.TryRegister(cross, caller, referrer)
	actualReferrer := referrer
	if !success {
		actualReferrer = referral.GetReferral(caller.String())
	}

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
	processedInput, err := p.processMintInput(mintInput)
	if err != nil {
		panic(newErrorWithDetail(errInvalidInput, err.Error()))
	}

	// mint liquidity
	params := newMintParams(processedInput, mintInput)
	id, liquidity, amount0, amount1 := p.mint(params)

	// refund leftover wrapped tokens
	if processedInput.tokenPair.token0IsNative && processedInput.tokenPair.wrappedAmount > safeConvertToInt64(amount0) {
		err = p.unwrap(processedInput.tokenPair.wrappedAmount-safeConvertToInt64(amount0), caller)
		if err != nil {
			panic(newErrorWithDetail(errWrapUnwrap, err.Error()))
		}
	}

	if processedInput.tokenPair.token1IsNative && processedInput.tokenPair.wrappedAmount > safeConvertToInt64(amount1) {
		err = p.unwrap(processedInput.tokenPair.wrappedAmount-safeConvertToInt64(amount1), caller)
		if err != nil {
			panic(newErrorWithDetail(errWrapUnwrap, err.Error()))
		}
	}

	poolSqrtPriceX96 := pl.GetSlot0SqrtPriceX96(processedInput.poolPath)

	tickCumulative, liquidityCumulative, secondsPerLiquidityCumulativeX128, observationTimestamp :=
		pl.GetObservation(processedInput.poolPath, 0)

	chain.Emit(
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
		"tickCumulative", formatInt(tickCumulative),
		"liquidityCumulative", liquidityCumulative,
		"secondsPerLiquidityCumulativeX128", secondsPerLiquidityCumulativeX128,
		"observationTimestamp", formatInt(observationTimestamp),
		"referrer", actualReferrer,
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
//   - Sufficient token balances and approvals
func (p *positionV1) IncreaseLiquidity(
	positionId uint64,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, string, string, string) {
	halt.AssertIsNotHaltedPositionWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	assertIsOwnerForToken(p, positionId, caller)

	assertValidNumberString(amount0DesiredStr)
	assertValidNumberString(amount1DesiredStr)
	assertValidNumberString(amount0MinStr)
	assertValidNumberString(amount1MinStr)
	assertIsNotExpired(deadline)

	emission.MintAndDistributeGns(cross)

	position := p.mustGetPosition(positionId)
	token0, token1, _ := splitOf(position.PoolKey())

	// assert that the user has sent the correct amount of native coin
	assertIsValidUserCoinSendWithWrappedTokenPair(token0, token1, amount0DesiredStr, amount1DesiredStr)

	receivedCoins := common.ExistsUserSendCoins()

	err := validateTokenPath(token0, token1)
	if err != nil {
		panic(newErrorWithDetail(err, ufmt.Sprintf("token0(%s), token1(%s)", token0, token1)))
	}

	wrappedAmount := int64(0)

	if receivedCoins {
		inputWrappedAmount := int64(0)

		if common.IsGNOTPath(token0) {
			inputWrappedAmount = mustParseInt64(amount0DesiredStr)
		} else if common.IsGNOTPath(token1) {
			inputWrappedAmount = mustParseInt64(amount1DesiredStr)
		}

		wrappedAmount, err = p.safeWrapNativeToken(inputWrappedAmount, caller)
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

	_, liquidity, amount0, amount1, poolPath, err := p.increaseLiquidity(increaseLiquidityParams)
	if err != nil {
		panic(err)
	}

	if err := p.unwrapLeftoverWrappedToken(token0, wrappedAmount, safeConvertToInt64(amount0), caller); err != nil {
		panic(err)
	}
	if err := p.unwrapLeftoverWrappedToken(token1, wrappedAmount, safeConvertToInt64(amount1), caller); err != nil {
		panic(err)
	}

	tickCumulative, liquidityCumulative, secondsPerLiquidityCumulativeX128, observationTimestamp :=
		pl.GetObservation(poolPath, 0)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
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
		"positionLiquidity", p.GetPositionLiquidity(positionId).ToString(),
		"token0Balance", pl.GetBalanceToken0(poolPath),
		"token1Balance", pl.GetBalanceToken1(poolPath),
		"tickCumulative", formatInt(tickCumulative),
		"liquidityCumulative", liquidityCumulative,
		"secondsPerLiquidityCumulativeX128", secondsPerLiquidityCumulativeX128,
		"observationTimestamp", formatInt(observationTimestamp),
	)

	return positionId, liquidity.ToString(), amount0.ToString(), amount1.ToString(), poolPath
}

// unwrapLeftoverWrappedToken unwraps leftover wrapped tokens to native tokens.
func (p *positionV1) unwrapLeftoverWrappedToken(token string, wrapped, amount int64, caller address) error {
	unwrappable := isWrappedToken(token) && wrapped > amount
	if !unwrappable {
		return nil
	}

	err := p.unwrap(wrapped-amount, caller)
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
func (p *positionV1) DecreaseLiquidity(
	positionId uint64,
	liquidityStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
	unwrapResult bool,
) (uint64, string, string, string, string, string, string) {
	halt.AssertIsNotHaltedPositionWithVersion(1)
	halt.AssertIsNotHaltedWithdrawWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	assertIsOwnerForToken(p, positionId, caller)
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

	positionId, liquidity, fee0, fee1, amount0, amount1, poolPath, err := p.decreaseLiquidity(decreaseLiquidityParams)
	if err != nil {
		panic(err)
	}

	tickCumulative, liquidityCumulative, secondsPerLiquidityCumulativeX128, observationTimestamp :=
		pl.GetObservation(poolPath, 0)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
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
		"positionLiquidity", p.GetPositionLiquidity(positionId).ToString(),
		"token0Balance", pl.GetBalanceToken0(poolPath),
		"token1Balance", pl.GetBalanceToken1(poolPath),
		"tickCumulative", formatInt(tickCumulative),
		"liquidityCumulative", liquidityCumulative,
		"secondsPerLiquidityCumulativeX128", secondsPerLiquidityCumulativeX128,
		"observationTimestamp", formatInt(observationTimestamp),
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
func (p *positionV1) CollectFee(
	positionId uint64,
	unwrapResult bool,
) (uint64, string, string, string, string, string) {
	halt.AssertIsNotHaltedPositionWithVersion(1)
	halt.AssertIsNotHaltedWithdrawWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	assertIsOwnerOrOperatorForToken(p, positionId, caller)

	return p.collectFee(positionId, unwrapResult, caller)
}

// collectFee performs fee collection and withdrawal fee calculation.
func (p *positionV1) collectFee(
	positionId uint64,
	unwrapResult bool,
	caller address,
) (uint64, string, string, string, string, string) {
	emission.MintAndDistributeGns(cross)

	// verify position
	position := p.mustGetPosition(positionId)
	token0, token1, fee := splitOf(position.PoolKey())

	pl.Burn(
		cross,
		token0,
		token1,
		fee,
		position.TickLower(),
		position.TickUpper(),
		ZERO_LIQUIDITY_FOR_FEE_COLLECTION, // burn '0' liquidity to collect fee
		caller,
	)

	currentFeeGrowth, err := p.getCurrentFeeGrowth(position, caller)
	if err != nil {
		panic(newErrorWithDetail(err, "failed to get current fee growth"))
	}

	tokensOwed0, tokensOwed1 := p.calculateFees(position, currentFeeGrowth)

	position.SetFeeGrowthInside0LastX128(u256.Zero().Set(currentFeeGrowth.feeGrowthInside0LastX128))
	position.SetFeeGrowthInside1LastX128(u256.Zero().Set(currentFeeGrowth.feeGrowthInside1LastX128))

	// collect fee
	amount0, amount1 := pl.Collect(
		cross,
		token0, token1, fee,
		caller,
		position.TickLower(), position.TickUpper(),
		tokensOwed0.ToString(), tokensOwed1.ToString(),
	)

	// sometimes there will be a few less uBase amount than expected due to rounding down in core, but we just subtract the full amount expected
	// instead of the actual amount so we can burn the token
	tokensOwed0Updated, underflow := u256.Zero().SubOverflow(tokensOwed0, u256.MustFromDecimal(amount0))
	if underflow {
		panic(newErrorWithDetail(errUnderflow, "tokensOwed0 - amount0 underflow"))
	}
	position.SetTokensOwed0(tokensOwed0Updated)

	tokensOwed1Updated, underflow := u256.Zero().SubOverflow(tokensOwed1, u256.MustFromDecimal(amount1))
	if underflow {
		panic(newErrorWithDetail(errUnderflow, "tokensOwed1 - amount1 underflow"))
	}
	position.SetTokensOwed1(tokensOwed1Updated)
	p.mustUpdatePosition(positionId, *position)

	withdrawalFeeBps := pl.GetWithdrawalFee()
	amount0WithoutFee, fee0 := calculateAmountWithWithdrawalFee(amount0, withdrawalFeeBps)
	amount1WithoutFee, fee1 := calculateAmountWithWithdrawalFee(amount1, withdrawalFeeBps)

	poolAddr, ok := access.GetAddressWithVersion(prabc.ROLE_POOL.String(), 1)
	if !ok {
		panic("pool address not found")
	}

	if isWrappedToken(token0) && unwrapResult {
		p.unwrapWithTransferFrom(poolAddr, caller, amount0WithoutFee)
	} else {
		common.SafeGRC20TransferFrom(cross, token0, poolAddr, caller, amount0WithoutFee)
	}

	if isWrappedToken(token1) && unwrapResult {
		p.unwrapWithTransferFrom(poolAddr, caller, amount1WithoutFee)
	} else {
		common.SafeGRC20TransferFrom(cross, token1, poolAddr, caller, amount1WithoutFee)
	}

	protocolFeeAddr, ok := access.GetAddressWithVersion(prabc.ROLE_PROTOCOL_FEE.String(), 1)
	if !ok {
		panic("protocol fee address not found")
	}

	// handle withdrawal protocol fee
	pf.AddToProtocolFee(cross, token0, fee0)
	common.SafeGRC20TransferFrom(cross, token0, poolAddr, protocolFeeAddr, fee0)

	pf.AddToProtocolFee(cross, token1, fee1)
	common.SafeGRC20TransferFrom(cross, token1, poolAddr, protocolFeeAddr, fee1)

	amount0WithoutFeeStr := formatInt(amount0WithoutFee)
	amount1WithoutFeeStr := formatInt(amount1WithoutFee)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"CollectSwapFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpPositionId", formatUint(positionId),
		"feeAmount0", amount0WithoutFeeStr,
		"feeAmount1", amount1WithoutFeeStr,
		"poolPath", position.PoolKey(),
		"unwrapResult", formatBool(unwrapResult),
	)

	chain.Emit(
		"WithdrawalFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpTokenId", formatUint(positionId),
		"poolPath", position.PoolKey(),
		"feeAmount0", formatInt(fee0),
		"feeAmount1", formatInt(fee1),
		"amount0WithoutFee", amount0WithoutFeeStr,
		"amount1WithoutFee", amount1WithoutFeeStr,
	)

	return positionId, amount0WithoutFeeStr, amount1WithoutFeeStr, position.PoolKey(), amount0, amount1
}

var feeAmountDivisor = u256.NewUint(10000)

// calculateAmountWithWithdrawalFee calculates amount after deducting withdrawal fee.
func calculateAmountWithWithdrawalFee(amount string, fee uint64) (int64, int64) {
	if fee == 0 {
		return safeConvertToInt64(u256.MustFromDecimal(amount)), 0
	}

	amountUint := u256.MustFromDecimal(amount)
	feeUint := u256.NewUint(fee)

	feeAmount, overflow := u256.Zero().MulOverflow(amountUint, feeUint)
	if overflow {
		panic(errOverflow)
	}
	feeAmount = u256.Zero().Div(feeAmount, feeAmountDivisor)
	amountWithoutFee := u256.Zero().Sub(amountUint, feeAmount)

	return safeConvertToInt64(amountWithoutFee), safeConvertToInt64(feeAmount)
}

// SetPositionOperator sets an operator for a position.
// Only staker can call this function.
func (p *positionV1) SetPositionOperator(
	id uint64,
	operator address,
) {
	halt.AssertIsNotHaltedPositionWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	access.AssertIsStakerWithVersion(1, caller)

	position := p.mustGetPosition(id)
	position.SetOperator(operator)

	p.mustUpdatePosition(id, *position)
}

// getCurrentFeeGrowth retrieves current fee growth values for a position.
func (p *positionV1) getCurrentFeeGrowth(position *position.Position, owner address) (FeeGrowthInside, error) {
	positionKey := computePositionKey(position.TickLower(), position.TickUpper())
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pl.GetPositionFeeGrowthInsideLastX128(position.PoolKey(), positionKey)

	feeGrowthInside := FeeGrowthInside{
		feeGrowthInside0LastX128: feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: feeGrowthInside1LastX128,
	}

	return feeGrowthInside, nil
}

// computePositionKey generates a unique base64-encoded key for a liquidity position.
func computePositionKey(
	tickLower int32,
	tickUpper int32,
) string {
	currentRealmPath := runtime.CurrentRealm().PkgPath()
	key := ufmt.Sprintf("%s__%d__%d", currentRealmPath, tickLower, tickUpper)
	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}
