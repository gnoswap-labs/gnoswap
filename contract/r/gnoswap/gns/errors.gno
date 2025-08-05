package gns

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errInvalidYear                 = errors.New("[GNOSWAP-GNS-001] invalid year")
	errTooManyEmission             = errors.New("[GNOSWAP-GNS-002] too many emission reward")
	errEmissionChangeIsNilCallback = errors.New("[GNOSWAP-GNS-003] callback emission change is nil")
	errInvalidAvgBlockTimeInMs     = errors.New("[GNOSWAP-GNS-004] invalid avg block time in ms")
	errBlockPerDayCannotBeZero     = errors.New("[GNOSWAP-GNS-005] blockPerDay cannot be zero")
	errInvalidBlockPerYear         = errors.New("[GNOSWAP-GNS-006] invalid blockPerYear calculation - would result in division by zero")
	errInvalidBlockPerDay          = errors.New("[GNOSWAP-GNS-007] invalid blockPerDay calculation - would result in division by zero")
	errEmissionPeriodEnded         = errors.New("[GNOSWAP-GNS-008] cannot set average block time after emission period has ended")
	errInvalidAddress              = errors.New("[GNOSWAP-GNS-009] address is not valid")
	errFromAddressEmpty            = errors.New("[GNOSWAP-GNS-010] from address cannot be empty")
	errToAddressEmpty              = errors.New("[GNOSWAP-GNS-011] to address cannot be empty")
	errAmountMustBePositive        = errors.New("[GNOSWAP-GNS-012] amount must be positive")
	errAmountCannotBeNegative      = errors.New("[GNOSWAP-GNS-013] amount cannot be negative")
	errSpenderAddressEmpty         = errors.New("[GNOSWAP-GNS-014] spender address cannot be empty")
	errOverflowInCalculation       = errors.New("[GNOSWAP-GNS-015] overflow in calculation")
	errInvalidType                 = errors.New("[GNOSWAP-GNS-016] invalid type")
)

func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
