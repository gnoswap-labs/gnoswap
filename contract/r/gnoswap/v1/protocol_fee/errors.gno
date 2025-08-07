package protocol_fee

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errNoPermission  = errors.New("[GNOSWAP-PROTOCOL_FEE-001] caller has no permission")
	errInvalidPct    = errors.New("[GNOSWAP-PROTOCOL_FEE-002] invalid percentage")
	errInvalidAmount = errors.New("[GNOSWAP-PROTOCOL_FEE-003] invalid amount")
)

func makeErrorWithDetail(err error, detail string) error {
	return ufmt.Errorf("%s || %s", err.Error(), detail)
}