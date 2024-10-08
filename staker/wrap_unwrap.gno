package staker

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
	banker.SendCoins(consts.STAKER_ADDR, wugnotAddr, std.Coins{{Denom: "ugnot", Amount: int64(ugnotAmount)}})
	wugnot.Deposit() // STAKER HAS WUGNOT

	// SEND WUGNOT: STAKER -> USER
	wugnot.Transfer(a2u(std.PrevRealm().Addr()), ugnotAmount)

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_prevRealm", prevRealm(),
		"p_ugnotAmount", uint64ToStr(ugnotAmount),
	)
}

func unwrap(wugnotAmount uint64) {
	if wugnotAmount == 0 {
		return
	}

	// SEND WUGNOT: USER -> STAKER
	wugnot.TransferFrom(a2u(std.PrevRealm().Addr()), a2u(consts.STAKER_ADDR), wugnotAmount)

	// UNWRAP IT
	wugnot.Withdraw(wugnotAmount)

	// SEND GNOT: STAKER -> USER
	banker := std.GetBanker(std.BankerTypeRealmSend)
	banker.SendCoins(consts.STAKER_ADDR, std.PrevRealm().Addr(), std.Coins{{Denom: "ugnot", Amount: int64(wugnotAmount)}})

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_prevRealm", prevRealm(),
		"p_wugnotAmount", uint64ToStr(wugnotAmount),
	)
}
