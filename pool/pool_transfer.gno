package pool

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// transferAndVerify performs a token transfer out of the pool while ensuring
// the pool has sufficient balance and updating internal accounting.
// This function is typically used during swaps and liquidity removals.
//
// Important requirements:
//   - The amount must be negative (representing an outflow from the pool)
//   - The pool must have sufficient balance for the transfer
//   - The transfer amount must fit within uint64 range
//
// Parameters:
//   - to: destination address for the transfer
//   - tokenPath: path identifier of the token to transfer
//   - amount: amount to transfer (must be negative)
//   - isToken0: true if transferring token0, false for token1
//
// The function will:
//  1. Validate the amount is negative
//  2. Check pool has sufficient balance
//  3. Execute the transfer
//  4. Update pool's internal balance
//
// Panics if any validation fails or if the transfer fails
func (p *Pool) transferAndVerify(
	to std.Address,
	tokenPath string,
	amount *i256.Int,
	isToken0 bool,
) {
	if amount.Sign() != -1 {
		panic(ufmt.Sprintf(
			"%v. got: %s", errMustBeNegative, amount.ToString(),
		))
	}

	absAmount := amount.Abs()

	token0 := p.balances.token0
	token1 := p.balances.token1

	if err := validatePoolBalance(token0, token1, absAmount, isToken0); err != nil {
		panic(err)
	}
	amountUint64, err := safeConvertToUint64(absAmount)
	if err != nil {
		panic(err)
	}

	token := common.GetTokenTeller(tokenPath)
	checkTransferError(token.Transfer(to, amountUint64))

	newBalance, err := updatePoolBalance(token0, token1, absAmount, isToken0)
	if err != nil {
		panic(err)
	}

	if isToken0 {
		p.balances.token0 = newBalance
	} else {
		p.balances.token1 = newBalance
	}
}

// transferFromAndVerify performs a token transfer into the pool using transferFrom
// while updating the pool's internal accounting. This function is typically used
// during swaps and liquidity additions.
//
// The function assumes the sender has approved the pool to spend their tokens.
//
// Parameters:
//   - from: source address for the transfer
//   - to: destination address (typically the pool)
//   - tokenPath: path identifier of the token to transfer
//   - amount: amount to transfer (must be positive)
//   - isToken0: true if transferring token0, false for token1
//
// The function will:
// 1. Convert amount to uint64 (must fit)
// 2. Execute the transferFrom
// 3. Update pool's internal balance
//
// Panics if the amount conversion fails or if the transfer fails
func (p *Pool) transferFromAndVerify(
	from, to std.Address,
	tokenPath string,
	amount *u256.Uint,
	isToken0 bool,
) {
	absAmount := amount
	amountUint64, err := safeConvertToUint64(absAmount)
	if err != nil {
		panic(err)
	}

	token := common.GetTokenTeller(tokenPath)
	checkTransferError(token.TransferFrom(from, to, amountUint64))

	// update pool balances
	if isToken0 {
		p.balances.token0 = new(u256.Uint).Add(p.balances.token0, absAmount)
	} else {
		p.balances.token1 = new(u256.Uint).Add(p.balances.token1, absAmount)
	}
}

// validatePoolBalance checks if the pool has sufficient balance of either token0 and token1
// before proceeding with a transfer. This prevents the pool won't go into a negative balance.
func validatePoolBalance(token0, token1, amount *u256.Uint, isToken0 bool) error {
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
		newBalance, overflow = new(u256.Uint).SubOverflow(token0, amount)
		if isBalanceOverflowOrNegative(overflow, newBalance) {
			return nil, ufmt.Errorf(
				"%v. cannot decrease, token0(%s) - amount(%s)",
				errTransferFailed, token0.ToString(), amount.ToString(),
			)
		}
		return newBalance, nil
	}

	newBalance, overflow = new(u256.Uint).SubOverflow(token1, amount)
	if isBalanceOverflowOrNegative(overflow, newBalance) {
		return nil, ufmt.Errorf(
			"%v. cannot decrease, token1(%s) - amount(%s)",
			errTransferFailed, token1.ToString(), amount.ToString(),
		)
	}
	return newBalance, nil
}

func isBalanceOverflowOrNegative(overflow bool, newBalance *u256.Uint) bool {
	return overflow || newBalance.Lt(u256.Zero())
}
