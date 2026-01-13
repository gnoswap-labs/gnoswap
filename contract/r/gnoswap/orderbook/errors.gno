package orderbook

import "gno.land/p/nt/ufmt"

var (
	ErrInvalidTickId           = ufmt.Errorf("invalid tick id")
	ErrInvalidOrderDirection   = ufmt.Errorf("invalid order direction")
	ErrInvalidQuantity         = ufmt.Errorf("invalid quantity")
	ErrInvalidBounty           = ufmt.Errorf("invalid bounty: must be <= 1%%")
	ErrOrderNotFound           = ufmt.Errorf("order not found")
	ErrUnauthorized            = ufmt.Errorf("unauthorized")
	ErrZeroClaim               = ufmt.Errorf("zero claim: order not filled yet")
	ErrInvalidTokenPair        = ufmt.Errorf("invalid token pair")
	ErrInvalidPrice            = ufmt.Errorf("invalid price")
	ErrInsufficientBalance     = ufmt.Errorf("insufficient balance")
	ErrOrderbookNotFound       = ufmt.Errorf("orderbook not found")
	ErrOrderbookAlreadyExists  = ufmt.Errorf("orderbook already exists")
	ErrInactiveOrderbook       = ufmt.Errorf("orderbook is inactive")
	ErrSlippageExceeded        = ufmt.Errorf("slippage exceeded")
)
