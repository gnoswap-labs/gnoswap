package staker

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission                 = errors.New("[GNOSWAP-STAKER-001] no permission")
	errNotRegistered                = errors.New("[GNOSWAP-STAKER-002] not registered")
	errAlreadyRegistered            = errors.New("[GNOSWAP-STAKER-003] already registered")
	errWrapUnwrap                   = errors.New("[GNOSWAP-STAKER-004] wrap/unwrap")
	errInvalidInput                 = errors.New("[GNOSWAP-STAKER-005] invalid input")
	errAlreadyStaked                = errors.New("[GNOSWAP-STAKER-006] already staked")
	errNonIncentivizedPool          = errors.New("[GNOSWAP-STAKER-007] non incentivized pool")
	errOutOfRange                   = errors.New("[GNOSWAP-STAKER-008] out of range")
	errCannotEndIncentive           = errors.New("[GNOSWAP-STAKER-009] cannot end incentive")
	errInvalidIncentiveStartTime    = errors.New("[GNOSWAP-STAKER-010] invalid incentive start time")
	errCannotUseForExternalReward   = errors.New("[GNOSWAP-STAKER-011] cannot use for external reward")
	errMinTier                      = errors.New("[GNOSWAP-STAKER-012] min tier")
	errDefaultPoolTier1CannotDelete = errors.New("[GNOSWAP-STAKER-013] default pool tier 1 cannot delete")
	errInvalidPoolPath              = errors.New("[GNOSWAP-STAKER-014] invalid pool path")
	errDataNotFound                 = errors.New("[GNOSWAP-STAKER-015] data not found")
	errCalculationError             = errors.New("[GNOSWAP-STAKER-016] calculation error")
	errNoLiquidity                  = errors.New("[GNOSWAP-STAKER-017] no liquidity")
)

func addDetailToError(err error, detail string) string {
	finalErr := errors.New(ufmt.Sprintf("%s || %s", err.Error(), detail))
	return finalErr.Error()
}
