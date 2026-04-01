package v1

import (
	"chain"
	"chain/runtime"

	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	pl "gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/referral"
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
	halt.AssertIsNotHaltedPosition()

	previousRealm := runtime.PreviousRealm()
	prevRealmAddr := previousRealm.Address()
	if !previousRealm.IsUser() {
		access.AssertIsStaker(prevRealmAddr)
	} else {
		assertEqualsAddress(prevRealmAddr, mintTo)
		assertEqualsAddress(prevRealmAddr, caller)
	}

	assertValidNumberString(amount0Desired)
	assertValidNumberString(amount1Desired)
	assertValidNumberString(amount0Min)
	assertValidNumberString(amount1Min)

	// assert that the user has sent the correct amount of native coin
	common.AssertIsNotHandleNativeCoin()
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

	poolSqrtPriceX96 := pl.GetSlot0SqrtPriceX96(processedInput.poolPath)

	tickCumulative, liquidityCumulative, secondsPerLiquidityCumulativeX128, observationTimestamp := pl.GetObservation(processedInput.poolPath, 0)

	chain.Emit(
		"Mint",
		"prevAddr", prevRealmAddr.String(),
		"prevRealm", previousRealm.PkgPath(),
		"tickLower", formatInt(processedInput.tickLower),
		"tickUpper", formatInt(processedInput.tickUpper),
		"poolPath", processedInput.poolPath,
		"mintTo", mintTo.String(),
		"caller", caller.String(),
		"lpPositionId", formatUint(id),
		"liquidityDelta", liquidity.ToString(),
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
		"sqrtPriceX96", poolSqrtPriceX96,
		"positionLiquidity", p.GetPositionLiquidity(id),
		"poolLiquidity", pl.GetLiquidity(processedInput.poolPath),
		"token0Balance", formatInt(pl.GetBalanceToken0(processedInput.poolPath)),
		"token1Balance", formatInt(pl.GetBalanceToken1(processedInput.poolPath)),
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
//   - liquidity: Liquidity amount added (the delta, not total)
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
	halt.AssertIsNotHaltedPosition()

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

	common.AssertIsNotHandleNativeCoin()

	err := validateTokenPath(token0, token1)
	if err != nil {
		panic(newErrorWithDetail(err, ufmt.Sprintf("token0(%s), token1(%s)", token0, token1)))
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

	tickCumulative, liquidityCumulative, secondsPerLiquidityCumulativeX128, observationTimestamp := pl.GetObservation(poolPath, 0)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"IncreaseLiquidity",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"caller", caller.String(),
		"lpPositionId", formatUint(positionId),
		"liquidityDelta", liquidity.ToString(),
		"amount0", amount0.ToString(),
		"amount1", amount1.ToString(),
		"sqrtPriceX96", pl.GetSlot0SqrtPriceX96(poolPath),
		"positionLiquidity", p.GetPositionLiquidity(positionId),
		"poolLiquidity", pl.GetLiquidity(poolPath),
		"token0Balance", formatInt(pl.GetBalanceToken0(poolPath)),
		"token1Balance", formatInt(pl.GetBalanceToken1(poolPath)),
		"tickCumulative", formatInt(tickCumulative),
		"liquidityCumulative", liquidityCumulative,
		"secondsPerLiquidityCumulativeX128", secondsPerLiquidityCumulativeX128,
		"observationTimestamp", formatInt(observationTimestamp),
	)

	return positionId, liquidity.ToString(), amount0.ToString(), amount1.ToString(), poolPath
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
//
// Returns:
//   - positionId: Same NFT ID
//   - liquidity: Amount of liquidity removed (the delta)
//   - fee0, fee1: Fees collected
//   - amount0, amount1: Principal collected
//   - poolPath: Pool identifier
//
// Note: Applies withdrawal fee on collected amounts.
func (p *positionV1) DecreaseLiquidity(
	positionId uint64,
	liquidityStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, string, string, string, string, string) {
	halt.AssertIsNotHaltedWithdraw()

	caller := runtime.PreviousRealm().Address()
	assertIsOwnerForToken(p, positionId, caller)
	assertIsNotExpired(deadline)
	assertValidLiquidityAmount(liquidityStr)

	emission.MintAndDistributeGns(cross)

	amount0Min := u256.MustFromDecimal(amount0MinStr)
	amount1Min := u256.MustFromDecimal(amount1MinStr)
	decreaseLiquidityParams := DecreaseLiquidityParams{
		positionId: positionId,
		liquidity:  liquidityStr,
		amount0Min: amount0Min,
		amount1Min: amount1Min,
		deadline:   deadline,
		caller:     caller,
	}

	positionId, liquidity, fee0, fee1, amount0, amount1, poolPath, err := p.decreaseLiquidity(decreaseLiquidityParams)
	if err != nil {
		panic(err)
	}

	tickCumulative, liquidityCumulative, secondsPerLiquidityCumulativeX128, observationTimestamp := pl.GetObservation(poolPath, 0)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"DecreaseLiquidity",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpPositionId", formatUint(positionId),
		"poolPath", poolPath,
		"liquidityDelta", liquidity,
		"feeAmount0", fee0,
		"feeAmount1", fee1,
		"amount0", amount0,
		"amount1", amount1,
		"sqrtPriceX96", pl.GetSlot0SqrtPriceX96(poolPath),
		"positionLiquidity", p.GetPositionLiquidity(positionId),
		"poolLiquidity", pl.GetLiquidity(poolPath),
		"token0Balance", formatInt(pl.GetBalanceToken0(poolPath)),
		"token1Balance", formatInt(pl.GetBalanceToken1(poolPath)),
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
//
// Returns:
//   - positionId: Same NFT ID
//   - tokensCollected0: Token0 amount sent to caller (after withdrawal fee)
//   - tokensCollected1: Token1 amount sent to caller (after withdrawal fee)
//   - poolPath: Pool identifier
//   - totalAmount0: Raw token0 collected (before withdrawal fee)
//   - totalAmount1: Raw token1 collected (before withdrawal fee)
//
// Requirements:
//   - Caller must be owner or approved operator
//   - Position must have accumulated fees
func (p *positionV1) CollectFee(positionId uint64) (uint64, string, string, string, string, string) {
	halt.AssertIsNotHaltedWithdraw()

	caller := runtime.PreviousRealm().Address()
	assertIsOwnerOrOperatorForToken(p, positionId, caller)

	emission.MintAndDistributeGns(cross)

	return p.collectFee(positionId, caller)
}

// collectFee performs fee collection and withdrawal fee calculation.
func (p *positionV1) collectFee(positionId uint64, caller address) (uint64, string, string, string, string, string) {
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
		"0", // burn '0' liquidity to collect fee
		caller,
	)

	currentFeeGrowth, err := p.getCurrentFeeGrowth(position, caller)
	if err != nil {
		panic(newErrorWithDetail(err, "failed to get current fee growth"))
	}

	tokensOwed0, tokensOwed1 := p.calculateFees(position, currentFeeGrowth)

	position.SetFeeGrowthInside0LastX128(currentFeeGrowth.feeGrowthInside0LastX128.ToString())
	position.SetFeeGrowthInside1LastX128(currentFeeGrowth.feeGrowthInside1LastX128.ToString())

	// collect fee
	amount0, amount1 := pl.Collect(
		cross,
		token0, token1, fee,
		caller,
		position.TickLower(), position.TickUpper(),
		formatInt(tokensOwed0), formatInt(tokensOwed1),
	)
	amount0Uint256 := u256.MustFromDecimal(amount0)
	amount1Uint256 := u256.MustFromDecimal(amount1)
	amount0Int64 := safeConvertToInt64(amount0Uint256)
	amount1Int64 := safeConvertToInt64(amount1Uint256)

	// sometimes there will be a few less uBase amount than expected due to rounding down in core, but we just subtract the full amount expected
	// instead of the actual amount so we can burn the token
	if tokensOwed0 < amount0Int64 {
		panic(newErrorWithDetail(errUnderflow, "tokensOwed0 - amount0 underflow"))
	}
	position.SetTokensOwed0(safeSubInt64(tokensOwed0, amount0Int64))

	if tokensOwed1 < amount1Int64 {
		panic(newErrorWithDetail(errUnderflow, "tokensOwed1 - amount1 underflow"))
	}
	position.SetTokensOwed1(safeSubInt64(tokensOwed1, amount1Int64))
	p.mustUpdatePosition(positionId, *position)

	fee0Str, fee1Str, amount0WithoutFeeStr, amount1WithoutFeeStr := pl.HandleWithdrawalFee(
		cross,
		token0, amount0,
		token1, amount1,
		caller,
	)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"CollectSwapFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpPositionId", formatUint(positionId),
		"feeAmount0", amount0WithoutFeeStr,
		"feeAmount1", amount1WithoutFeeStr,
		"poolPath", position.PoolKey(),
		"feeGrowthInside0LastX128", position.FeeGrowthInside0LastX128(),
		"feeGrowthInside1LastX128", position.FeeGrowthInside1LastX128(),
	)

	chain.Emit(
		"WithdrawalFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpTokenId", formatUint(positionId),
		"poolPath", position.PoolKey(),
		"feeAmount0", fee0Str,
		"feeAmount1", fee1Str,
		"amount0WithoutFee", amount0WithoutFeeStr,
		"amount1WithoutFee", amount1WithoutFeeStr,
	)

	return positionId, amount0WithoutFeeStr, amount1WithoutFeeStr, position.PoolKey(), amount0, amount1
}

// SetPositionOperator sets an operator for a position.
// Only staker can call this function.
func (p *positionV1) SetPositionOperator(id uint64, operator address) {
	if operator != address("") {
		halt.AssertIsNotHaltedPosition()
	}

	access.AssertIsStaker(runtime.PreviousRealm().Address())

	assertValidOperatorAddress(operator)

	position := p.mustGetPosition(id)
	prevOperator := position.Operator()
	position.SetOperator(operator)

	p.mustUpdatePosition(id, *position)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"SetPositionOperator",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"lpPositionId", formatUint(id),
		"prevOperator", prevOperator.String(),
		"newOperator", operator.String(),
	)
}

// getCurrentFeeGrowth retrieves current fee growth values for a position.
func (p *positionV1) getCurrentFeeGrowth(position *position.Position, owner address) (FeeGrowthInside, error) {
	positionKey := computePositionKey(position.TickLower(), position.TickUpper())
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pl.GetPositionFeeGrowthInsideLastX128(position.PoolKey(), positionKey)

	feeGrowthInside := FeeGrowthInside{
		feeGrowthInside0LastX128: u256.MustFromDecimal(feeGrowthInside0LastX128),
		feeGrowthInside1LastX128: u256.MustFromDecimal(feeGrowthInside1LastX128),
	}

	return feeGrowthInside, nil
}

// computePositionKey generates a compact deterministic key for a liquidity position.
func computePositionKey(tickLower, tickUpper int32) string {
	return pl.EncodePositionKey(tickLower, tickUpper)
}

// calculatePositionBalances computes token balances for a position at current price.
// Returns calculated token0 and token1 balances based on position liquidity and price range.
func calculatePositionBalances(position *position.Position) (int64, int64) {
	liquidity := u256.MustFromDecimal(position.Liquidity())
	if liquidity.IsZero() {
		return 0, 0
	}

	token0Balance, token1Balance := common.GetAmountsForLiquidity(
		u256.MustFromDecimal(pl.GetSlot0SqrtPriceX96(position.PoolKey())), // currentSqrtPriceX96
		common.TickMathGetSqrtRatioAtTick(position.TickLower()),
		common.TickMathGetSqrtRatioAtTick(position.TickUpper()),
		liquidity,
	)

	return safeConvertToInt64(token0Balance), safeConvertToInt64(token1Balance)
}
