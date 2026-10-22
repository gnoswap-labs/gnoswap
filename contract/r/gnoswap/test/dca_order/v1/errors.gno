package dca_order

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errInvalidPool        = "[GNOSWAP-DCA-ORDER-001] invalid pool"
	errInvalidToken       = "[GNOSWAP-DCA-ORDER-002] invalid token"
	errInvalidInterval    = "[GNOSWAP-DCA-ORDER-003] invalid interval"
	errInvalidAmount      = "[GNOSWAP-DCA-ORDER-004] invalid amount"
	errInvalidExecutions  = "[GNOSWAP-DCA-ORDER-005] invalid number of executions"
	errOrderNotFound      = "[GNOSWAP-DCA-ORDER-006] order not found"
	errOrderNotActive     = "[GNOSWAP-DCA-ORDER-007] order is not active"
	errNotOrderOwner      = "[GNOSWAP-DCA-ORDER-008] caller is not the order owner"
	errGroupNotFound      = "[GNOSWAP-DCA-ORDER-009] group not found"
	errGroupNotExecutable = "[GNOSWAP-DCA-ORDER-010] group is not executable"
	errSwapMismatch       = "[GNOSWAP-DCA-ORDER-011] swap result mismatch"
	errInvalidConfig      = "[GNOSWAP-DCA-ORDER-012] invalid config"
	errInvalidAddress     = "[GNOSWAP-DCA-ORDER-013] invalid address"
	errInsufficientFee    = "[GNOSWAP-DCA-ORDER-014] insufficient pending fee"
	errInvalidState       = "[GNOSWAP-DCA-ORDER-015] invalid accounting state"
	errOverflow           = "[GNOSWAP-DCA-ORDER-016] overflow"
	errReentrant          = "[GNOSWAP-DCA-ORDER-017] reentrant call during group execution"
	errFeeTooHigh         = "[GNOSWAP-DCA-ORDER-019] creation fee exceeds the caller's maximum"
	errInvalidCursor      = "[GNOSWAP-DCA-ORDER-020] invalid cursor"
	errClaimFirst         = "[GNOSWAP-DCA-ORDER-022] accrued output exceeds a single transfer; claim before cancelling"
)

func makeErrorWithDetails(message string, details string) error {
	return ufmt.Errorf("%s || %s", message, details)
}
