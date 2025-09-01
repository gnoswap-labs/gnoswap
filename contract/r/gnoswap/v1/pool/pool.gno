package pool

import (
	"std"

	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

var (
	positionAddr, _    = access.GetAddress(prabc.ROLE_POSITION.String())
	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())
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
func Mint(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string,
	positionCaller std.Address,
) (string, string) {
	halt.AssertIsNotHaltedPool()

	caller := std.PreviousRealm().Address()
	access.AssertIsPosition(caller)
	access.AssertIsValidAddress(positionCaller)

	liquidity := u256.MustFromDecimal(liquidityAmount)
	if liquidity.IsZero() {
		panic(errZeroLiquidity)
	}

	pool := mustGetPoolBy(token0Path, token1Path, fee)
	liquidityDelta := safeConvertToInt128(liquidity)
	positionParam := newModifyPositionParams(positionCaller, tickLower, tickUpper, liquidityDelta)
	_, amount0, amount1, err := pool.modifyPosition(positionParam)
	if err != nil {
		panic(err)
	}

	if amount0.Gt(zero) {
		pool.safeTransferFrom(positionCaller, poolAddr, pool.token0Path, amount0, true)
	}

	if amount1.Gt(zero) {
		pool.safeTransferFrom(positionCaller, poolAddr, pool.token1Path, amount1, false)
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
func Burn(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string, // uint128
	positionCaller std.Address,
) (string, string) { // uint256 x2
	halt.AssertIsNotHaltedPool()

	caller := std.PreviousRealm().Address()
	access.AssertIsPosition(caller)
	access.AssertIsValidAddress(positionCaller)

	liqAmount := u256.MustFromDecimal(liquidityAmount)
	liqAmountInt256 := safeConvertToInt128(liqAmount)
	liqDelta := i256.Zero().Neg(liqAmountInt256)

	posParams := newModifyPositionParams(positionCaller, tickLower, tickUpper, liqDelta)
	pool := mustGetPoolBy(token0Path, token1Path, fee)
	position, amount0, amount1, err := pool.modifyPosition(posParams)
	if err != nil {
		panic(err)
	}

	if amount0.Gt(zero) || amount1.Gt(zero) {
		amount0 = toUint128(amount0)
		amount1 = toUint128(amount1)

		tokensOwed0, overflow := u256.Zero().AddOverflow(position.tokensOwed0, amount0)
		if overflow {
			panic(errOverFlow)
		}
		position.tokensOwed0 = tokensOwed0

		tokensOwed1, overflow := u256.Zero().AddOverflow(position.tokensOwed1, amount1)
		if overflow {
			panic(errOverFlow)
		}
		position.tokensOwed1 = tokensOwed1
	}

	positionKey, err := getPositionKey(tickLower, tickUpper)
	if err != nil {
		panic(err)
	}

	pool.setPosition(positionKey, position)

	// mustGetPosition() is called to ensure the position exists
	pool.mustGetPosition(positionKey)

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
func Collect(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	halt.AssertIsNotHaltedPool()
	halt.AssertIsNotHaltedWithdraw()

	caller := std.PreviousRealm().Address()
	access.AssertIsPosition(caller)
	access.AssertIsValidAddress(recipient)

	pool := mustGetPoolBy(token0Path, token1Path, fee)
	// Use recipient address instead of getPrevAddr() for position key generation
	// Because positions are created with the recipient's address in Mint function,
	// and we need to access the same position that was originally created.
	// GetPrevAddr() would return the position contract address, but the actual
	// position is stored under the recipient's address key.
	positionKey, err := getPositionKey(tickLower, tickUpper)
	if err != nil {
		panic(err)
	}

	position := pool.mustGetPosition(positionKey)

	var amount0, amount1 *u256.Uint

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount0Req := u256.MustFromDecimal(amount0Requested)
	amount0 = collectToken(amount0Req, position.tokensOwed0, pool.BalanceToken0())

	amount1Req := u256.MustFromDecimal(amount1Requested)
	amount1 = collectToken(amount1Req, position.tokensOwed1, pool.BalanceToken1())

	if amount0.Gt(u256.Zero()) {
		tokenOwed0, overflow := u256.Zero().SubOverflow(position.tokensOwed0, amount0)
		if overflow {
			panic(errOverFlow)
		}

		token0Balance, overflow := u256.Zero().SubOverflow(pool.balances.token0, amount0)
		if overflow {
			panic(errOverFlow)
		}

		position.tokensOwed0 = tokenOwed0
		pool.balances.token0 = token0Balance
		if err := common.Approve(cross, pool.token0Path, positionAddr, safeConvertToInt64(amount0)); err != nil {
			panic(err)
		}
	}
	if amount1.Gt(u256.Zero()) {
		position.tokensOwed1 = u256.Zero().Sub(position.tokensOwed1, amount1)
		pool.balances.token1 = u256.Zero().Sub(pool.balances.token1, amount1)

		if err := common.Approve(cross, pool.token1Path, positionAddr, safeConvertToInt64(amount1)); err != nil {
			panic(err)
		}
	}

	pool.setPosition(positionKey, position)

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
func CollectProtocol(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	amount0Requested string, // uint128
	amount1Requested string, // uint128
) (string, string) {
	halt.AssertIsNotHaltedPool()
	halt.AssertIsNotHaltedWithdraw()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	common.MustRegistered(token0Path)
	common.MustRegistered(token1Path)

	amount0, amount1 := collectProtocol(
		token0Path,
		token1Path,
		fee,
		recipient,
		amount0Requested,
		amount1Requested,
	)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"CollectProtocol",
		"prevAddr", previousRealm.Address().String(),
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
func collectProtocol(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	pool := mustGetPoolBy(token0Path, token1Path, fee)

	amount0Req := u256.MustFromDecimal(amount0Requested)
	amount1Req := u256.MustFromDecimal(amount1Requested)
	if amount0Req.IsZero() && amount1Req.IsZero() {
		return "0", "0"
	}

	amount0 := u256Min(amount0Req, pool.ProtocolFeesToken0())
	amount1 := u256Min(amount1Req, pool.ProtocolFeesToken1())

	amount0, amount1 = pool.saveProtocolFees(amount0.Clone(), amount1.Clone())
	uAmount0 := safeConvertToInt64(amount0)
	uAmount1 := safeConvertToInt64(amount1)

	checkTransferError(common.Transfer(cross, pool.token0Path, recipient, uAmount0))
	newBalanceToken0, err := updatePoolBalance(pool.BalanceToken0(), pool.BalanceToken1(), amount0, true)
	if err != nil {
		panic(err)
	}
	pool.balances.token0 = newBalanceToken0

	checkTransferError(common.Transfer(cross, pool.token1Path, recipient, uAmount1))
	newBalanceToken1, err := updatePoolBalance(pool.BalanceToken0(), pool.BalanceToken1(), amount1, false)
	if err != nil {
		panic(err)
	}
	pool.balances.token1 = newBalanceToken1

	return amount0.ToString(), amount1.ToString()
}

// saveProtocolFees updates the protocol fee balances after collection.
// Returns amount0, amount1 representing the fees deducted from protocol reserves.
func (p *Pool) saveProtocolFees(amount0, amount1 *u256.Uint) (*u256.Uint, *u256.Uint) {
	p.protocolFees.token0 = u256.Zero().Sub(p.ProtocolFeesToken0(), amount0)
	p.protocolFees.token1 = u256.Zero().Sub(p.ProtocolFeesToken1(), amount1)

	return amount0, amount1
}
