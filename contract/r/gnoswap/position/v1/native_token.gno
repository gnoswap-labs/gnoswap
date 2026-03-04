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

// wrap transfers WUGNOT from the caller to the position contract.
// The caller must have already deposited GNOT into WUGNOT and approved this contract.
func (p *positionV1) wrap(wugnotAmount int64, from address) error {
	if wugnotAmount <= 0 {
		return ufmt.Errorf("amount(%d) is zero or negative", wugnotAmount)
	}

	positionAddr := mustGetPositionAddress()
	wugnot.TransferFrom(cross, from, positionAddr, wugnotAmount)

	return nil
}

// unwrap transfers WUGNOT back to the specified recipient address.
// The recipient receives WUGNOT directly (no longer unwraps to GNOT).
func (p *positionV1) unwrap(wugnotAmount int64, to address) error {
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

// safeWrapNativeToken safely transfers WUGNOT from the user to the position contract.
// The user must have already deposited GNOT into WUGNOT and approved this contract.
// Returns the amount of WUGNOT that was successfully transferred.
func (p *positionV1) safeWrapNativeToken(amount int64, fromAddress address) (int64, error) {
	if amount == 0 {
		return 0, nil
	}

	positionAddr := mustGetPositionAddress()
	beforeBalance := wugnot.BalanceOf(positionAddr)

	wugnot.TransferFrom(cross, fromAddress, positionAddr, amount)

	balanceDiff := wugnot.BalanceOf(positionAddr) - beforeBalance
	if balanceDiff != amount {
		return 0, makeErrorWithDetails(
			errWrapUnwrap,
			ufmt.Sprintf("expected wugnot transfer(%d) but got(%d)", amount, balanceDiff),
		)
	}

	return amount, nil
}

// wrapWithTransfer transfers WUGNOT from the caller to the specified address.
// The caller must have already deposited GNOT into WUGNOT and approved this contract.
func (p *positionV1) wrapWithTransfer(fromAddress, toAddress address, wugnotAmount int64) error {
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

// unwrapWithTransferFrom transfers WUGNOT from a source address to the target address.
// The recipient receives WUGNOT directly (no longer unwraps to GNOT).
func (p *positionV1) unwrapWithTransferFrom(fromAddress, toAddress address, wugnotAmount int64) error {
	if wugnotAmount == 0 {
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
