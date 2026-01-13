package dust_converter

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errInvalidAmount   = errors.New("[GNOSWAP-DUST_CONVERTER-001] invalid amount")
	errInvalidCooldown = errors.New("[GNOSWAP-DUST_CONVERTER-002] cooldown not elapsed")
	errInvalidInput    = errors.New("[GNOSWAP-DUST_CONVERTER-003] invalid input")
)

func makeErrorWithDetail(err error, detail string) error {
	return ufmt.Errorf("%s || %s", err.Error(), detail)
}
