package dca_order

import "errors"

var (
	// Order errors
	ErrOrderNotFound      = errors.New("[GNOSWAP-DCA-001] order not found")
	ErrNotOrderOwner      = errors.New("[GNOSWAP-DCA-002] caller is not the order owner")
	ErrGroupNotFound      = errors.New("[GNOSWAP-DCA-003] order group not found")
	ErrOrderStateNotFound = errors.New("[GNOSWAP-DCA-004] order state not found")

	// Validation errors
	ErrInvalidAmount     = errors.New("[GNOSWAP-DCA-010] invalid amount")
	ErrInvalidExecutions = errors.New("[GNOSWAP-DCA-011] invalid number of executions")
	ErrInvalidInterval   = errors.New("[GNOSWAP-DCA-012] invalid interval")

	// Balance errors
	ErrInsufficientBalance = errors.New("[GNOSWAP-DCA-020] insufficient balance")
	ErrNothingToClaim      = errors.New("[GNOSWAP-DCA-021] nothing to claim")

	// Admin errors
	ErrNotAdmin = errors.New("[GNOSWAP-DCA-030] caller is not admin")
)
