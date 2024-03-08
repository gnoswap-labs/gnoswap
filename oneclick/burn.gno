package oneclick

import (
	"std"

	pn "gno.land/r/demo/position"

	"gno.land/r/demo/wugnot"
)

func OneClickDecreaseLiquidity(
	tokenId uint64,
	liquidity string,
	amount0Min string, // *u256.Uint
	amount1Min string, // *u256.Uint
	deadline int64,
) (uint64, string, string, string, string) { // tokenId, liquidity, amount0, amount1, poolPath
	std.AssertOriginCall() // can not call by other contract

	// before decrease, save user's current wugnot balance
	userOldWgnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller()))

	tokenId, liquidity, amount0, amount1, poolPath := pn.DecreaseLiquidity(
		tokenId,
		liquidity,
		amount0Min,
		amount1Min,
		deadline,
	)
	userNewWgnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller()))

	// use collectd wugnot from liquidity and fee
	userGotWugnot := userNewWgnotBalance - userOldWgnotBalance

	if userGotWugnot > 0 {
		// SEND WUGNOT: USER > ONE CLICK
		wugnot.TransferFrom(a2u(std.GetOrigCaller()), a2u(std.GetOrigPkgAddr()), uint64(userGotWugnot))

		// SEND WUGNOT: ONE CLICK > WUGNOT
		// SEND GNOT: WUGNOT > ONE CLICK
		wugnot.Withdraw(userGotWugnot)

		// SEND GNOT: ONE CLICK > USER
		banker := std.GetBanker(std.BankerTypeRealmSend)
		banker.SendCoins(std.GetOrigPkgAddr(), std.GetOrigCaller(), std.Coins{{"gnot", int64(userGotWugnot)}})
	}

	return tokenId, liquidity, amount0, amount1, poolPath
}
