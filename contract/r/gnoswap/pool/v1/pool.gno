package v1

import (
	"chain"
	"chain/runtime"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
	pl "gno.land/r/gnoswap/pool"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

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
//   - recipient: Position owner address
//   - tickLower, tickUpper: Price range boundaries (must be tick-aligned)
//   - liquidityAmount: Liquidity to add (Q128 format)
//   - positionCaller: Original caller for token transfers
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
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string,
	positionCaller address,
) (string, string) {
	halt.AssertIsNotHaltedPool()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsPosition(caller)
	access.AssertIsValidAddress(positionCaller)

	liquidity := u256.MustFromDecimal(liquidityAmount)
	if liquidity.IsZero() {
		panic(errZeroLiquidity)
	}

	pool := i.mustGetPoolBy(token0Path, token1Path, fee)

	tickSpacing := pool.TickSpacing()
	checkTickSpacing(tickLower, tickSpacing)
	checkTickSpacing(tickUpper, tickSpacing)

	liquidityDelta := safeConvertToInt128(liquidity)
	positionParam := newModifyPositionParams(positionCaller, tickLower, tickUpper, liquidityDelta)
	_, amount0, amount1, err := modifyPosition(pool, positionParam)
	if err != nil {
		panic(err)
	}

	poolAddr := access.MustGetAddress(prabc.ROLE_POOL.String())

	if amount0.Gt(zero) {
		i.safeTransferFrom(pool, positionCaller, poolAddr, pool.Token0Path(), amount0, true)
	}

	if amount1.Gt(zero) {
		i.safeTransferFrom(pool, positionCaller, poolAddr, pool.Token1Path(), amount1, false)
	}

	// Save pool state after modifyPosition may have updated liquidity
	err = i.savePool(pool)
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
//   - amount0: Token0 owed to position (uint256)
//   - amount1: Token1 owed to position (uint256)
//
// Note: Tokens remain in pool until Collect is called.
// Only callable by position contract.
func (i *poolV1) Burn(
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string, // uint128
	positionCaller address,
) (string, string) {
	halt.AssertIsNotHaltedPool()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsPosition(caller)
	access.AssertIsValidAddress(positionCaller)

	liqAmount := u256.MustFromDecimal(liquidityAmount)
	liqAmountInt256 := safeConvertToInt128(liqAmount)
	liqDelta := i256.Zero().Neg(liqAmountInt256)

	posParams := newModifyPositionParams(positionCaller, tickLower, tickUpper, liqDelta)
	pool := i.mustGetPoolBy(token0Path, token1Path, fee)
	position, amount0, amount1, err := modifyPosition(pool, posParams)
	if err != nil {
		panic(err)
	}

	if amount0.Gt(zero) || amount1.Gt(zero) {
		amount0 = toUint128(amount0)
		amount1 = toUint128(amount1)

		tokensOwed0, overflow := u256.Zero().AddOverflow(position.TokensOwed0(), amount0)
		if overflow {
			panic(errOverflow)
		}
		position.SetTokensOwed0(tokensOwed0)

		tokensOwed1, overflow := u256.Zero().AddOverflow(position.TokensOwed1(), amount1)
		if overflow {
			panic(errOverflow)
		}
		position.SetTokensOwed1(tokensOwed1)
	}

	positionKey, err := getPositionKey(tickLower, tickUpper)
	if err != nil {
		panic(err)
	}

	setPosition(pool, positionKey, position)
	mustGetPositionByPool(pool, positionKey)

	// Save pool state after modifyPosition may have updated liquidity
	err = i.savePool(pool)
	if err != nil {
		panic(err)
	}

	// actual token transfer happens in Collect()
	return amount0.ToString(), amount1.ToString()
}

// Collect transfers owed tokens from a position to recipient.
//
// Claims tokens from burned liquidity and accumulated fees.
// Applies protocol withdrawal fee (1% default) before transfer.
// Supports partial collection via amount limits.
//
// Parameters:
//   - token0Path, token1Path: Token contract paths
//   - fee: Fee tier of the pool
//   - recipient: Address to receive tokens
//   - tickLower, tickUpper: Position's price range
//   - amount0Requested, amount1Requested: Max amounts to collect (use MAX_UINT128 for all)
//
// Returns:
//   - amount0: Token0 actually collected (after fees)
//   - amount1: Token1 actually collected (after fees)
//
// Protocol fees: 1% on collected amounts.
// Only callable by position contract.
func (i *poolV1) Collect(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	halt.AssertIsNotHaltedPool()
	halt.AssertIsNotHaltedWithdraw()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsPosition(caller)
	access.AssertIsValidAddress(recipient)

	pool := i.mustGetPoolBy(token0Path, token1Path, fee)
	// Generate position key by combining position contract path with tick range
	// The key is composed of the position contract's address and the tick boundaries,
	// allowing the pool to uniquely identify and access position data.
	positionKey, err := getPositionKey(tickLower, tickUpper)
	if err != nil {
		panic(err)
	}

	position := mustGetPositionByPool(pool, positionKey)

	var amount0, amount1 *u256.Uint

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount0Req := u256.MustFromDecimal(amount0Requested)
	amount0 = collectToken(amount0Req, position.TokensOwed0(), pool.BalanceToken0())

	amount1Req := u256.MustFromDecimal(amount1Requested)
	amount1 = collectToken(amount1Req, position.TokensOwed1(), pool.BalanceToken1())

	positionAddr := access.MustGetAddress(prabc.ROLE_POSITION.String())

	if amount0.Gt(u256.Zero()) {
		tokenOwed0, overflow := u256.Zero().SubOverflow(position.TokensOwed0(), amount0)
		if overflow {
			panic(errOverflow)
		}

		token0Balance, overflow := u256.Zero().SubOverflow(pool.BalanceToken0(), amount0)
		if overflow {
			panic(errOverflow)
		}

		position.SetTokensOwed0(tokenOwed0)
		pool.SetBalanceToken0(token0Balance)
		common.SafeGRC20Approve(cross, pool.Token0Path(), positionAddr, safeConvertToInt64(amount0))
	}
	if amount1.Gt(u256.Zero()) {
		tokenOwed1, overflow := u256.Zero().SubOverflow(position.TokensOwed1(), amount1)
		if overflow {
			panic(errOverflow)
		}

		token1Balance, overflow := u256.Zero().SubOverflow(pool.BalanceToken1(), amount1)
		if overflow {
			panic(errOverflow)
		}

		position.SetTokensOwed1(tokenOwed1)
		pool.SetBalanceToken1(token1Balance)
		common.SafeGRC20Approve(cross, pool.Token1Path(), positionAddr, safeConvertToInt64(amount1))
	}

	setPosition(pool, positionKey, *position)

	err = i.savePool(pool)
	if err != nil {
		panic(err)
	}

	return amount0.ToString(), amount1.ToString()
}

// collectToken calculates the actual amount of tokens that can be collected.
// It returns the minimum of: requested amount, tokens owed, and pool balance.
// This ensures collection never exceeds available funds.
func collectToken(
	amountReq, tokensOwed, poolBalance *u256.Uint,
) (amount *u256.Uint) {
	// find smallest of three amounts
	amount = u256Min(amountReq, tokensOwed)
	amount = u256Min(amount, poolBalance)
	return amount.Clone()
}

// CollectProtocol collects accumulated protocol fees from swap operations.
// Only callable by admin or governance.
// Returns amount0, amount1 representing protocol fees collected.
func (i *poolV1) CollectProtocol(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	amount0Requested string, // uint128
	amount1Requested string, // uint128
) (string, string) {
	halt.AssertIsNotHaltedPool()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	common.MustRegistered(token0Path, token1Path)

	amount0, amount1 := i.collectProtocol(
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
		"fee", formatUint(fee),
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
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	pool := i.mustGetPoolBy(token0Path, token1Path, fee)

	amount0Req := u256.MustFromDecimal(amount0Requested)
	amount1Req := u256.MustFromDecimal(amount1Requested)
	if amount0Req.IsZero() && amount1Req.IsZero() {
		return "0", "0"
	}

	amount0 := u256Min(amount0Req, pool.ProtocolFeesToken0())
	amount1 := u256Min(amount1Req, pool.ProtocolFeesToken1())

	amount0, amount1 = i.saveProtocolFees(pool, amount0.Clone(), amount1.Clone())
	uAmount0 := safeConvertToInt64(amount0)
	uAmount1 := safeConvertToInt64(amount1)

	common.SafeGRC20Transfer(cross, pool.Token0Path(), recipient, uAmount0)
	newBalanceToken0, err := updatePoolBalance(pool.BalanceToken0(), pool.BalanceToken1(), amount0, true)
	if err != nil {
		panic(err)
	}
	pool.SetBalanceToken0(newBalanceToken0)

	common.SafeGRC20Transfer(cross, pool.Token1Path(), recipient, uAmount1)
	newBalanceToken1, err := updatePoolBalance(pool.BalanceToken0(), pool.BalanceToken1(), amount1, false)
	if err != nil {
		panic(err)
	}
	pool.SetBalanceToken1(newBalanceToken1)

	err = i.savePool(pool)
	if err != nil {
		panic(err)
	}

	return amount0.ToString(), amount1.ToString()
}

// saveProtocolFees updates the protocol fee balances after collection.
// Returns amount0, amount1 representing the fees deducted from protocol reserves.
func (i *poolV1) saveProtocolFees(pool *pl.Pool, amount0, amount1 *u256.Uint) (*u256.Uint, *u256.Uint) {
	token0Fees, underflow := u256.Zero().SubOverflow(pool.ProtocolFeesToken0(), amount0)
	if underflow {
		panic(errOverflow)
	}
	pool.SetProtocolFeesToken0(token0Fees)

	token1Fees, underflow := u256.Zero().SubOverflow(pool.ProtocolFeesToken1(), amount1)
	if underflow {
		panic(errUnderflow)
	}
	pool.SetProtocolFeesToken1(token1Fees)

	return amount0, amount1
}

func (i *poolV1) IncreaseObservationCardinalityLimit(
	token0Path string,
	token1Path string,
	fee uint32,
	cardinalityNext uint16,
) {
	halt.AssertIsNotHaltedPool()

	pool := i.mustGetPoolBy(token0Path, token1Path, fee)
	err := increaseObservationCardinalityLimitByPool(pool, cardinalityNext)
	if err != nil {
		panic(err)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"IncreaseObservationCardinalityLimit",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", pool.PoolPath(),
		"cardinalityNext", formatUint(cardinalityNext),
	)
}
