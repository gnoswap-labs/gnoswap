package gns

import (
	gnsmath "gno.land/p/gnoswap/gnsmath"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// validYear validates that year is within halving period range (1-12).
// Returns error if year is outside the valid range.
func validYear(year int64) error {
	if year < HALVING_START_YEAR || year > HALVING_END_YEAR {
		return makeErrorWithDetails(errInvalidYear, ufmt.Sprintf("year: %d", year))
	}

	return nil
}

// validEmissionAmount validates that the emission amount does not exceed maximum.
// Returns error if minting the amount would exceed MAX_EMISSION_AMOUNT.
func validEmissionAmount(amount int64) error {
	if amount < 0 {
		return makeErrorWithDetails(errInvalidEmissionAmount, ufmt.Sprintf("emission amount cannot be negative: %d", amount))
	}

	if gnsmath.SafeAddInt64(amount, MintedEmissionAmount()) > MAX_EMISSION_AMOUNT {
		return makeErrorWithDetails(errTooManyEmission, ufmt.Sprintf("too many emission amount: %d", amount))
	}

	return nil
}

// i64Min returns the smaller of two int64 values.
func i64Min(x, y int64) int64 {
	if x < y {
		return x
	}
	return y
}
