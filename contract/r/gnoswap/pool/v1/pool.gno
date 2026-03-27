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
//   - amount0: Token0 owed to position (decimal string)
//   - amount1: Token1 owed to position (decimal string)
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

		position.SetTokensOwed0(safeAddInt64(position.TokensOwed0(), safeConvertToInt64(amount0)))
		position.SetTokensOwed1(safeAddInt64(position.TokensOwed1(), safeConvertToInt64(amount1)))
	}

	positionKey := getPositionKey(tickLower, tickUpper)

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
//   - amount0: Token0 amount transferred (before any withdrawal fees)
//   - amount1: Token1 amount transferred (before any withdrawal fees)
//
// Note: Withdrawal fees are applied by the position contract, not here.
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

	amount0Req := safeParseInt64(amount0Requested)
	amount1Req := safeParseInt64(amount1Requested)

	if amount0Req < 0 || amount1Req < 0 {
		panic(errInvalidInput)
	}

	pool := i.mustGetPoolBy(token0Path, token1Path, fee)
	// Generate position key by combining position contract path with tick range
	// The key is composed of the position contract's address and the tick boundaries,
	// allowing the pool to uniquely identify and access position data.
	positionKey := getPositionKey(tickLower, tickUpper)
	position := mustGetPositionByPool(pool, positionKey)

	amount0 := minRequestedAmount(amount0Req, position.TokensOwed0())
	amount1 := minRequestedAmount(amount1Req, position.TokensOwed1())

	positionAddr := access.MustGetAddress(prabc.ROLE_POSITION.String())

	if amount0 > 0 {
		tokenOwed0 := safeSubInt64(position.TokensOwed0(), amount0)
		token0Balance := safeSubInt64(pool.BalanceToken0(), amount0)

		position.SetTokensOwed0(tokenOwed0)
		pool.SetBalanceToken0(token0Balance)
		common.SafeGRC20Approve(cross, pool.Token0Path(), positionAddr, amount0)
	}
	if amount1 > 0 {
		tokenOwed1 := safeSubInt64(position.TokensOwed1(), amount1)
		token1Balance := safeSubInt64(pool.BalanceToken1(), amount1)

		position.SetTokensOwed1(tokenOwed1)
		pool.SetBalanceToken1(token1Balance)
		common.SafeGRC20Approve(cross, pool.Token1Path(), positionAddr, amount1)
	}

	setPosition(pool, positionKey, *position)

	if err := i.savePool(pool); err != nil {
		panic(err)
	}

	return formatInt(amount0), formatInt(amount1)
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

	amount0Req := safeParseInt64(amount0Requested)
	amount1Req := safeParseInt64(amount1Requested)

	if amount0Req < 0 || amount1Req < 0 {
		panic(errInvalidInput)
	}

	amount0 := minRequestedAmount(amount0Req, pool.ProtocolFeesToken0())
	amount1 := minRequestedAmount(amount1Req, pool.ProtocolFeesToken1())

	amount0, amount1 = i.saveProtocolFees(pool, amount0, amount1)

	common.SafeGRC20Transfer(cross, pool.Token0Path(), recipient, amount0)
	newBalanceToken0, err := updatePoolBalance(pool.BalanceToken0(), pool.BalanceToken1(), amount0, true)
	if err != nil {
		panic(err)
	}
	pool.SetBalanceToken0(newBalanceToken0)

	common.SafeGRC20Transfer(cross, pool.Token1Path(), recipient, amount1)
	newBalanceToken1, err := updatePoolBalance(pool.BalanceToken0(), pool.BalanceToken1(), amount1, false)
	if err != nil {
		panic(err)
	}
	pool.SetBalanceToken1(newBalanceToken1)

	err = i.savePool(pool)
	if err != nil {
		panic(err)
	}

	return formatInt(amount0), formatInt(amount1)
}

// saveProtocolFees updates the protocol fee balances after collection.
// Returns amount0, amount1 representing the fees deducted from protocol reserves.
func (i *poolV1) saveProtocolFees(pool *pl.Pool, amount0, amount1 int64) (int64, int64) {
	if pool.ProtocolFeesToken0() < amount0 {
		panic(errUnderflow)
	}
	pool.SetProtocolFeesToken0(safeSubInt64(pool.ProtocolFeesToken0(), amount0))

	if pool.ProtocolFeesToken1() < amount1 {
		panic(errUnderflow)
	}
	pool.SetProtocolFeesToken1(safeSubInt64(pool.ProtocolFeesToken1(), amount1))

	return amount0, amount1
}

func minRequestedAmount(request, available int64) int64 {
	if request > available {
		return available
	}

	return request
}

func (i *poolV1) IncreaseObservationCardinalityNext(
	token0Path string,
	token1Path string,
	fee uint32,
	cardinalityNext uint16,
) {
	halt.AssertIsNotHaltedPool()

	pool := i.mustGetPoolBy(token0Path, token1Path, fee)
	err := increaseObservationCardinalityNextByPool(pool, cardinalityNext)
	if err != nil {
		panic(err)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"IncreaseObservationCardinalityNext",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", pool.PoolPath(),
		"cardinalityNext", formatUint(cardinalityNext),
	)
}
