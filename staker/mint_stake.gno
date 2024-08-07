package staker

import (
	"std"

	pn "gno.land/r/gnoswap/v2/position"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gnft"

	"gno.land/p/demo/grc/grc721"
)

// MintAndStake mints LP tokens and stakes them in a single transaction.
//
// Parameters:
//   - token0, token1 (string): Addresses of the two tokens in the liquidity pool.
//   - fee (string): The fee tier of the pool.
//   - tickLower, tickUpper (string): The lower and upper tick boundaries for the position.
//   - amount0Desired, amount1Desired (string): Desired amounts of token0 and token1 to add as liquidity.
//   - amount0Min, amount1Min (string): Minimum amounts of token0 and token1 to add as liquidity.
//   - deadline (int64): The timestamp by which the transaction must be executed.
//
// Returns:
//   - tokenId          (uint64): The ID of the minted NFT representing the liquidity position.
//   - liquidity        (string): The amount of liquidity added to the pool.
//   - amount0, amount1 (string): The actual amounts of token0 and token1 used to provide liquidity.
//   - poolPath         (string): The path identifier for the liquidity pool.
//
// Note: All amount parameters are strings representing *u256.Uint values.
func MintAndStake(
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	amount0Desired string, // *u256.Uint
	amount1Desired string, // *u256.Uint
	amount0Min string, // *u256.Uint
	amount1Min string, // *u256.Uint
	deadline int64,
) (uint64, string, string, string, string) { // tokenId, liquidity, amount0, amount1, poolPath ( *u256.Uint x3)

	// if one click native
	if token0 == consts.GNOT || token1 == consts.GNOT {
		// check sent ugnot
		sent := std.GetOrigSend()
		ugnotSent := uint64(sent.AmountOf("ugnot"))

		// not enough ugnot sent
		if ugnotSent < consts.UGNOT_MIN_DEPOSIT_TO_WRAP {
			panic(ufmt.Sprintf("[STAKER] mint_stake.gno__MintAndStake() || too less(%d) ugnot sent (minimum:%d)", ugnotSent, consts.UGNOT_MIN_DEPOSIT_TO_WRAP))
		}

		// send it over to position to wrap
		banker := std.GetBanker(std.BankerTypeRealmSend)
		banker.SendCoins(consts.STAKER_ADDR, consts.POSITION_ADDR, std.Coins{{Denom: "ugnot", Amount: int64(ugnotSent)}})
	}

	tokenId, liquidity, amount0, amount1 := pn.Mint(
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
		consts.STAKER_ADDR.String(),
	)

	// at this point staker has minted token
	toTid := grc721.TokenID(ufmt.Sprintf("%d", tokenId))
	gnft.SetTokenURI(toTid)

	poolPath, _, _ := StakeToken(tokenId) // poolPath, stakedAmount0, stakedAmount1

	/*
		std.Emit(
			"GNOSWAP",
			"m_callType", callType(),
			"m_origCaller", origCaller(),
			"m_prevRealm", prevRealm(),
			"p_tickLower", int32ToStr(tickLower),
			"p_tickUpper", int32ToStr(tickUpper),
			"poolPath", poolPath,
			"tokenId", uint64ToStr(tokenId),
			"liquidity", liquidity,
			"amount0", amount0,
			"amount1", amount1,
		)
	*/

	return tokenId, liquidity, amount0, amount1, poolPath
}
