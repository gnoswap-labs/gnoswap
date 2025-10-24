package v1

import (
	"chain"
	"chain/banker"
	"chain/runtime"

	"gno.land/r/gnoland/wugnot"

	"gno.land/p/nt/ufmt"
)

// wrapWithTransfer wraps GNOT into WUGNOT and transfers it to the specified address.
func wrapWithTransfer(toAddress address, amount int64) error {
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
	currentRealmAddr := runtime.CurrentRealm().Address()

	sentCoins := banker.OriginSend()
	ugnotSent := sentCoins.AmountOf(GNOT_DENOM)
	if ugnotSent != amount {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("user(%s) sent ugnot(%d) amount not equal to rewardAmount(%d)", toAddress.String(), ugnotSent, amount),
		)
	}

	// wrap gnot to wugnot
	wugnotAddr := chain.PackageAddress(WUGNOT_PATH)
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(currentRealmAddr, wugnotAddr, sentCoins)
	wugnot.Deposit(cross)

	// if to address is not current realm, transfer wugnot to to address
	if toAddress != currentRealmAddr {
		wugnot.Transfer(cross, toAddress, amount)
	}

	return nil
}

// unwrapWithTransfer unwraps WUGNOT to GNOT and sends it to the specified address.
func unwrapWithTransfer(toAddress address, wugnotAmount int64) error {
	if wugnotAmount == 0 {
		return nil
	}

	wugnot.Withdraw(cross, wugnotAmount)

	currentRealmAddr := runtime.CurrentRealm().Address()
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(currentRealmAddr, toAddress, chain.Coins{{"ugnot", int64(wugnotAmount)}})

	return nil
}

// unwrapWithTransferFrom transfers WUGNOT from a source address, unwraps it to GNOT, and sends it to the target.
func unwrapWithTransferFrom(fromAddress, toAddress address, wugnotAmount int64) error {
	if wugnotAmount == 0 {
		return nil
	}

	currentRealmAddr := runtime.CurrentRealm().Address()
	if fromAddress != currentRealmAddr {
		wugnot.TransferFrom(cross, fromAddress, currentRealmAddr, wugnotAmount)
	}

	wugnot.Withdraw(cross, wugnotAmount)

	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(currentRealmAddr, toAddress, chain.Coins{{"ugnot", int64(wugnotAmount)}})

	return nil
}
