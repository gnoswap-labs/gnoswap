package v1

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errInvalidPct        = "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage"
	errInvalidAmount     = "[GNOSWAP-PROTOCOL_FEE-002] invalid amount"
	errProtocolFeeHalted = "[GNOSWAP-PROTOCOL_FEE-003] protocol fee halted"
	errSpoofedRealm      = "[GNOSWAP-PROTOCOL_FEE-004] rlm does not match the current crossing frame"
)

// makeErrorWithDetail creates an error with additional context.
func makeErrorWithDetail(message string, detail string) error {
	return ufmt.Errorf("%s || %s", message, detail)
}
