package router

import (
	"std"

	"gno.land/r/demo/wugnot"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v2/consts"
)

func wrap(ugnotAmount uint64) {
	if ugnotAmount <= 0 {
		panic(ufmt.Sprintf("cannot wrap 0 ugnot"))
	}

	if ugnotAmount < consts.UGNOT_MIN_DEPOSIT_TO_WRAP {
		panic(ufmt.Sprintf("Deposit below minimum: %d/%d ugnot.", ugnotAmount, consts.UGNOT_MIN_DEPOSIT_TO_WRAP))
	}

	// WRAP IT
	wugnotAddr := std.DerivePkgAddr(consts.WRAPPED_WUGNOT)
	banker := std.GetBanker(std.BankerTypeRealmSend)
	banker.SendCoins(consts.ROUTER_ADDR, wugnotAddr, std.Coins{{"ugnot", int64(ugnotAmount)}})
	wugnot.Deposit() // ROUTER HAS WUGNOT

	// SEND WUGNOT: ROUTER -> USER
	wugnot.Transfer(a2u(std.GetOrigCaller()), ugnotAmount)
}

func unwrap(wugnotAmount uint64) {
	if wugnotAmount == 0 {
		return
	}

	// SEND WUGNOT: USER -> ROUTER
	wugnot.TransferFrom(a2u(std.GetOrigCaller()), a2u(consts.ROUTER_ADDR), wugnotAmount)

	// UNWRAP IT
	wugnot.Withdraw(wugnotAmount)

	// SEND GNOT: ROUTER -> USER
	banker := std.GetBanker(std.BankerTypeRealmSend)
	banker.SendCoins(consts.ROUTER_ADDR, std.GetOrigCaller(), std.Coins{{"ugnot", int64(wugnotAmount)}})
}
