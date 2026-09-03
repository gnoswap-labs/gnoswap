package pool

import (
	"chain"
	"errors"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
	pl "gno.land/r/gnoswap/pool"

	"gno.land/p/gnoswap/gnsmath"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/gnoswap/utils"
	ufmt "gno.land/p/nt/ufmt/v0"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

// Mint adds liquidity to a pool position.
//
// Increases liquidity for a position within specified tick range.
// Calculates required token amounts based on current pool price.
// Updates tick state and transfers tokens atomically.
//
// Parameters:
//   - token0Path, token1Path: Token contract paths
//   - fee: Fee tier (100, 500, 3000, 10000 = 0.01%, 0.05%, 0.3%, 1%)
//   - tickLower, tickUpper: Price range boundaries (must be tick-aligned)
//   - liquidityAmount: Liquidity to add (decimal string)
//   - positionCaller: Address that provides tokens for the mint operation
//
// Returns:
//   - amount0: Token0 amount consumed (decimal string)
//   - amount1: Token1 amount consumed (decimal string)
//
// Requirements:
//   - Pool must exist for token pair and fee
//   - Liquidity amount must be positive
//   - Ticks must be valid and aligned to spacing
//
// Only callable by position contract.
func (i *poolV1) Mint(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string,
	positionCaller address,
) (string, string) {
	access.AssertIsRlmCurrent(0, rlm)

	i.assertPoolUnlocked()
	halt.AssertIsNotHaltedPool()

	caller := rlm.Previous().Address()
	access.AssertIsPosition(caller)
	access.AssertIsValidAddress(positionCaller)

	i.lockPool(0, rlm)
	defer i.unlockPool(0, rlm)

	liquidity := u256.MustFromDecimal(liquidityAmount)
	if liquidity.IsZero() {
		panic(errors.New(errZeroLiquidity))
	}

	pool := i.mustGetPoolBy(token0Path, token1Path, fee)

	tickSpacing := pool.TickSpacing()
	checkTickSpacing(tickLower, tickSpacing)
	checkTickSpacing(tickUpper, tickSpacing)

	liquidityDelta := gnsmath.SafeConvertToInt128(liquidity)
	positionParam := newModifyPositionParams(positionCaller, tickLower, tickUpper, liquidityDelta)
	_, amount0, amount1, err := modifyPosition(pool, positionParam)
	if err != nil {
		panic(err)
	}

	poolAddr := access.MustGetAddress(prabc.ROLE_POOL.String())

	if amount0.Gt(u256.Zero()) {
		i.safeTransferFrom(0, rlm, pool, positionCaller, poolAddr, pool.Token0Path(), amount0, true)
	}

	if amount1.Gt(u256.Zero()) {
		i.safeTransferFrom(0, rlm, pool, positionCaller, poolAddr, pool.Token1Path(), amount1, false)
	}

	// Save pool state after modifyPosition may have updated liquidity
	err = i.savePool(0, rlm, pool)
	if err != nil {
		panic(err)
	}

	return amount0.ToString(), amount1.ToString()
}

// Burn removes liquidity from a position.
//
// Decreases liquidity and calculates tokens owed to position owner.
// Updates tick state but doesn't transfer tokens (use Collect).
// Two-step process prevents reentrancy attacks.
//
// Parameters:
//   - token0Path, token1Path: Token contract paths
//   - fee: Fee tier matching the pool
//   - tickLower, tickUpper: Position's price range
//   - liquidityAmount: Liquidity to remove (uint128)
//   - positionCaller: Position owner for validation
//
// Returns:
//   - amount0: Token0 owed to position (decimal string)
//   - amount1: Token1 owed to position (decimal string)
//
// Note: Tokens remain in pool until Collect is called.
// Only callable by position contract.
func (i *poolV1) Burn(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string, // uint128
	positionCaller address,
) (string, string) {
	access.AssertIsRlmCurrent(0, rlm)

	i.assertPoolUnlocked()
	halt.AssertIsNotHaltedWithdraw()

	caller := rlm.Previous().Address()
	access.AssertIsPosition(caller)
	access.AssertIsValidAddress(positionCaller)

	i.lockPool(0, rlm)
	defer i.unlockPool(0, rlm)

	liqAmount := u256.MustFromDecimal(liquidityAmount)
	liqAmountInt256 := gnsmath.SafeConvertToInt128(liqAmount)
	liqDelta := i256.Zero().Neg(liqAmountInt256)

	posParams := newModifyPositionParams(positionCaller, tickLower, tickUpper, liqDelta)
	pool := i.mustGetPoolBy(token0Path, token1Path, fee)
	position, amount0, amount1, err := modifyPosition(pool, posParams)
	if err != nil {
		panic(err)
	}

	if amount0.Gt(u256.Zero()) || amount1.Gt(u256.Zero()) {
		amount0 = toUint128(amount0)
		amount1 = toUint128(amount1)

		position.SetTokensOwed0(gnsmath.SafeAddInt64(position.TokensOwed0(), gnsmath.SafeConvertToInt64(amount0)))
		position.SetTokensOwed1(gnsmath.SafeAddInt64(position.TokensOwed1(), gnsmath.SafeConvertToInt64(amount1)))
	}

	positionKey := getPositionKey(tickLower, tickUpper)

	setPosition(pool, positionKey, position)

	err = i.savePool(0, rlm, pool)
	if err != nil {
		panic(err)
	}

	// actual token transfer happens in Collect()
	return amount0.ToString(), amount1.ToString()
}

// CollectSwapFee pays out accrued swap fees for a position.
//
// The withdrawal fee is deducted from the collected amount and settled to the
// protocol fee realm; the remainder is transferred to recipient. Only accrued
// swap fees belong on this path - principal returned by Burn is not fee
// bearing and must go through Collect.
//
// Parameters:
//   - token0Path, token1Path: Token contract paths
//   - fee: Fee tier of the pool
//   - recipient: Address to receive tokens
//   - tickLower, tickUpper: Position's price range
//   - amount0Requested, amount1Requested: Max amounts to collect (use MAX_UINT128 for all)
//
// Returns:
//   - amount0, amount1: Collected amounts, before the withdrawal fee
//   - fee0, fee1: Withdrawal fee withheld from each amount
//
// Only callable by position contract.
func (i *poolV1) CollectSwapFee(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
) (amount0, amount1, fee0, fee1 string) {
	collected0, collected1, withheld0, withheld1 := i.collect(
		0, rlm,
		token0Path, token1Path, fee,
		recipient,
		tickLower, tickUpper,
		amount0Requested, amount1Requested,
		true,
	)

	return utils.FormatInt(collected0), utils.FormatInt(collected1),
		utils.FormatInt(withheld0), utils.FormatInt(withheld1)
}

// Collect pays out tokens owed to a position, transferring the full amount to
// recipient.
//
// No withdrawal fee is charged: this path carries principal credited by Burn,
// which the protocol does not tax. Accrued swap fees belong on CollectSwapFee.
//
// Parameters:
//   - token0Path, token1Path: Token contract paths
//   - fee: Fee tier of the pool
//   - recipient: Address to receive tokens
//   - tickLower, tickUpper: Position's price range
//   - amount0Requested, amount1Requested: Max amounts to collect (use MAX_UINT128 for all)
//
// Returns:
//   - amount0, amount1: Amounts transferred to recipient
//
// Only callable by position contract.
func (i *poolV1) Collect(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
) (amount0, amount1 string) {
	collected0, collected1, _, _ := i.collect(
		0, rlm,
		token0Path, token1Path, fee,
		recipient,
		tickLower, tickUpper,
		amount0Requested, amount1Requested,
		false,
	)

	return utils.FormatInt(collected0), utils.FormatInt(collected1)
}

// collect settles the pool ledger for a position and pays the recipient.
//
// The payout is capped by the position's tokensOwed, never by a caller
// supplied number, and the ledger is written before any token leaves the
// realm. Both happen under a single pool lock, so the pool's accounting and
// its token balance are never observably out of step.
//
// The collected amount is NOT capped by the pool's internal balance: a balance
// short of the owed amount means the internal ledger has drifted, so the call
// reverts rather than silently paying out less.
//
// applyWithdrawalFee selects the fee policy; pass false for a fee-free payout.
// It is the entry point, not the configured rate, that decides whether the
// protocol fee is settled: a rate of zero must still flush a backlog left
// pending by an earlier halted settlement.
func (i *poolV1) collect(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
	applyWithdrawalFee bool,
) (amount0, amount1, fee0, fee1 int64) {
	access.AssertIsRlmCurrent(0, rlm)

	i.assertPoolUnlocked()
	halt.AssertIsNotHaltedWithdraw()

	caller := rlm.Previous().Address()
	access.AssertIsPosition(caller)
	access.AssertIsValidAddress(recipient)

	i.lockPool(0, rlm)
	defer i.unlockPool(0, rlm)

	amount0Req := utils.SafeParseInt64(amount0Requested)
	amount1Req := utils.SafeParseInt64(amount1Requested)

	if amount0Req < 0 || amount1Req < 0 {
		panic(errors.New(errInvalidInput))
	}

	pool := i.mustGetPoolBy(token0Path, token1Path, fee)
	// Generate position key by combining position contract path with tick range
	// The key is composed of the position contract's address and the tick boundaries,
	// allowing the pool to uniquely identify and access position data.
	positionKey := getPositionKey(tickLower, tickUpper)
	position, err := pool.GetPosition(positionKey)
	if err != nil {
		panic(newErrorWithDetail(
			errDataNotFound,
			ufmt.Sprintf("positionKey(%s) does not exist", positionKey),
		))
	}

	amount0 = minRequestedAmount(amount0Req, position.TokensOwed0())
	amount1 = minRequestedAmount(amount1Req, position.TokensOwed1())

	if amount0 > 0 {
		tokenOwed0 := gnsmath.SafeSubInt64(position.TokensOwed0(), amount0)
		token0Balance, err := updatePoolBalance(pool.BalanceToken0(), pool.BalanceToken1(), amount0, true)
		if err != nil {
			panic(err)
		}

		position.SetTokensOwed0(tokenOwed0)
		pool.SetBalanceToken0(token0Balance)
	}
	if amount1 > 0 {
		tokenOwed1 := gnsmath.SafeSubInt64(position.TokensOwed1(), amount1)
		token1Balance, err := updatePoolBalance(pool.BalanceToken0(), pool.BalanceToken1(), amount1, false)
		if err != nil {
			panic(err)
		}

		position.SetTokensOwed1(tokenOwed1)
		pool.SetBalanceToken1(token1Balance)
	}

	setPosition(pool, positionKey, position)

	if err := i.savePool(0, rlm, pool); err != nil {
		panic(err)
	}

	withdrawalFeeBPS := ZeroBps
	if applyWithdrawalFee {
		withdrawalFeeBPS = i.store.GetWithdrawalFeeBPS()
	}

	// Effects are persisted above; everything below leaves the realm.
	fee0, amount0AfterFee := deductWithdrawalFee(amount0, withdrawalFeeBPS)
	fee1, amount1AfterFee := deductWithdrawalFee(amount1, withdrawalFeeBPS)

	if applyWithdrawalFee {
		// Called even for a zero fee, and for a zero withdrawal fee rate, so that
		// anything left pending for these tokens by an earlier halted settlement
		// is flushed.
		i.settleProtocolFee(0, rlm, token0Path, fee0)
		i.settleProtocolFee(0, rlm, token1Path, fee1)
	}

	if amount0AfterFee > 0 {
		common.SafeGRC20Transfer(0, rlm, token0Path, recipient, amount0AfterFee)
	}
	if amount1AfterFee > 0 {
		common.SafeGRC20Transfer(0, rlm, token1Path, recipient, amount1AfterFee)
	}

	return amount0, amount1, fee0, fee1
}

// CollectProtocol collects accumulated protocol fees from swap operations.
// Only callable by admin or governance.
// Returns amount0, amount1 representing protocol fees collected.
func (i *poolV1) CollectProtocol(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	amount0Requested string, // uint128
	amount1Requested string, // uint128
) (string, string) {
	access.AssertIsRlmCurrent(0, rlm)

	i.assertPoolUnlocked()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	common.MustRegistered(token0Path, token1Path)

	i.lockPool(0, rlm)
	defer i.unlockPool(0, rlm)

	amount0, amount1 := i.collectProtocol(
		0,
		rlm,
		token0Path,
		token1Path,
		fee,
		recipient,
		amount0Requested,
		amount1Requested,
	)

	chain.Emit(
		"CollectProtocol",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"token0Path", token0Path,
		"token1Path", token1Path,
		"fee", utils.FormatUint(fee),
		"recipient", recipient.String(),
		"internal_amount0", amount0,
		"internal_amount1", amount1,
	)

	return amount0, amount1
}

// collectProtocol performs the actual protocol fee collection.
// It ensures requested amounts don't exceed available protocol fees.
// Returns amount0, amount1 as strings representing collected fees.
func (i *poolV1) collectProtocol(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	pool := i.mustGetPoolBy(token0Path, token1Path, fee)

	amount0Req := utils.SafeParseInt64(amount0Requested)
	amount1Req := utils.SafeParseInt64(amount1Requested)

	if amount0Req < 0 || amount1Req < 0 {
		panic(errors.New(errInvalidInput))
	}

	amount0 := minRequestedAmount(amount0Req, pool.ProtocolFeesToken0())
	amount1 := minRequestedAmount(amount1Req, pool.ProtocolFeesToken1())

	amount0, amount1 = i.saveProtocolFees(pool, amount0, amount1)

	newBalanceToken0, err := updatePoolBalance(pool.BalanceToken0(), pool.BalanceToken1(), amount0, true)
	if err != nil {
		panic(err)
	}
	pool.SetBalanceToken0(newBalanceToken0)

	newBalanceToken1, err := updatePoolBalance(pool.BalanceToken0(), pool.BalanceToken1(), amount1, false)
	if err != nil {
		panic(err)
	}
	pool.SetBalanceToken1(newBalanceToken1)

	err = i.savePool(0, rlm, pool)
	if err != nil {
		panic(err)
	}

	common.SafeGRC20Transfer(0, rlm, pool.Token0Path(), recipient, amount0)
	common.SafeGRC20Transfer(0, rlm, pool.Token1Path(), recipient, amount1)

	return utils.FormatInt(amount0), utils.FormatInt(amount1)
}

// saveProtocolFees updates the protocol fee balances after collection.
// Returns amount0, amount1 representing the fees deducted from protocol reserves.
func (i *poolV1) saveProtocolFees(pool *pl.Pool, amount0, amount1 int64) (int64, int64) {
	if pool.ProtocolFeesToken0() < amount0 {
		panic(errors.New(errUnderflow))
	}
	pool.SetProtocolFeesToken0(gnsmath.SafeSubInt64(pool.ProtocolFeesToken0(), amount0))

	if pool.ProtocolFeesToken1() < amount1 {
		panic(errors.New(errUnderflow))
	}
	pool.SetProtocolFeesToken1(gnsmath.SafeSubInt64(pool.ProtocolFeesToken1(), amount1))

	return amount0, amount1
}

func minRequestedAmount(request, available int64) int64 {
	if request > available {
		return available
	}

	return request
}

func (i *poolV1) IncreaseObservationCardinalityNext(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	cardinalityNext uint16,
) {
	access.AssertIsRlmCurrent(0, rlm)

	i.assertPoolUnlocked()
	halt.AssertIsNotHaltedPool()

	pool := i.mustGetPoolBy(token0Path, token1Path, fee)

	i.lockPool(0, rlm)
	defer i.unlockPool(0, rlm)

	err := increaseObservationCardinalityNextByPool(pool, cardinalityNext)
	if err != nil {
		panic(err)
	}

	previousRealm := rlm.Previous()
	chain.Emit(
		"IncreaseObservationCardinalityNext",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", pool.PoolPath(),
		"cardinalityNext", utils.FormatUint(cardinalityNext),
	)
}
