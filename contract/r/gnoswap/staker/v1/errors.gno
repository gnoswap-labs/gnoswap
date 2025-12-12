package v1

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errNoPermission                  = errors.New("[GNOSWAP-STAKER-001] caller has no permission")
	errPoolNotFound                  = errors.New("[GNOSWAP-STAKER-002] pool not found")
	errWugnotMinimum                 = errors.New("[GNOSWAP-STAKER-003] cannot wrap less than minimum amount")
	errInvalidInput                  = errors.New("[GNOSWAP-STAKER-004] invalid input data")
	errInvalidUnstakingFee           = errors.New("[GNOSWAP-STAKER-005] invalid unstaking fee")
	errAlreadyStaked                 = errors.New("[GNOSWAP-STAKER-006] already staked position")
	errNonIncentivizedPool           = errors.New("[GNOSWAP-STAKER-007] pool is not incentivized")
	errCannotEndIncentive            = errors.New("[GNOSWAP-STAKER-008] cannot end incentive")
	errInvalidIncentiveStartTime     = errors.New("[GNOSWAP-STAKER-009] invalid incentive start time")
	errDefaultExternalToken          = errors.New("[GNOSWAP-STAKER-010] cannot delete default external token")
	errInvalidPoolPath               = errors.New("[GNOSWAP-STAKER-011] invalid pool path")
	errInvalidPoolTier               = errors.New("[GNOSWAP-STAKER-012] invalid pool tier")
	errDataNotFound                  = errors.New("[GNOSWAP-STAKER-013] requested data not found")
	errCalculationError              = errors.New("[GNOSWAP-STAKER-014] unexpected calculation error")
	errZeroLiquidity                 = errors.New("[GNOSWAP-STAKER-015] zero liquidity")
	errInvalidIncentiveDuration      = errors.New("[GNOSWAP-STAKER-016] invalid incentive duration")
	errNotAllowedForExternalReward   = errors.New("[GNOSWAP-STAKER-017] not allowed for external reward")
	errIncentiveAlreadyExists        = errors.New("[GNOSWAP-STAKER-018] incentive already exists")
	errOverflow                      = errors.New("[GNOSWAP-STAKER-019] overflow")
	errAddExistingToken              = errors.New("[GNOSWAP-STAKER-020] cannot add existing token")
	errNotAvailableUpdateCollectTime = errors.New("[GNOSWAP-STAKER-021] not available to update collect time")
)

func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
