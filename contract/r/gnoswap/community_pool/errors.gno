package community_pool

import (
	"errors"
)

var (
	errNoPermission      = errors.New("[GNOSWAP-COMMUNITY_POOL-001] caller has no permission")
	errNotRegistered     = errors.New("[GNOSWAP-COMMUNITY_POOL-002] not registered")
	errAlreadyRegistered = errors.New("[GNOSWAP-COMMUNITY_POOL-003] already registered")
	errLocked            = errors.New("[GNOSWAP-COMMUNITY_POOL-004] can't transfer token while locked")
	errHalted            = errors.New("[GNOSWAP-COMMUNITY_POOL-005] halted")
)
