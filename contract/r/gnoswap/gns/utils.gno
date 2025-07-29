package gns

import (
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/rbac"
)

func validBlockTime(blockTime int64) error {
	if blockTime <= 0 || blockTime >= 1e9 {
		return errInvalidAvgBlockTimeInMs
	}

	return nil
}

func validYear(year int64) error {
	if year < HALVING_START_YEAR || year > HALVING_END_YEAR {
		return makeErrorWithDetails(errInvalidYear, ufmt.Sprintf("year: %d", year))
	}

	return nil
}

// validEmissionAmount validates the emission amount if the amount of gns to mint is too many.
// Parameters:
//   - amount: The emission amount to validate
// Returns:
//   - error: An error if the emission amount is invalid
func validEmissionAmount(amount int64) error {
	if (amount + MintedEmissionAmount()) > MAX_EMISSION_AMOUNT {
		return ufmt.Errorf("too many emission amount: %d", amount)
	}

	return nil
}

func getAdminAddress() std.Address {
	addr, exists := access.GetAddress(prabc.ROLE_ADMIN.String())
	if !exists {
		return rbac.DefaultRoleAddresses[prabc.ROLE_ADMIN]
	}

	return addr
}

func i64Min(x, y int64) int64 {
	if x < y {
		return x
	}
	return y
}

func secToMs(sec int64) int64 {
	return sec * MILLISECONDS_PER_SECOND
}

func milliToSec(ms int64) int64 {
	return ms / MILLISECONDS_PER_SECOND
}

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
