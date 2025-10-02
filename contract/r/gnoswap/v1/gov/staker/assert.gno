package staker

import "gno.land/p/nt/ufmt"

// assertIsValidDelegateAmount validates that the delegation amount meets system requirements.
// This function checks minimum amount and multiple requirements.
//
// Parameters:
//   - amount: amount to validate
//
// Returns:
//   - error: nil if valid, error describing validation failure
func assertIsValidDelegateAmount(amount int64) {
	if amount < minimumAmount {
		panic(makeErrorWithDetails(
			errLessThanMinimum,
			ufmt.Sprintf("minimum amount to delegate is %d (requested:%d)", minimumAmount, amount),
		))
	}

	if amount%minimumAmount != 0 {
		panic(makeErrorWithDetails(
			errInvalidAmount,
			ufmt.Sprintf("amount must be multiple of %d", minimumAmount),
		))
	}
}
