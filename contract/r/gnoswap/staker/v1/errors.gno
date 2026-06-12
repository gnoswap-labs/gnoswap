package v1

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errNoPermission                  = "[GNOSWAP-STAKER-001] caller has no permission"
	errPoolNotFound                  = "[GNOSWAP-STAKER-002] pool not found"
	errNotAvailableUpdateCollectTime = "[GNOSWAP-STAKER-003] not available to update collect time"
	errInvalidInput                  = "[GNOSWAP-STAKER-004] invalid input data"
	errInvalidUnstakingFee           = "[GNOSWAP-STAKER-005] invalid unstaking fee"
	errAlreadyStaked                 = "[GNOSWAP-STAKER-006] already staked position"
	errNonIncentivizedPool           = "[GNOSWAP-STAKER-007] pool is not incentivized"
	errCannotEndIncentive            = "[GNOSWAP-STAKER-008] cannot end incentive"
	errInvalidIncentiveStartTime     = "[GNOSWAP-STAKER-009] invalid incentive start time"
	errDefaultExternalToken          = "[GNOSWAP-STAKER-010] cannot delete default external token"
	errInvalidPoolPath               = "[GNOSWAP-STAKER-011] invalid pool path"
	errInvalidPoolTier               = "[GNOSWAP-STAKER-012] invalid pool tier"
	errDataNotFound                  = "[GNOSWAP-STAKER-013] requested data not found"
	errCalculationError              = "[GNOSWAP-STAKER-014] unexpected calculation error"
	errZeroLiquidity                 = "[GNOSWAP-STAKER-015] zero liquidity"
	errInvalidIncentiveDuration      = "[GNOSWAP-STAKER-016] invalid incentive duration"
	errNotAllowedForExternalReward   = "[GNOSWAP-STAKER-017] not allowed for external reward"
	errIncentiveAlreadyExists        = "[GNOSWAP-STAKER-018] incentive already exists"
	errOverflow                      = "[GNOSWAP-STAKER-019] overflow"
	errAddExistingToken              = "[GNOSWAP-STAKER-020] cannot add existing token"
	errInvalidAddress                = "[GNOSWAP-STAKER-021] invalid address"
	errIsNotEndedIncentive           = "[GNOSWAP-STAKER-022] incentive is not ended yet"
	errSpoofedRealm                  = "[GNOSWAP-STAKER-023] rlm does not match the current crossing frame"
)

func makeErrorWithDetails(message string, details string) error {
	return ufmt.Errorf("%s || %s", message, details)
}
