package staker

import (
	"std"

	"gno.land/r/gnoland/wugnot"

	"gno.land/p/nt/ufmt"
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

// unwrapWithTransfer unwraps WUGNOT to GNOT and sends it to the specified address.
func unwrapWithTransfer(toAddress std.Address, wugnotAmount int64) error {
	if wugnotAmount == 0 {
		return nil
	}

	wugnot.Withdraw(cross, wugnotAmount)

	currentRealmAddr := std.CurrentRealm().Address()
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(currentRealmAddr, toAddress, std.Coins{{"ugnot", int64(wugnotAmount)}})

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

	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(currentRealmAddr, toAddress, std.Coins{{"ugnot", int64(wugnotAmount)}})

	return nil
}
