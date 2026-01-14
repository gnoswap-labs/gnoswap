package limit_order

import "errors"

var (
	// Order creation errors
	ErrInvalidPoolPath     = errors.New("[LIMIT_ORDER] invalid pool path")
	ErrInvalidTokenIn      = errors.New("[LIMIT_ORDER] invalid token in address")
	ErrInvalidTokenOut     = errors.New("[LIMIT_ORDER] invalid token out address")
	ErrSameToken           = errors.New("[LIMIT_ORDER] token in and token out must be different")
	ErrInvalidAmountIn     = errors.New("[LIMIT_ORDER] invalid amount in (must be > 0)")
	ErrInvalidMinAmountOut = errors.New("[LIMIT_ORDER] invalid min amount out (must be > 0)")
	ErrInvalidKeeperFee    = errors.New("[LIMIT_ORDER] invalid keeper fee")
	ErrInvalidSlippage     = errors.New("[LIMIT_ORDER] invalid slippage (max 10%)")
	ErrTokenPoolMismatch   = errors.New("[LIMIT_ORDER] tokens do not match pool path")
	ErrPoolNotFound        = errors.New("[LIMIT_ORDER] pool not found")
	ErrDeadlineTooShort    = errors.New("[LIMIT_ORDER] deadline too short")
	ErrDeadlineTooLong     = errors.New("[LIMIT_ORDER] deadline too long")

	// Order execution errors
	ErrOrderNotFound      = errors.New("[LIMIT_ORDER] order not found")
	ErrOrderNotActive     = errors.New("[LIMIT_ORDER] order is not active")
	ErrOrderExpired       = errors.New("[LIMIT_ORDER] order has expired")
	ErrOrderNotDeposited  = errors.New("[LIMIT_ORDER] order tokens not deposited")
	ErrPriceNotReached    = errors.New("[LIMIT_ORDER] limit price not reached")
	ErrSlippageExceeded   = errors.New("[LIMIT_ORDER] slippage exceeded, output less than minimum")
	ErrInsufficientOutput = errors.New("[LIMIT_ORDER] insufficient output amount")

	// Order cancellation errors
	ErrUnauthorized     = errors.New("[LIMIT_ORDER] unauthorized caller")
	ErrAlreadyExecuted  = errors.New("[LIMIT_ORDER] order already executed")
	ErrAlreadyCancelled = errors.New("[LIMIT_ORDER] order already cancelled")

	// Storage errors
	ErrStoreNotInitialized = errors.New("[LIMIT_ORDER] store not initialized")
)
