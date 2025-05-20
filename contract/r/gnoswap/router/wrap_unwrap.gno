package router

import (
	"std"

	"gno.land/r/demo/wugnot"

	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
)

var (
	errFailedToWrapZeroUgnot = "cannot wrap 0 ugnot"
	errFailedToWrapBelowMin = "amount(%d) < minimum(%d)"
)

func wrap(ugnotAmount int64) {
	if ugnotAmount <= 0 {
		panic(addDetailToError(errWrapUnwrap, errFailedToWrapZeroUgnot))
	}

	if ugnotAmount < consts.UGNOT_MIN_DEPOSIT_TO_WRAP {
		panic(addDetailToError(
			errWugnotMinimum,
			ufmt.Sprintf(errFailedToWrapBelowMin, ugnotAmount, consts.UGNOT_MIN_DEPOSIT_TO_WRAP),
		))
	}

	// WRAP IT
	wugnotAddr := std.DerivePkgAddr(consts.WRAPPED_WUGNOT)
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(routerAddr, wugnotAddr, std.Coins{{"ugnot", int64(ugnotAmount)}})
	cross(wugnot.Deposit)() // ROUTER HAS WUGNOT

	// SEND WUGNOT: ROUTER -> USER
	cross(wugnot.Transfer)(std.PreviousRealm().Address(), ugnotAmount)
}

func unwrap(wugnotAmount uint64) {
	if wugnotAmount == 0 {
		return
	}

	// SEND WUGNOT: USER -> ROUTER
	cross(wugnot.TransferFrom)(std.PreviousRealm().Address(), routerAddr, wugnotAmount)

	// UNWRAP IT
	cross(wugnot.Withdraw)(wugnotAmount)

	// SEND GNOT: ROUTER -> USER
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(routerAddr, std.PreviousRealm().Address(), std.Coins{{"ugnot", int64(wugnotAmount)}})
}
