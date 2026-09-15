package pool

import (
	ufmt "gno.land/p/nt/ufmt/v0"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"

	"gno.land/p/gnoswap/gnsmath"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// safeTransfer performs a token transfer out of the pool while ensuring
// the pool has sufficient balance and updating internal accounting.
// This function is typically used during swaps and liquidity removals.
//
// Parameters:
//   - _: interrealm call discriminator; callers pass 0.
//   - rlm: propagated realm context used for the token transfer.
//   - p: pool whose selected token balance is decremented.
//   - to: destination address receiving the tokens.
//   - tokenPath: path identifier of the token to transfer.
//   - amount: non-negative token amount to transfer; it must fit in int64.
//   - isToken0: true to transfer token0, false to transfer token1.
//
// Panics when the amount cannot fit in int64, the selected balance is
// insufficient, the token transfer fails, or internal balance arithmetic fails.
func (i *poolV1) safeTransfer(
	_ int,
	rlm realm,
	p *pl.Pool,
	to address,
	tokenPath string,
	amount *u256.Uint,
	isToken0 bool,
) {
	token0 := p.BalanceToken0()
	token1 := p.BalanceToken1()
	amountInt64 := gnsmath.SafeConvertToInt64(amount)

	if err := validatePoolBalance(token0, token1, amountInt64, isToken0); err != nil {
		panic(err)
	}

	common.SafeGRC20Transfer(0, rlm, tokenPath, to, amountInt64)

	newBalance, err := updatePoolBalance(token0, token1, amountInt64, isToken0)
	if err != nil {
		panic(err)
	}

	poolBalances := p.Balances()

	if isToken0 {
		poolBalances.SetToken0(newBalance)
	} else {
		poolBalances.SetToken1(newBalance)
	}

	p.SetBalances(poolBalances)
}

// safeTransferFrom securely transfers tokens into the pool while ensuring balance consistency.
//
// Parameters:
//   - _: interrealm call discriminator; callers pass 0.
//   - rlm: propagated realm context used for the token transfer.
//   - p: pool whose selected token balance is incremented.
//   - from: source address authorized to transfer tokens.
//   - to: destination address whose token balance must increase; normally the pool address.
//   - tokenPath: path identifier of the token being transferred.
//   - amount: non-negative token amount to transfer; it must fit in int64.
//   - isToken0: true to update token0, false to update token1.
//
// The destination balance is checked before and after TransferFrom so the
// internal pool balance cannot diverge from the token contract. The function
// panics if conversion, transfer, balance verification, or checked addition fails.
func (i *poolV1) safeTransferFrom(
	_ int,
	rlm realm,
	p *pl.Pool,
	from, to address,
	tokenPath string,
	amount *u256.Uint,
	isToken0 bool,
) {
	amountInt64 := gnsmath.SafeConvertToInt64(amount)

	beforeBalance := common.BalanceOf(tokenPath, to)

	common.SafeGRC20TransferFrom(0, rlm, tokenPath, from, to, amountInt64)

	afterBalance := common.BalanceOf(tokenPath, to)
	if gnsmath.SafeAddInt64(beforeBalance, amountInt64) != afterBalance {
		panic(ufmt.Sprintf(
			"%v. beforeBalance(%d) + amount(%d) != afterBalance(%d)",
			errTransferFailed, beforeBalance, amountInt64, afterBalance,
		))
	}

	poolBalances := p.Balances()

	// update pool balances
	if isToken0 {
		poolBalances.SetToken0(gnsmath.SafeAddInt64(poolBalances.Token0(), amountInt64))
	} else {
		poolBalances.SetToken1(gnsmath.SafeAddInt64(poolBalances.Token1(), amountInt64))
	}

	p.SetBalances(poolBalances)
}

// safeSwapCallback executes a swap callback and validates the token payment.
//
// The pool first sends output tokens, then invokes swapCallback so the caller
// can transfer the required input tokens back to the pool. Positive callback
// deltas mean the pool must receive that token; negative deltas mean the pool
// already sent it.
//
// Parameters:
//   - _: interrealm call discriminator; callers pass 0.
//   - rlm: propagated realm context passed to the callback.
//   - p: pool whose input-token balance is incremented after payment.
//   - tokenPath: path of the input token that the pool must receive.
//   - amountInInt256: signed input amount; its int64 value is required from the callback.
//   - amountOutInt256: signed output amount, normally negative under the delta convention.
//   - zeroForOne: true for token0-to-token1 swaps, false for token1-to-token0 swaps.
//   - swapCallback: callback that must pay the input token and return nil on success.
//
// Panics when the callback is nil or returns an error, payment is insufficient,
// or the resulting pool balance cannot be represented safely.
func (i *poolV1) safeSwapCallback(
	_ int,
	rlm realm,
	p *pl.Pool,
	tokenPath string,
	amountInInt256 *i256.Int,
	amountOutInt256 *i256.Int,
	zeroForOne bool,
	swapCallback func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error,
) {
	if swapCallback == nil {
		panic(makeErrorWithDetails(
			errInvalidInput,
			"swapCallback is nil",
		))
	}

	currentAddress := access.MustGetAddress(prabc.ROLE_POOL.String())

	amountIn := amountInInt256.Int64()
	amountOut := amountOutInt256.Int64()
	balanceBefore := common.BalanceOf(tokenPath, currentAddress)

	// Make callback to the calling contract
	// The contract should transfer tokens to pool within this callback
	// Following Uniswap V3 convention:
	// - Positive delta: amount the pool must receive (input token)
	// - Negative delta: amount the pool has sent (output token)
	var amount0Delta, amount1Delta, beforeTokenBalance int64

	if zeroForOne {
		// zeroForOne: pool receives token0 (positive), sends token1 (negative)
		amount0Delta = amountIn
		amount1Delta = amountOut
		beforeTokenBalance = p.BalanceToken0()
	} else {
		// !zeroForOne: pool receives token1 (positive), sends token0 (negative)
		amount0Delta = amountOut
		amount1Delta = amountIn
		beforeTokenBalance = p.BalanceToken1()
	}

	// execute swap callback
	// CallbackMarker is created by the pool module to enforce type-system level validation.
	// Allocation goes through pl.NewCallbackMarker so the alloc happens in pool realm
	// (interrealm v2 forbids /r/-declared types being constructed outside their owner).
	err := swapCallback(cross(rlm), amount0Delta, amount1Delta, pl.NewCallbackMarker())
	if err != nil {
		panic(err)
	}

	balanceAfter := common.BalanceOf(tokenPath, currentAddress)
	balanceIncrease := gnsmath.SafeSubInt64(balanceAfter, balanceBefore)

	// check insufficient payment by swap callback
	if balanceIncrease < amountIn {
		panic(makeErrorWithDetails(
			errInsufficientPayment,
			ufmt.Sprintf("insufficient payment: expected %d, received %d", amountIn, balanceIncrease),
		))
	}

	// check overflow update pool balance
	resultTokenBalance := gnsmath.SafeAddInt64(beforeTokenBalance, amountIn)

	poolBalances := p.Balances()

	if zeroForOne {
		poolBalances.SetToken0(resultTokenBalance)
	} else {
		poolBalances.SetToken1(resultTokenBalance)
	}

	p.SetBalances(poolBalances)
}

// validatePoolBalance checks that amount is non-negative and does not exceed
// the selected token balance before a transfer out of the pool.
//
// Parameters:
//   - token0: current token0 balance.
//   - token1: current token1 balance.
//   - amount: amount to subtract from the selected balance.
//   - isToken0: true to validate token0, false to validate token1.
//
// Returns:
//   - error: nil when the selected balance covers amount; otherwise an error describing the violation.
func validatePoolBalance(token0, token1, amount int64, isToken0 bool) error {
	if amount < 0 {
		return ufmt.Errorf("%v. amount(%d) must be positive", errTransferFailed, amount)
	}

	if isToken0 {
		if token0 < amount {
			return ufmt.Errorf(
				"%v. token0(%d) >= amount(%d)",
				errTransferFailed, token0, amount,
			)
		}
		return nil
	}
	if token1 < amount {
		return ufmt.Errorf(
			"%v. token1(%d) >= amount(%d)",
			errTransferFailed, token1, amount,
		)
	}
	return nil
}

// updatePoolBalance calculates the selected token balance after a transfer out.
// It rejects negative amounts and subtraction that would make the balance negative.
//
// Parameters:
//   - token0: current token0 balance.
//   - token1: current token1 balance.
//   - amount: amount to subtract from the selected balance.
//   - isToken0: true to update token0, false to update token1.
//
// Returns:
//   - int64: selected token balance after subtracting amount; zero on error.
//   - error: nil when subtraction succeeds; non-nil for a negative amount or insufficient balance.
func updatePoolBalance(
	token0, token1, amount int64,
	isToken0 bool,
) (int64, error) {
	if amount < 0 {
		return 0, ufmt.Errorf("%v. amount(%d) must be positive", errBalanceUpdateFailed, amount)
	}

	if isToken0 {
		if token0 < amount {
			return 0, ufmt.Errorf(
				"%v. cannot decrease, token0(%d) - amount(%d)",
				errBalanceUpdateFailed, token0, amount,
			)
		}
		return gnsmath.SafeSubInt64(token0, amount), nil
	}

	if token1 < amount {
		return 0, ufmt.Errorf(
			"%v. cannot decrease, token1(%d) - amount(%d)",
			errBalanceUpdateFailed, token1, amount,
		)
	}
	return gnsmath.SafeSubInt64(token1, amount), nil
}
