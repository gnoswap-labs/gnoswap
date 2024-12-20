package position

import (
	"std"

	"gno.land/r/demo/wugnot"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/consts"
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
func wrap(ugnotAmount uint64, to std.Address) error {
	if ugnotAmount == 0 || ugnotAmount < consts.UGNOT_MIN_DEPOSIT_TO_WRAP {
		return ufmt.Errorf("amount(%d) < minimum(%d)", ugnotAmount, consts.UGNOT_MIN_DEPOSIT_TO_WRAP)
	}

	wugnotAddr := std.DerivePkgAddr(consts.WRAPPED_WUGNOT)
	transferUGNOT(consts.POSITION_ADDR, wugnotAddr, ugnotAmount)

	wugnot.Deposit()                      // POSITION HAS WUGNOT
	wugnot.Transfer(a2u(to), ugnotAmount) // SEND WUGNOT: POSITION -> USER

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
func unwrap(wugnotAmount uint64, to std.Address) error {
	if wugnotAmount == 0 {
		return ufmt.Errorf("amount(%d) is zero", wugnotAmount)
	}

	wugnot.TransferFrom(a2u(to), a2u(consts.POSITION_ADDR), wugnotAmount) // SEND WUGNOT: USER -> POSITION
	wugnot.Withdraw(wugnotAmount)                                         // POSITION HAS UGNOT
	transferUGNOT(consts.POSITION_ADDR, to, wugnotAmount)                 // SEND UGNOT: POSITION -> USER
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
func transferUGNOT(from, to std.Address, amount uint64) {
	if amount == 0 {
		return
	}

	banker := std.GetBanker(std.BankerTypeRealmSend)
	banker.SendCoins(from, to, std.Coins{
		{Denom: consts.UGNOT, Amount: int64(amount)},
	})
}

// refundUGNOT refunds a specified amount of `UGNOT` tokens to the provided address.
// This function uses `transferUGNOT` to perform the transfer from the contract's position address
// (`POSITION_ADDR`) to the recipient.
//
// Parameters:
// - `to`: The recipient's address (std.Address) who will receive the refund.
// - `amount`: The amount of `UGNOT` tokens to refund (uint64).
func refundUGNOT(to std.Address, amount uint64) {
	transferUGNOT(consts.POSITION_ADDR, to, amount)
}
