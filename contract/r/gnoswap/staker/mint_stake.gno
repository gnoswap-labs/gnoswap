package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/halt"

	pn "gno.land/r/gnoswap/v1/position"
)

// MintAndStake mints LP tokens and stakes them in a single transaction.
// Returns positionId, liquidity, amount0, amount1, poolPath
// ref: https://docs.gnoswap.io/contracts/staker/mint_stake.gno#mintandstake
func MintAndStake(
	cur realm,
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	amount0Desired string,
	amount1Desired string,
	amount0Min string,
	amount1Min string,
	deadline int64,
	referrer string,
) (uint64, string, string, string, string) {
	halt.AssertIsNotHaltedStaker()

	// if one click native
	if token0 == GNOT || token1 == GNOT {
		// check sent ugnot
		sent := std.OriginSend()
		ugnotSent := sent.AmountOf("ugnot")

		// not enough ugnot sent
		if ugnotSent < int64(UGNOT_MIN_DEPOSIT_TO_WRAP) {
			panic(ufmt.Errorf(
				"%v: too less ugnot sent(%d), minimum:%d",
				errWugnotMinimum, ugnotSent, UGNOT_MIN_DEPOSIT_TO_WRAP,
			))
		}

		// send it over to position to wrap
		banker := std.NewBanker(std.BankerTypeRealmSend)
		banker.SendCoins(stakerAddr, positionAddr, std.Coins{{Denom: "ugnot", Amount: ugnotSent}})
	}

	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		token0,
		token1,
		fee,
		tickLower,
		tickUpper,
		amount0Desired,
		amount1Desired,
		amount0Min,
		amount1Min,
		deadline,
		stakerAddr,
		std.PreviousRealm().Address(),
		referrer,
	)

	poolPath, _, _ := StakeToken(cur, positionId, "")

	return positionId, liquidity, amount0, amount1, poolPath
}
