package gnft

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission     = errors.New("[GNOSWAP-GNFT-001] caller has no permission")
	errCannotSetURI     = errors.New("[GNOSWAP-GNFT-002] cannot set URI")
	errNoTokenForCaller = errors.New("[GNOSWAP-GNFT-003] no token for caller")
	errInvalidAddress   = errors.New("[GNOSWAP-GNFT-004] invalid addresss")
)

func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
