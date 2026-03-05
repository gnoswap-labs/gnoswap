package v1

import (
	"chain/runtime"

	"gno.land/r/gnoland/wugnot"
)

const (
	WUGNOT_PATH = "gno.land/r/gnoland/wugnot"
	GNOT_DENOM  = "ugnot"
)

// transferWugnotFrom transfers WUGNOT from the caller to the specified address.
// The caller must have already deposited GNOT into WUGNOT and approved this contract.
func transferWugnotFrom(fromAddress, toAddress address, amount int64) error {
	if amount <= 0 {
		return nil
	}

	currentRealmAddr := runtime.CurrentRealm().Address()

	// transfer wugnot from user to current realm (or toAddress)
	if toAddress == currentRealmAddr {
		wugnot.TransferFrom(cross, fromAddress, currentRealmAddr, amount)
	} else {
		wugnot.TransferFrom(cross, fromAddress, toAddress, amount)
	}

	return nil
}

// relayWugnot transfers WUGNOT from a source address to the target address.
// The recipient receives WUGNOT directly (no longer unwraps to GNOT).
func relayWugnot(fromAddress, toAddress address, wugnotAmount int64) error {
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

// transferWugnot transfers WUGNOT to the specified address.
// The recipient receives WUGNOT directly (no longer unwraps to GNOT).
func transferWugnot(toAddress address, amount int64) error {
	if amount <= 0 {
		return nil
	}

	wugnot.Transfer(cross, toAddress, amount)

	return nil
}
