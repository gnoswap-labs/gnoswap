package gns

import (
	"std"
	"strconv"

	"gno.land/p/nt/ufmt"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/rbac"
)

// validBlockTime validates that block time is within acceptable range.
// Returns error if block time is <= 0 or >= 1e9.
func validBlockTime(blockTime int64) error {
	if blockTime <= 0 || blockTime >= 1e9 {
		return errInvalidAvgBlockTimeInMs
	}

	return nil
}

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
	if (amount + MintedEmissionAmount()) > MAX_EMISSION_AMOUNT {
		return ufmt.Errorf("too many emission amount: %d", amount)
	}

	return nil
}

// getAdminAddress returns the admin address from access control or default role address.
func getAdminAddress() std.Address {
	addr, exists := access.GetAddress(prabc.ROLE_ADMIN.String())
	if !exists {
		return rbac.DefaultRoleAddresses[prabc.ROLE_ADMIN]
	}

	return addr
}

// i64Min returns the smaller of two int64 values.
func i64Min(x, y int64) int64 {
	if x < y {
		return x
	}
	return y
}

// formatUint formats unsigned integer types to string.
// Supports uint8, uint32, and uint64. Panics for unsupported types.
func formatUint(v any) string {
	switch v := v.(type) {
	case uint8:
		return strconv.FormatUint(uint64(v), 10)
	case uint32:
		return strconv.FormatUint(uint64(v), 10)
	case uint64:
		return strconv.FormatUint(v, 10)
	default:
		panic(ufmt.Sprintf("invalid type: %T", v))
	}
}

// formatInt formats signed integer types to string.
// Supports int32, int64, and int. Panics for unsupported types.
func formatInt(v any) string {
	switch v := v.(type) {
	case int32:
		return strconv.FormatInt(int64(v), 10)
	case int64:
		return strconv.FormatInt(v, 10)
	case int:
		return strconv.Itoa(v)
	default:
		panic(ufmt.Sprintf("invalid type: %T", v))
	}
}
