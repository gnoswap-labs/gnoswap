package position_manager

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errCannotSetURI          = errors.New("[GNOSWAP-GNFT-002] cannot set URI")
	errInvalidAddress        = errors.New("[GNOSWAP-GNFT-004] invalid addresss")
	errNotTokenOwner         = errors.New("[GNOSWAP-GNFT-001] caller is not token owner")
	errNotOwnerOrApproved    = errors.New("[GNOSWAP-GNFT-006] caller is not token owner or approved")
	errTokenNotExists        = errors.New("[GNOSWAP-GNFT-007] token does not exist")
	errTransferToSelf        = errors.New("[GNOSWAP-GNFT-008] cannot transfer to self")
	errInvalidTokenId        = errors.New("[GNOSWAP-NFT-POSITION-001] invalid token ID")
	errNotAuthorized         = errors.New("[GNOSWAP-NFT-POSITION-002] not authorized")
	errPositionNotCleared    = errors.New("[GNOSWAP-NFT-POSITION-003] position not cleared")
	errInsufficientLiquidity = errors.New("[GNOSWAP-NFT-POSITION-004] insufficient liquidity")
	errZeroLiquidity         = errors.New("[GNOSWAP-NFT-POSITION-005] liquidity must be greater than 0")
	errMustCollectSomething  = errors.New("[GNOSWAP-NFT-POSITION-006] must collect something")
	errTransactionExpired    = errors.New("[GNOSWAP-NFT-POSITION-007] transaction expired")
	errOnlyUserCanCall       = errors.New("[GNOSWAP-NFT-POSITION-008] only users can call this function")
	errSlippageExceeded      = errors.New("[GNOSWAP-NFT-POSITION-009] slippage exceeded")
	errInvalidRecipient      = errors.New("[GNOSWAP-NFT-POSITION-010] invalid recipient")
	errPositionDoesNotExist  = errors.New("[GNOSWAP-NFT-POSITION-011] position does not exist")
	errInvalidAmount         = errors.New("[GNOSWAP-NFT-POSITION-012] invalid amount")
	errInvalidTickRange      = errors.New("[GNOSWAP-NFT-POSITION-013] invalid tick range")
	errPoolDoesNotExist      = errors.New("[GNOSWAP-NFT-POSITION-014] pool does not exist")
	errTokenTransferFailed   = errors.New("[GNOSWAP-NFT-POSITION-015] token transfer failed")
	errInvalidFeeGrowth      = errors.New("[GNOSWAP-NFT-POSITION-016] invalid fee growth")
	errInvalidPoolKey        = errors.New("[GNOSWAP-NFT-POSITION-017] invalid pool key")
	errPositionAlreadyBurned = errors.New("[GNOSWAP-NFT-POSITION-018] position already burned")
	errCannotApproveToSelf   = errors.New("[GNOSWAP-NFT-POSITION-019] cannot approve to self")
	errInvalidOperator       = errors.New("[GNOSWAP-NFT-POSITION-020] invalid operator")
)

// makeErrorWithDetails creates an error with additional context.
func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
