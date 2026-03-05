package v1

import (
	"chain/runtime"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoland/wugnot"
)

const (
	WUGNOT_PATH = "gno.land/r/gnoland/wugnot"
	GNOT_DENOM  = "ugnot"
)

// validateWugnotBalance validates that the user has sufficient WUGNOT balance.
// In the new flow, users must pre-wrap GNOT into WUGNOT.
// Pool pulls WUGNOT directly from the user via TransferFrom.
func (p *positionV1) validateWugnotBalance(wugnotAmount int64, from address) error {
	if wugnotAmount <= 0 {
		return ufmt.Errorf("amount(%d) is zero or negative", wugnotAmount)
	}

	balance := wugnot.BalanceOf(from)
	if balance < wugnotAmount {
		return ufmt.Errorf("insufficient wugnot balance: have(%d) need(%d)", balance, wugnotAmount)
	}

	return nil
}

// transferWugnot transfers WUGNOT back to the specified recipient address.
// The recipient receives WUGNOT directly (no longer unwraps to GNOT).
func (p *positionV1) transferWugnot(wugnotAmount int64, to address) error {
	if wugnotAmount <= 0 {
		return ufmt.Errorf("amount(%d) is zero or negative", wugnotAmount)
	}

	wugnot.Transfer(cross, to, wugnotAmount)
	return nil
}

// isNative checks whether the given token is a native token.
func isNative(token string) bool {
	return token == GNOT_DENOM
}

// isWrappedToken checks whether the tokenPath is wrapped token.
func isWrappedToken(tokenPath string) bool {
	return tokenPath == WUGNOT_PATH
}

// validateAndReturnWugnotAmount validates that the user has sufficient WUGNOT balance for the native token swap.
// In the new flow, users must pre-wrap GNOT into WUGNOT before calling position functions.
// Pool will pull WUGNOT directly from the user via TransferFrom.
// Returns the amount that will be used for the native token side.
func (p *positionV1) validateAndReturnWugnotAmount(amount int64, fromAddress address) (int64, error) {
	if amount == 0 {
		return 0, nil
	}

	balance := wugnot.BalanceOf(fromAddress)
	if balance < amount {
		return 0, makeErrorWithDetails(
			errWrapUnwrap,
			ufmt.Sprintf("insufficient wugnot balance: have(%d) need(%d)", balance, amount),
		)
	}

	return amount, nil
}

// transferWugnotFrom transfers WUGNOT from the caller to the specified address.
// The caller must have already deposited GNOT into WUGNOT and approved this contract.
func (p *positionV1) transferWugnotFrom(fromAddress, toAddress address, wugnotAmount int64) error {
	if wugnotAmount <= 0 {
		return makeErrorWithDetails(errWrapUnwrap, "cannot transfer 0 wugnot")
	}

	currentRealmAddr := runtime.CurrentRealm().Address()

	if toAddress == currentRealmAddr {
		wugnot.TransferFrom(cross, fromAddress, currentRealmAddr, wugnotAmount)
	} else {
		wugnot.TransferFrom(cross, fromAddress, toAddress, wugnotAmount)
	}

	return nil
}

// relayWugnot transfers WUGNOT from a source address to the target address.
// The recipient receives WUGNOT directly (no longer unwraps to GNOT).
func (p *positionV1) relayWugnot(fromAddress, toAddress address, wugnotAmount int64) error {
	if wugnotAmount <= 0 {
		return nil
	}

	currentRealmAddr := runtime.CurrentRealm().Address()
	if fromAddress != currentRealmAddr {
		wugnot.TransferFrom(cross, fromAddress, currentRealmAddr, wugnotAmount)
	}

	if toAddress != currentRealmAddr {
		wugnot.Transfer(cross, toAddress, wugnotAmount)
	}

	return nil
}
