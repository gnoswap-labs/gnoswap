package staker

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission                = errors.New("[GNOSWAP-STAKER-001] no permission")
	errNotRegistered               = errors.New("[GNOSWAP-STAKER-002] not registered")
	errAlreadyRegistered           = errors.New("[GNOSWAP-STAKER-003] already registered")
	errLocked                      = errors.New("[GNOSWAP-STAKER-004] can't transfer token while locked")
	errWrapUnwrap                  = errors.New("[GNOSWAP-STAKER-005] wrap/unwrap")
	errWugnotMinimum               = errors.New("[GNOSWAP-STAKER-006] wugnot minimum")
	errInvalidInput                = errors.New("[GNOSWAP-STAKER-007] invalid input")
	errInvalidUnstakingFee         = errors.New("[GNOSWAP-STAKER-008] invalid unstaking fee")
	errAlreadyStaked               = errors.New("[GNOSWAP-STAKER-009] already staked")
	errNonIncentivizedPool         = errors.New("[GNOSWAP-STAKER-010] non incentivized pool")
	errOutOfRange                  = errors.New("[GNOSWAP-STAKER-011] out of range")
	errCannotEndIncentive          = errors.New("[GNOSWAP-STAKER-012] cannot end incentive")
	errInvalidIncentiveStartTime   = errors.New("[GNOSWAP-STAKER-013] invalid incentive start time")
	errInvalidIncentiveEndTime     = errors.New("[GNOSWAP-STAKER-014] invalid incentive end time")
	errCannotUseForExternalReward  = errors.New("[GNOSWAP-STAKER-015] cannot use for external reward")
	errMinTier                     = errors.New("[GNOSWAP-STAKER-016] min tier")
	errDefaultPoolTier1            = errors.New("[GNOSWAP-STAKER-017] can not delete default pool tier 1")
	errDefaultExternalToken        = errors.New("[GNOSWAP-STAKER-018] can not delete default external token")
	errInvalidPoolPath             = errors.New("[GNOSWAP-STAKER-019] invalid pool path")
	errInvalidPoolTier             = errors.New("[GNOSWAP-STAKER-020] invalid pool tier")
	errAlreadyHasTier              = errors.New("[GNOSWAP-STAKER-021] already has tier")
	errDataNotFound                = errors.New("[GNOSWAP-STAKER-022] data not found")
	errCalculationError            = errors.New("[GNOSWAP-STAKER-023] calculation error")
	errZeroLiquidity               = errors.New("[GNOSWAP-STAKER-024] zero liquidity")
	errInvalidIncentiveDuration    = errors.New("[GNOSWAP-STAKER-025] invalid incentive duration")
	errNotAllowedForExternalReward = errors.New("[GNOSWAP-STAKER-026] not allowed for external reward")
	errInvalidWarmUpPercent        = errors.New("[GNOSWAP-STAKER-027] invalid warm up percent")
)

func addDetailToError(err error, detail string) string {
	finalErr := ufmt.Errorf("%s || %s", err.Error(), detail)
	return finalErr.Error()
}
