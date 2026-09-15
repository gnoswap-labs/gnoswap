package gns

import (
	gnsmath "gno.land/p/gnoswap/gnsmath"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// validYear validates that year is one of the configured halving periods [1, 12].
//
// Parameters:
//   - year: halving period number to validate
//
// Returns:
//   - error: nil for a year in [1, 12]; non-nil identifying an invalid year otherwise
func validYear(year int64) error {
	if year < HALVING_START_YEAR || year > HALVING_END_YEAR {
		return makeErrorWithDetails(errInvalidYear, ufmt.Sprintf("year: %d", year))
	}

	return nil
}

// validEmissionAmount validates an emission amount against the global cap and
// current minted total without changing either value.
//
// Parameters:
//   - amount: nonnegative GNS base units proposed for emission
//
// Returns:
//   - error: nil when amount is nonnegative and fits under MAX_EMISSION_AMOUNT after current minting; non-nil for a negative or excessive amount
func validEmissionAmount(amount int64) error {
	if amount < 0 {
		return makeErrorWithDetails(errInvalidEmissionAmount, ufmt.Sprintf("emission amount cannot be negative: %d", amount))
	}

	if gnsmath.SafeAddInt64(amount, MintedEmissionAmount()) > MAX_EMISSION_AMOUNT {
		return makeErrorWithDetails(errTooManyEmission, ufmt.Sprintf("too many emission amount: %d", amount))
	}

	return nil
}

// i64Min returns the smaller of x and y.
//
// Parameters:
//   - x: first int64 value to compare
//   - y: second int64 value to compare
//
// Returns:
//   - minimum: lesser of x and y; y is returned when the values are equal
func i64Min(x, y int64) int64 {
	if x < y {
		return x
	}
	return y
}
