package dca_order

import "errors"

var (
	ErrOrderNotFound       = errors.New("order not found")
	ErrNotOrderOwner       = errors.New("caller is not the order owner")
	ErrGroupNotFound       = errors.New("order group not found")
	ErrOrderStateNotFound  = errors.New("order state not found")
	ErrInvalidAmount       = errors.New("invalid amount")
	ErrInvalidExecutions   = errors.New("invalid number of executions")
	ErrInvalidInterval     = errors.New("invalid interval")
	ErrInsufficientBalance = errors.New("insufficient balance")
	ErrNothingToClaim      = errors.New("nothing to claim")
	ErrNotAdmin            = errors.New("caller is not admin")
)
