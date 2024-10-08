package position

import (
	"std"

	"gno.land/r/demo/wugnot"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v2/consts"
)

func wrap(ugnotAmount uint64, to std.Address) {
	if ugnotAmount == 0 {
		return
	}

	if ugnotAmount < consts.UGNOT_MIN_DEPOSIT_TO_WRAP {
		panic(ufmt.Sprintf("Deposit below minimum: %d/%d ugnot.", ugnotAmount, consts.UGNOT_MIN_DEPOSIT_TO_WRAP))
	}

	// WRAP IT
	wugnotAddr := std.DerivePkgAddr(consts.WRAPPED_WUGNOT)
	banker := std.GetBanker(std.BankerTypeRealmSend)

	banker.SendCoins(consts.POSITION_ADDR, wugnotAddr, std.Coins{{"ugnot", int64(ugnotAmount)}})
	wugnot.Deposit() // POSITION HAS WUGNOT

	// SEND WUGNOT: POSITION -> USER
	wugnot.Transfer(a2u(to), ugnotAmount)

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_prevRealm", prevRealm(),
		"p_ugnotAmount", uint64ToStr(ugnotAmount),
	)
}

func unwrap(wugnotAmount uint64, to std.Address) {
	if wugnotAmount == 0 {
		return
	}

	// SEND WUGNOT: USER -> POSITION
	wugnot.TransferFrom(a2u(to), a2u(consts.POSITION_ADDR), wugnotAmount)

	// UNWRAP IT
	wugnot.Withdraw(wugnotAmount)

	// SEND GNOT: POSITION -> USER
	banker := std.GetBanker(std.BankerTypeRealmSend)
	banker.SendCoins(consts.POSITION_ADDR, to, std.Coins{{"ugnot", int64(wugnotAmount)}})

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_prevRealm", prevRealm(),
		"p_wugnotAmount", uint64ToStr(wugnotAmount),
	)
}
