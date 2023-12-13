package pool

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/wugnot"
)

func wrap(tokenPath string) {
	if tokenPath != GNOT {
		return
	}

	prev := std.PrevRealm().PkgPath()
	if tokenPath == GNOT && prev == "gno.land/r/demo/router" {
		return
	}

	caller := std.GetOrigCaller()
	sentCoins := std.GetOrigSend()

	if len(sentCoins) != 1 {
		panic(ufmt.Sprintf("[POOL] wrap_unwrap.gno__wrap() || NEED TO SEND ONLY ONE COIN, BUT %d SENT", len(sentCoins)))
	}
	sentCoin := sentCoins[0]

	if sentCoin.Denom != "ugnot" {
		panic(ufmt.Sprintf("[POOL] wrap_unwrap.gno__wrap() || SEND ONLY UGNOT, BUT %s SENT", sentCoin.Denom))
	}

	// println("[DEBUG__POOL] wrap_unwrap.gno__wrap() || WRAP AMOUNT:", sentCoin.Amount)
	wugnot.Wrap(a2u(caller), uint64(sentCoin.Amount))
}

func unWrap(tokenPath string, recipient std.Address, amount uint64) {
	if tokenPath != GNOT {
		return
	}

	if tokenPath == GNOT && recipient == ADDR_ROUTER {
		return
	}

	// Collect
	caller := std.GetOrigCaller()

	refund := std.Coins{
		std.Coin{
			Denom:  "ugnot",
			Amount: int64(amount),
		},
	}

	// println("[DEBUG__POOL] wrap_unwrap.gno__unWrap() || UNWRAP AMOUNT:", amount)
	wugnot.Unwrap(a2u(caller), amount)

	banker := std.GetBanker(std.BankerTypeRealmSend)
	banker.SendCoins(std.GetOrigPkgAddr(), caller, refund)
}
