package staker

import (
	pn "gno.land/r/demo/position"

	"gno.land/r/gnoswap/consts"
)

// MintAndStake mints and stakes the LP token
// If minting is successful, it mints LP token to staker not user
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

	poolPath, _, _ := StakeToken(tokenId)

	return tokenId, liquidity, amount0, amount1, poolPath
}
