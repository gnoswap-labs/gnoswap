package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/wugnot"
)

func wrap(tokenPath string, amount uint64) {
	if tokenPath != GNOT {
		return
	}

	caller := std.GetOrigCaller()
	sentCoins := std.GetOrigSend()

	if len(sentCoins) != 1 {
		panic(ufmt.Sprintf("[STAKER] wrap_unwrap.gno__wrap() || NEED TO SEND ONLY ONE COIN, BUT %d SENT", len(sentCoins)))
	}
	sentCoin := sentCoins[0]

	if sentCoin.Denom != "ugnot" {
		panic(ufmt.Sprintf("[STAKER] wrap_unwrap.gno__wrap() || SEND ONLY UGNOT, BUT %s SENT", sentCoin.Denom))
	}

	if sentCoin.Amount != amount {
		panic(ufmt.Sprintf("[STAKER] wrap_unwrap.gno__wrap() || COIN AMOUNT(%d) != REWARD AMOUNT(%d)", sentCoin.Amount, amount))
	}

	// println("[DEBUG__STAKER] wrap_unwrap.gno__wrap() || WRAP AMOUNT:", sentCoin.Amount)
	wugnot.Wrap(a2u(caller), uint64(sentCoin.Amount))
}

func unWrap(tokenPath string, amount uint64) {
	if tokenPath != GNOT {
		return
	}

	caller := std.GetOrigCaller()

	refund := std.Coins{
		std.Coin{
			Denom:  "ugnot",
			Amount: int64(amount),
		},
	}

	// println("[DEBUG__STAKER] wrap_unwrap.gno__unWrap() || UNWRAP AMOUNT:", amount)
	wugnot.Unwrap(a2u(caller), amount)

	banker := std.GetBanker(std.BankerTypeRealmSend)
	banker.SendCoins(std.GetOrigPkgAddr(), caller, refund)
}
