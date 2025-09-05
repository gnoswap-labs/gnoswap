package router

import (
	"std"

	"gno.land/r/gnoland/wugnot"

	"gno.land/p/nt/ufmt"
)

const (
	UGNOT_MIN_DEPOSIT_TO_WRAP int64 = 1000
	WUGNOT_PATH                     = "gno.land/r/gnoland/wugnot"
	GNOT                            = "gnot"
	GNOT_DENOM                      = "ugnot"
)

var (
	errFailedToWrapZeroUgnot = "cannot wrap 0 ugnot"
	errFailedToWrapBelowMin  = "amount(%d) < minimum(%d)"
)

// wrapWithTransfer wraps GNOT into WUGNOT and transfers it to the specified address.
func wrapWithTransfer(toAddress std.Address, amount int64) error {
	if amount <= 0 {
		return nil
	}

	if amount < UGNOT_MIN_DEPOSIT_TO_WRAP {
		return makeErrorWithDetails(
			errWugnotMinimum,
			ufmt.Sprintf("amount(%d) < minimum(%d)", amount, UGNOT_MIN_DEPOSIT_TO_WRAP),
		)
	}

	// transfer ugnot from fromAddress to current realm
	currentRealmAddr := std.CurrentRealm().Address()

	sentCoins := std.OriginSend()
	ugnotSent := sentCoins.AmountOf(GNOT_DENOM)
	if ugnotSent != amount {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("user(%s) sent ugnot(%d) amount not equal to rewardAmount(%d)", toAddress.String(), ugnotSent, amount),
		)
	}

	// wrap gnot to wugnot
	wugnotAddr := std.DerivePkgAddr(WUGNOT_PATH)
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(currentRealmAddr, wugnotAddr, sentCoins)
	wugnot.Deposit(cross)

	// if to address is not current realm, transfer wugnot to to address
	if toAddress != currentRealmAddr {
		wugnot.Transfer(cross, toAddress, amount)
	}

	return nil
}

// unwrapWithTransferFrom transfers WUGNOT from a source address, unwraps it to GNOT, and sends it to the target.
func unwrapWithTransferFrom(fromAddress, toAddress std.Address, wugnotAmount int64) error {
	if wugnotAmount == 0 {
		return nil
	}

	currentRealmAddr := std.CurrentRealm().Address()
	if fromAddress != currentRealmAddr {
		wugnot.TransferFrom(cross, fromAddress, currentRealmAddr, wugnotAmount)
	}

	wugnot.Withdraw(cross, wugnotAmount)

	sendCoins := std.Coins{{Denom: GNOT_DENOM, Amount: wugnotAmount}}
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(currentRealmAddr, toAddress, sendCoins)

	return nil
}

// unwrapWithTransfer unwraps WUGNOT to GNOT and sends it to the specified address.
func unwrapWithTransfer(toAddress std.Address, amount int64) error {
	if amount <= 0 {
		return nil
	}

	// unwrap wugnot to gnot
	wugnot.Withdraw(cross, amount)

	// send gnot to user
	sendCoins := std.Coins{{Denom: GNOT_DENOM, Amount: amount}}
	banker := std.NewBanker(std.BankerTypeRealmSend)
	currentRealmAddr := std.CurrentRealm().Address()
	banker.SendCoins(currentRealmAddr, toAddress, sendCoins)

	return nil
}
