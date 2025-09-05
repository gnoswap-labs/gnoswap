package position

import (
	"std"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoland/wugnot"
)

const (
	UGNOT_MIN_DEPOSIT_TO_WRAP = int64(1000)
	WUGNOT_PATH               = "gno.land/r/gnoland/wugnot"
	GNOT_DENOM                = "ugnot"
)

var (
	errFailedToWrapZeroUgnot = "cannot wrap 0 ugnot"
	errFailedToWrapBelowMin  = "amount(%d) < minimum(%d)"
)

// wrap wraps the specified amount of the native token ugnot into the wrapped token wugnot.
// Returns an error if ugnotAmount is zero or less than the minimum deposit threshold.
func wrap(ugnotAmount int64, to std.Address) error {
	if ugnotAmount == 0 || ugnotAmount < UGNOT_MIN_DEPOSIT_TO_WRAP {
		return ufmt.Errorf("amount(%d) < minimum(%d)", ugnotAmount, UGNOT_MIN_DEPOSIT_TO_WRAP)
	}

	wugnotAddr := std.DerivePkgAddr(WRAPPED_WUGNOT)
	transferUGNOT(positionAddr, wugnotAddr, ugnotAmount)

	wugnot.Deposit(cross)                   // position has wugnot
	wugnot.Transfer(cross, to, ugnotAmount) // send wugnot: position -> user

	return nil
}

// unwrap converts a specified amount of WUGNOT tokens into UGNOT tokens
// and transfers the resulting UGNOT back to the specified recipient address.
func unwrap(wugnotAmount int64, to std.Address) error {
	if wugnotAmount <= 0 {
		return ufmt.Errorf("amount(%d) is zero or negative", wugnotAmount)
	}

	wugnot.TransferFrom(cross, to, positionAddr, wugnotAmount) // send wugnot: user -> position
	wugnot.Withdraw(cross, wugnotAmount)                       // position has ugnot
	transferUGNOT(positionAddr, to, wugnotAmount)              // send ugnot: position -> user
	return nil
}

// transferUGNOT transfers a specified amount of UGNOT tokens from one address to another.
// The function ensures that no transaction occurs if the transfer amount is zero.
// Panics if amount is negative or if sender has insufficient balance.
func transferUGNOT(from, to std.Address, amount int64) {
	if amount < 0 {
		panic(ufmt.Sprintf("amount(%d) is negative", amount))
	}
	if amount == 0 {
		return
	}

	banker := std.NewBanker(std.BankerTypeRealmSend)
	fromBalance := banker.GetCoins(from).AmountOf(UGNOT)
	if fromBalance < amount {
		panic(newErrorWithDetail(
			errInsufficientUGNOT,
			ufmt.Sprintf("from(%s) balance(%d) is less than amount(%d)", from, fromBalance, amount)))
	}
	banker.SendCoins(from, to, std.Coins{
		{Denom: UGNOT, Amount: amount},
	})
}

// isNative checks whether the given token is a native token.
func isNative(token string) bool {
	return token == GNOT
}

// isWrappedToken checks whether the tokenPath is wrapped token.
func isWrappedToken(tokenPath string) bool {
	return tokenPath == WRAPPED_WUGNOT
}

// safeWrapNativeToken safely wraps the native token ugnot into the wrapped token wugnot for a user.
// Returns the amount of ugnot that was successfully wrapped into wugnot.
// Returns an error if the sent ugnot amount is zero, less than requested, or if wrapping fails.
func safeWrapNativeToken(amount int64, toAddress std.Address) (int64, error) {
	// if amount is zero, return 0
	if amount == 0 {
		return 0, nil
	}

	beforeWrappedBalance := wugnot.BalanceOf(toAddress)
	nativeSentAmount := std.OriginSend().AmountOf(UGNOT)

	if nativeSentAmount <= 0 {
		return 0, makeErrorWithDetails(errZeroUGNOT, "amount of ugnot is zero")
	}

	if nativeSentAmount < amount {
		return 0, makeErrorWithDetails(errInsufficientUGNOT, "amount of ugnot is less than desired amount")
	}

	// If nativeSentAmount is greater than amount, refund the excess amount.
	if nativeSentAmount > amount {
		excessAmount := nativeSentAmount - amount
		transferUGNOT(positionAddr, toAddress, excessAmount)

		nativeSentAmount = amount
	}

	if err := wrapWithTransfer(nativeSentAmount, toAddress); err != nil {
		return 0, err
	}

	afterWrappedBalance := wugnot.BalanceOf(toAddress)
	balanceDiff := afterWrappedBalance - beforeWrappedBalance

	if balanceDiff != nativeSentAmount {
		return 0, makeErrorWithDetails(
			errWrapUnwrap,
			ufmt.Sprintf("amount of ugnot (%d) is not equal to amount of wugnot. (diff: %d)", nativeSentAmount, balanceDiff),
		)
	}

	return nativeSentAmount, nil
}

func wrapWithTransfer(ugnotAmount int64, toAddress std.Address) error {
	if ugnotAmount <= 0 {
		return makeErrorWithDetails(errWrapUnwrap, errFailedToWrapZeroUgnot)
	}

	if ugnotAmount < UGNOT_MIN_DEPOSIT_TO_WRAP {
		return makeErrorWithDetails(
			errWugnotMinimum,
			ufmt.Sprintf(errFailedToWrapBelowMin, ugnotAmount, UGNOT_MIN_DEPOSIT_TO_WRAP),
		)
	}

	// wrap it
	wugnotAddr := std.DerivePkgAddr(WUGNOT_PATH)
	currentRealmAddr := std.CurrentRealm().Address()

	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(currentRealmAddr, wugnotAddr, std.Coins{{"ugnot", ugnotAmount}})
	wugnot.Deposit(cross) // Position has wugnot

	// send wugnot: position -> user
	wugnot.Transfer(cross, toAddress, ugnotAmount)

	return nil
}

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
	banker.SendCoins(currentRealmAddr, toAddress, std.Coins{{"ugnot", wugnotAmount}})

	return nil
}
