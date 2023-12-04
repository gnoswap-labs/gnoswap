package position

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/wugnot"
)

const (
	GNOT           = "gnot"
	WRAPPED_WUGNOT = "gno.land/r/wugnot"
)

func wrap(tokenPath string) string {
	if tokenPath != GNOT {
		return tokenPath
	}

	caller := std.GetOrigCaller() // GOTTA BE USER for POSITION.MINT
	sentCoins := std.GetOrigSend()

	if len(sentCoins) != 1 {
		panic(ufmt.Sprintf("[POSITION] wrap_unwrap.gno__wrap() || NEED TO SEND ONLY ONE COIN, BUT %d SENT", len(sentCoins)))
	}
	sentCoin := sentCoins[0]

	if sentCoin.Denom != "ugnot" {
		panic(ufmt.Sprintf("[POSITION] wrap_unwrap.gno__wrap() || SEND ONLY UGNOT, BUT %s SENT", sentCoin.Denom))
	}

	// println("[DEBUG__POSITION] wrap_unwrap.gno__wrap() || WRAP AMOUNT:", sentCoin.Amount)
	wugnot.Wrap(a2u(caller), uint64(sentCoin.Amount))

	// return wrapepd ugnot path
	return WRAPPED_WUGNOT
}

func unWrap(tokenPath string, amount uint64) string {
	if tokenPath != GNOT {
		return tokenPath
	}

	caller := std.GetOrigCaller() // GOTTA BE USER for POSITION.MINT

	refund := std.Coins{
		std.Coin{
			Denom:  "ugnot",
			Amount: int64(amount),
		},
	}

	// println("[DEBUG__POSITION] wrap_unwrap.gno__unWrap() || UNWRAP AMOUNT:", amount)
	wugnot.Unwrap(a2u(caller), amount)

	banker := std.GetBanker(std.BankerTypeRealmSend)
	banker.SendCoins(std.GetOrigPkgAddr(), caller, refund)

	// return wrapepd ugnot path
	return WRAPPED_WUGNOT
}
