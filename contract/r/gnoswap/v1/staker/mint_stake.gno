package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/halt"

	pn "gno.land/r/gnoswap/v1/position"
)

// MintAndStake mints LP tokens and stakes them in a single transaction.
//
// Parameters:
//   - cur: Current realm
//   - token0: Address of the first token
//   - token1: Address of the second token
//   - fee: Fee tier of the pool
//   - tickLower: Lower tick boundary of the position
//   - tickUpper: Upper tick boundary of the position
//   - amount0Desired: Desired amount of token0 to provide
//   - amount1Desired: Desired amount of token1 to provide
//   - amount0Min: Minimum acceptable amount of token0
//   - amount1Min: Minimum acceptable amount of token1
//   - deadline: Unix timestamp after which the transaction reverts
//   - referrer: Address of the referrer (if any)
//
// Returns:
//   - uint64: Position ID of the minted and staked position
//   - string: Amount of liquidity provided
//   - string: Actual amount of token0 used
//   - string: Actual amount of token1 used
//   - string: Pool path where the position was staked
//
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
