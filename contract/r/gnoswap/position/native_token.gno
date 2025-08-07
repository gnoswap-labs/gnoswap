package position

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/wugnot"
)

const (
	UGNOT_MIN_DEPOSIT_TO_WRAP = int64(1000)
	WUGNOT_PATH               = "gno.land/r/demo/wugnot"
	GNOT_DENOM                = "ugnot"
)

var (
	errFailedToWrapZeroUgnot = "cannot wrap 0 ugnot"
	errFailedToWrapBelowMin  = "amount(%d) < minimum(%d)"
)

// wrap wraps the specified amount of the native token `ugnot` into the wrapped token `wugnot`.
//
// Parameters:
//   - ugnotAmount (uint64): The amount of `ugnot` tokens to wrap into `wugnot`.
//   - to (std.Address): The recipient's address to receive the wrapped tokens.
//
// Returns:
//   - error: An error if the `ugnot` amount is zero, below the minimum wrapping threshold, or any other issue occurs.
//
// Example:
//
//	wrap(1000, userAddress)
//	- Wraps 1000 UGNOT into WUGNOT and transfers the WUGNOT to `userAddress`.
//
// Errors:
//   - Returns an error if `ugnotAmount` is zero or less than the minimum deposit threshold.
func wrap(ugnotAmount int64, to std.Address) error {
	if ugnotAmount == 0 || ugnotAmount < UGNOT_MIN_DEPOSIT_TO_WRAP {
		return ufmt.Errorf("amount(%d) < minimum(%d)", ugnotAmount, UGNOT_MIN_DEPOSIT_TO_WRAP)
	}

	wugnotAddr := std.DerivePkgAddr(WRAPPED_WUGNOT)
	transferUGNOT(positionAddr, wugnotAddr, ugnotAmount)

	wugnot.Deposit(cross)                   // POSITION HAS WUGNOT
	wugnot.Transfer(cross, to, ugnotAmount) // SEND WUGNOT: POSITION -> USER

	return nil
}

// unwrap converts a specified amount of `WUGNOT` tokens into `UGNOT` tokens
// and transfers the resulting `UGNOT` back to the specified recipient address.
//
// Parameters:
// - `wugnotAmount`: The amount of `WUGNOT` tokens to unwrap (uint64).
// - `to`: The recipient's address (std.Address) to receive the unwrapped `UGNOT`.
//
// Example:
// unwrap(100, userAddress)
// - Converts 100 WUGNOT into UGNOT and sends the resulting UGNOT to `userAddress`.
func unwrap(wugnotAmount int64, to std.Address) error {
	if wugnotAmount <= 0 {
		return ufmt.Errorf("amount(%d) is zero or negative", wugnotAmount)
	}

	wugnot.TransferFrom(cross, to, positionAddr, wugnotAmount) // SEND WUGNOT: USER -> POSITION
	wugnot.Withdraw(cross, wugnotAmount)                       // POSITION HAS UGNOT
	transferUGNOT(positionAddr, to, wugnotAmount)              // SEND UGNOT: POSITION -> USER
	return nil
}

// transferUGNOT transfers a specified amount of `UGNOT` tokens from one address to another.
// The function ensures that no transaction occurs if the transfer amount is zero.
// It uses the `std.BankerTypeRealmSend` banker type to facilitate the transfer.
//
// Parameters:
// - `from`: The sender's address (std.Address).
// - `to`: The recipient's address (std.Address).
// - `amount`: The amount of UGNOT tokens to transfer (uint64).
//
// Example:
// transferUGNOT(sender, receiver, 100) // Transfers 100 UGNOT from `sender` to `receiver`.
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

// isWrappedToken checks whether the tokenPath is wrapped token
func isWrappedToken(tokenPath string) bool {
	return tokenPath == WRAPPED_WUGNOT
}

// safeWrapNativeToken safely wraps the native token `ugnot` into the wrapped token `wugnot` for a user.
//
// Parameters:
//   - amount: The desired amount of `ugnot` to be wrapped.
//   - toAddress: The address of the user initiating the wrapping process.
//
// Returns:
//   - uint64: The amount of `ugnot` that was successfully wrapped into `wugnot`.
//
// Panics:
//   - If the sent `ugnot` amount is zero.
//   - If `amount` cannot be parsed into a valid uint64 value.
//   - If the sent `ugnot` amount is less than `amount`.
//   - If the `wrap` function fails to wrap the tokens.
//   - If there is a mismatch between the expected wrapped token amount and the user's balance after wrapping.
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

	// if nativeSentAmount is greater than amount, refund the excess amount
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

	// WRAP IT
	wugnotAddr := std.DerivePkgAddr(WUGNOT_PATH)
	currentRealmAddr := std.CurrentRealm().Address()

	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(currentRealmAddr, wugnotAddr, std.Coins{{"ugnot", ugnotAmount}})
	wugnot.Deposit(cross) // Position has wugnot

	// SEND WUGNOT: Position -> User
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
