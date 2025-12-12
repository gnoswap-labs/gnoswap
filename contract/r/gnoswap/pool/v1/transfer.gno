package v1

import (
	"chain/runtime"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// safeTransfer performs a token transfer out of the pool while ensuring
// the pool has sufficient balance and updating internal accounting.
// This function is typically used during swaps and liquidity removals.
//
// Important requirements:
//   - The amount must be a positive value representing tokens to transfer out
//   - The pool must have sufficient balance for the transfer
//   - The transfer amount must fit within int64 range
//
// Parameters:
//   - p: the pool instance
//   - to: destination address for the transfer
//   - tokenPath: path identifier of the token to transfer
//   - amount: amount to transfer (positive u256.Uint value)
//   - isToken0: true if transferring token0, false for token1
//
// The function will:
//  1. Check pool has sufficient balance
//  2. Execute the transfer
//  3. Subtract the amount from pool's internal balance
//
// Panics if any validation fails or if the transfer fails
func (i *poolV1) safeTransfer(
	p *pl.Pool,
	to address,
	tokenPath string,
	amount *u256.Uint,
	isToken0 bool,
) {
	token0 := p.BalanceToken0()
	token1 := p.BalanceToken1()

	if err := validatePoolBalance(token0, token1, amount, isToken0); err != nil {
		panic(err)
	}
	amountInt64 := safeConvertToInt64(amount)

	common.SafeGRC20Transfer(cross, tokenPath, to, amountInt64)

	newBalance, err := updatePoolBalance(token0, token1, amount, isToken0)
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
// This function performs the following steps:
// 1. Validates and converts the transfer amount to `int64` using `safeConvertToInt64`.
// 2. Executes the token transfer using `TransferFrom` via the token teller contract.
// 3. Verifies that the destination balance reflects the correct amount after transfer.
// 4. Updates the pool's internal balances (`token0` or `token1`) and validates the updated state.
//
// Parameters:
// - p (*pl.Pool): The pool instance to transfer tokens into.
// - from (address): Source address for the token transfer.
// - to (address): Destination address, typically the pool address.
// - tokenPath (string): Path identifier for the token being transferred.
// - amount (*u256.Uint): The amount of tokens to transfer (must be a positive value).
// - isToken0 (bool): A flag indicating whether the token being transferred is token0 (`true`) or token1 (`false`).
//
// Panics:
// - If the `amount` exceeds the int64 range during conversion.
// - If the token transfer (`TransferFrom`) fails.
// - If the destination balance after the transfer does not match the expected amount.
// - If the pool's internal balances (`token0` or `token1`) overflow or become inconsistent.
//
// Notes:
// - The function assumes that the sender (`from`) has approved the pool to spend the specified tokens.
// - The balance consistency check ensures that no tokens are lost or double-counted during the transfer.
// - Pool balance updates are performed atomically to ensure internal consistency.
func (i *poolV1) safeTransferFrom(
	p *pl.Pool,
	from, to address,
	tokenPath string,
	amount *u256.Uint,
	isToken0 bool,
) {
	amountInt64 := safeConvertToInt64(amount)

	token := common.GetToken(tokenPath)
	beforeBalance := token.BalanceOf(to)

	common.SafeGRC20TransferFrom(cross, tokenPath, from, to, amountInt64)

	afterBalance := token.BalanceOf(to)
	if (beforeBalance + amountInt64) != afterBalance {
		panic(ufmt.Sprintf(
			"%v. beforeBalance(%d) + amount(%d) != afterBalance(%d)",
			errTransferFailed, beforeBalance, amountInt64, afterBalance,
		))
	}

	poolBalances := p.Balances()

	// update pool balances
	if isToken0 {
		beforeToken0 := poolBalances.Token0().Clone()
		poolBalances.SetToken0(u256.Zero().Add(poolBalances.Token0(), amount))
		if poolBalances.Token0().Lt(beforeToken0) {
			panic(ufmt.Sprintf(
				"%v. token0(%s) < beforeToken0(%s)",
				errBalanceUpdateFailed, poolBalances.Token0().ToString(), beforeToken0.ToString(),
			))
		}
	} else {
		beforeToken1 := poolBalances.Token1().Clone()
		poolBalances.SetToken1(u256.Zero().Add(poolBalances.Token1(), amount))
		if poolBalances.Token1().Lt(beforeToken1) {
			panic(ufmt.Sprintf(
				"%v. token1(%s) < beforeToken1(%s)",
				errBalanceUpdateFailed, poolBalances.Token1().ToString(), beforeToken1.ToString(),
			))
		}
	}

	p.SetBalances(poolBalances)
}

// safeSwapCallback executes a swap callback and validates the token payment.
//
// This function implements the flash swap pattern where the pool first sends output tokens
// to the recipient, then invokes the callback to receive input tokens from the caller.
// The callback is responsible for transferring the required input tokens to the pool.
//
// Callback Signature:
//
//	func(cur realm, amount0Delta, amount1Delta int64) error
//
// Delta Convention (following Uniswap V3 standard):
//   - Positive delta: Amount the pool must RECEIVE (input token)
//   - Negative delta: Amount the pool has SENT (output token)
//
// For zeroForOne swaps (token0 → token1):
//   - amount0Delta > 0: Pool receives token0 (input)
//   - amount1Delta < 0: Pool sends token1 (output)
//
// For oneForZero swaps (token1 → token0):
//   - amount0Delta < 0: Pool sends token0 (output)
//   - amount1Delta > 0: Pool receives token1 (input)
//
// Parameters:
//   - p: The pool instance
//   - tokenPath: Path of the input token that pool must receive
//   - amountInInt256: Amount pool must receive (positive i256.Int)
//   - amountOutInt256: Amount pool has sent (negative i256.Int)
//   - zeroForOne: Swap direction (true = token0 to token1)
//   - swapCallback: Callback function that must transfer input tokens to pool
//
// The callback needed:
//  1. Transfer at least `amountIn` of input tokens to the pool
//  2. Return nil on success, or an error to revert the swap
//
// Example callback implementation:
//
//	func(cur realm, amount0Delta, amount1Delta int64) error {
//	    if amount0Delta > 0 {
//	        // Transfer token0 to pool
//	        token0.Transfer(poolAddr, amount0Delta)
//	    }
//	    if amount1Delta > 0 {
//	        // Transfer token1 to pool
//	        token1.Transfer(poolAddr, amount1Delta)
//	    }
//	    return nil
//	}
func (i *poolV1) safeSwapCallback(
	p *pl.Pool,
	tokenPath string,
	amountInInt256 *i256.Int,
	amountOutInt256 *i256.Int,
	zeroForOne bool,
	swapCallback func(cur realm, amount0Delta, amount1Delta int64) error,
) {
	if swapCallback == nil {
		panic(makeErrorWithDetails(
			errInvalidInput,
			"swapCallback is nil",
		))
	}

	currentAddress := runtime.CurrentRealm().Address()

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
		beforeTokenBalance = p.BalanceToken0().Int64()
	} else {
		// !zeroForOne: pool receives token1 (positive), sends token0 (negative)
		amount0Delta = amountOut
		amount1Delta = amountIn
		beforeTokenBalance = p.BalanceToken1().Int64()
	}

	// execute swap callback
	err := swapCallback(cross, amount0Delta, amount1Delta)
	if err != nil {
		panic(err)
	}

	balanceAfter := common.BalanceOf(tokenPath, currentAddress)
	balanceIncrease := safeSubInt64(balanceAfter, balanceBefore)

	// check insufficient payment by swap callback
	if balanceIncrease < amountIn {
		panic(makeErrorWithDetails(
			errInsufficientPayment,
			ufmt.Sprintf("insufficient payment: expected %d, received %d", amountIn, balanceIncrease),
		))
	}

	// check overflow update pool balance
	resultTokenBalance := safeAddInt64(beforeTokenBalance, amountIn)
	resultTokenBalanceUint := u256.NewUintFromInt64(resultTokenBalance)

	poolBalances := p.Balances()

	if zeroForOne {
		poolBalances.SetToken0(resultTokenBalanceUint)
	} else {
		poolBalances.SetToken1(resultTokenBalanceUint)
	}

	p.SetBalances(poolBalances)
}

// validatePoolBalance checks if the pool has sufficient balance of either token0 and token1
// before proceeding with a transfer. This prevents the pool won't go into a negative balance.
func validatePoolBalance(token0, token1, amount *u256.Uint, isToken0 bool) error {
	if token0 == nil || token1 == nil || amount == nil {
		return ufmt.Errorf(
			"%v. token0(%s) or token1(%s) or amount(%s) is nil",
			errTransferFailed, token0.ToString(), token1.ToString(), amount.ToString(),
		)
	}

	if isToken0 {
		if token0.Lt(amount) {
			return ufmt.Errorf(
				"%v. token0(%s) >= amount(%s)",
				errTransferFailed, token0.ToString(), amount.ToString(),
			)
		}
		return nil
	}
	if token1.Lt(amount) {
		return ufmt.Errorf(
			"%v. token1(%s) >= amount(%s)",
			errTransferFailed, token1.ToString(), amount.ToString(),
		)
	}
	return nil
}

// updatePoolBalance calculates the new balance after a transfer and validate.
// It ensures the resulting balance won't be negative or overflow.
func updatePoolBalance(
	token0, token1, amount *u256.Uint,
	isToken0 bool,
) (*u256.Uint, error) {
	var overflow bool
	var newBalance *u256.Uint

	if isToken0 {
		newBalance, overflow = u256.Zero().SubOverflow(token0, amount)
		if isBalanceOverflowOrNegative(overflow, newBalance) {
			return nil, ufmt.Errorf(
				"%v. cannot decrease, token0(%s) - amount(%s)",
				errBalanceUpdateFailed, token0.ToString(), amount.ToString(),
			)
		}
		return newBalance, nil
	}

	newBalance, overflow = u256.Zero().SubOverflow(token1, amount)
	if isBalanceOverflowOrNegative(overflow, newBalance) {
		return nil, ufmt.Errorf(
			"%v. cannot decrease, token1(%s) - amount(%s)",
			errBalanceUpdateFailed, token1.ToString(), amount.ToString(),
		)
	}
	return newBalance, nil
}

// isBalanceOverflowOrNegative checks if the balance calculation resulted in an overflow or negative value.
func isBalanceOverflowOrNegative(overflow bool, newBalance *u256.Uint) bool {
	return overflow || newBalance.Lt(zero)
}
