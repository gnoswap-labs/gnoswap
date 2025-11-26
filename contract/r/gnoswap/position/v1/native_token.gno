package v1

import (
	"chain"
	"chain/banker"
	"chain/runtime"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/common"
)

const (
	UGNOT_MIN_DEPOSIT_TO_WRAP = int64(1000)
	WUGNOT_PATH               = "gno.land/r/gnoland/wugnot"
)

var (
	errFailedToWrapZeroUgnot = "cannot wrap 0 ugnot"
	errFailedToWrapBelowMin  = "amount(%d) < minimum(%d)"
)

// wrap wraps the specified amount of the native token ugnot into the wrapped token wugnot.
// Returns an error if ugnotAmount is zero or less than the minimum deposit threshold.
func (p *positionV1) wrap(ugnotAmount int64, to address) error {
	if ugnotAmount == 0 || ugnotAmount < UGNOT_MIN_DEPOSIT_TO_WRAP {
		return ufmt.Errorf("amount(%d) < minimum(%d)", ugnotAmount, UGNOT_MIN_DEPOSIT_TO_WRAP)
	}

	wugnotAddr := chain.PackageAddress(WRAPPED_WUGNOT)
	p.transferUGNOT(positionAddr, wugnotAddr, ugnotAmount)

	wugnot.Deposit(cross)                   // position has wugnot
	wugnot.Transfer(cross, to, ugnotAmount) // send wugnot: position -> user

	return nil
}

// unwrap converts a specified amount of WUGNOT tokens into UGNOT tokens
// and transfers the resulting UGNOT back to the specified recipient address.
func (p *positionV1) unwrap(wugnotAmount int64, to address) error {
	if wugnotAmount <= 0 {
		return ufmt.Errorf("amount(%d) is zero or negative", wugnotAmount)
	}

	wugnot.TransferFrom(cross, to, positionAddr, wugnotAmount) // send wugnot: user -> position
	wugnot.Withdraw(cross, wugnotAmount)                       // position has ugnot
	p.transferUGNOT(positionAddr, to, wugnotAmount)            // send ugnot: position -> user
	return nil
}

// transferUGNOT transfers a specified amount of UGNOT tokens from one address to another.
// The function ensures that no transaction occurs if the transfer amount is zero.
// Panics if amount is negative or if sender has insufficient balance.
func (p *positionV1) transferUGNOT(from, to address, amount int64) {
	if amount < 0 {
		panic(ufmt.Sprintf("amount(%d) is negative", amount))
	}
	if amount == 0 {
		return
	}

	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	fromBalance := banker_.GetCoins(from).AmountOf(common.GNOT_DENOM)
	if fromBalance < amount {
		panic(newErrorWithDetail(
			errInsufficientUGNOT,
			ufmt.Sprintf("from(%s) balance(%d) is less than amount(%d)", from, fromBalance, amount)))
	}
	banker_.SendCoins(from, to, chain.Coins{
		{Denom: common.GNOT_DENOM, Amount: amount},
	})
}

// isNative checks whether the given token is a native token.
func isNative(token string) bool {
	return token == common.GNOT_DENOM
}

// isWrappedToken checks whether the tokenPath is wrapped token.
func isWrappedToken(tokenPath string) bool {
	return tokenPath == WRAPPED_WUGNOT
}

// safeWrapNativeToken safely wraps the native token ugnot into the wrapped token wugnot for a user.
// Returns the amount of ugnot that was successfully wrapped into wugnot.
// Returns an error if the sent ugnot amount is zero, less than requested, or if wrapping fails.
func (p *positionV1) safeWrapNativeToken(amount int64, toAddress address) (int64, error) {
	// if amount is zero, return 0
	if amount == 0 {
		return 0, nil
	}

	beforeWrappedBalance := wugnot.BalanceOf(toAddress)
	nativeSentAmount := banker.OriginSend().AmountOf(common.GNOT_DENOM)

	if nativeSentAmount <= 0 {
		return 0, makeErrorWithDetails(errZeroUGNOT, "amount of ugnot is zero")
	}

	if nativeSentAmount < amount {
		return 0, makeErrorWithDetails(errInsufficientUGNOT, "amount of ugnot is less than desired amount")
	}

	// If nativeSentAmount is greater than amount, refund the excess amount.
	if nativeSentAmount > amount {
		excessAmount := nativeSentAmount - amount
		p.transferUGNOT(positionAddr, toAddress, excessAmount)

		nativeSentAmount = amount
	}

	if err := p.wrapWithTransfer(nativeSentAmount, toAddress); err != nil {
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

func (p *positionV1) wrapWithTransfer(ugnotAmount int64, toAddress address) error {
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
	wugnotAddr := chain.PackageAddress(WUGNOT_PATH)
	currentRealmAddr := runtime.CurrentRealm().Address()

	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(currentRealmAddr, wugnotAddr, chain.Coins{{common.GNOT_DENOM, ugnotAmount}})
	wugnot.Deposit(cross) // Position has wugnot

	// send wugnot: position -> user
	wugnot.Transfer(cross, toAddress, ugnotAmount)

	return nil
}

func (p *positionV1) unwrapWithTransferFrom(fromAddress, toAddress address, wugnotAmount int64) error {
	if wugnotAmount == 0 {
		return nil
	}

	currentRealmAddr := runtime.CurrentRealm().Address()
	if fromAddress != currentRealmAddr {
		wugnot.TransferFrom(cross, fromAddress, currentRealmAddr, wugnotAmount)
	}

	wugnot.Withdraw(cross, wugnotAmount)

	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(currentRealmAddr, toAddress, chain.Coins{{common.GNOT_DENOM, wugnotAmount}})

	return nil
}
