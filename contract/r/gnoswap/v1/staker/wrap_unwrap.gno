package staker

import (
	"std"

	"gno.land/r/demo/wugnot"

	"gno.land/p/demo/ufmt"
)

// wrapWithTransfer handles transferring tokens from a caller to a target address,
// with special handling for GNOT tokens that need to be wrapped into WUGNOT.
//
// Parameters:
// - toAddress: The address receiving the tokens
// - amount: The amount of tokens to transfer
//
// Returns:
// - error: Any error that occurred during the transfer
func wrapWithTransfer(toAddress std.Address, amount int64) error {
	if amount <= 0 {
		return nil
	}

	if amount < int64(UGNOT_MIN_DEPOSIT_TO_WRAP) {
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

// unwrapWithTransfer unwraps WUGNOT tokens to GNOT and transfers them to the target address
//
// Parameters:
// - toAddress: The address to receive the unwrapped GNOT
// - wugnotAmount: The amount of WUGNOT to unwrap and transfer
//
// Returns:
// - error: Any error that occurred during unwrapping and transfer
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

// unwrapWithTransferFrom transfers WUGNOT from a source address, unwraps it to GNOT,
// and sends the GNOT to a target address
//
// Parameters:
// - fromAddress: The address holding the WUGNOT tokens
// - toAddress: The address to receive the unwrapped GNOT
// - wugnotAmount: The amount of WUGNOT to transfer and unwrap
//
// Returns:
// - error: Any error that occurred during the transfer and unwrap process
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
