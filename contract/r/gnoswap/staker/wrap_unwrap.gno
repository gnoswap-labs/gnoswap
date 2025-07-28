package staker

import (
	"std"

	"gno.land/r/demo/wugnot"

	"gno.land/p/demo/ufmt"
)

const WUGNOT_ADDR std.Address = "g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6"

// wrap converts `ugnot` tokens into `wugnot` tokens.
//
// Parameters:
// - ugnotAmount (uint64): The amount of `ugnot` to wrap.
//
// Panics:
// - If `ugnotAmount` is less than or equal to 0.
// - If `ugnotAmount` is less than the minimum deposit required (`UGNOT_MIN_DEPOSIT_TO_WRAP`).
func wrap(ugnotAmount int64) {
	if ugnotAmount <= 0 {
		panic(makeErrorWithDetails(
			errWrapUnwrap,
			"cannot wrap 0 ugnot",
		))
	}

	if ugnotAmount < int64(UGNOT_MIN_DEPOSIT_TO_WRAP) {
		panic(makeErrorWithDetails(
			errWugnotMinimum,
			ufmt.Sprintf("amount(%d) < minimum(%d)", ugnotAmount, UGNOT_MIN_DEPOSIT_TO_WRAP),
		))
	}

	// WRAP IT
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(stakerAddr, WUGNOT_ADDR, std.Coins{{Denom: "ugnot", Amount: ugnotAmount}})
	wugnot.Deposit(cross) // STAKER HAS WUGNOT

	// SEND WUGNOT: STAKER -> USER
	wugnot.Transfer(cross, std.PreviousRealm().Address(), ugnotAmount)
}

// unwrap converts `wugnot` tokens back into `ugnot` tokens.
//
// Parameters:
// - wugnotAmount (uint64): The amount of `wugnot` to unwrap.
//
// Note:
// - If `wugnotAmount` is 0, the function simply returns without executing further steps.
func unwrap(wugnotAmount int64) {
	if wugnotAmount == 0 {
		return
	}

	// SEND WUGNOT: USER -> STAKER
	wugnot.TransferFrom(cross, std.PreviousRealm().Address(), stakerAddr, wugnotAmount)

	// UNWRAP IT
	wugnot.Withdraw(cross, wugnotAmount)

	// SEND GNOT: STAKER -> USER
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(stakerAddr, std.PreviousRealm().Address(), std.Coins{{Denom: "ugnot", Amount: wugnotAmount}})
}
