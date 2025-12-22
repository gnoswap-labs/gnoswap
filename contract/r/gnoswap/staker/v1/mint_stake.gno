package v1

import (
	"chain"
	"chain/banker"
	"chain/runtime"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"

	pn "gno.land/r/gnoswap/position"
)

// MintAndStake mints a new liquidity position and immediately stakes it.
//
// Atomic operation combining position creation and staking.
// Saves gas by avoiding separate mint and stake transactions.
// Position NFT transferred directly to staker contract.
//
// Parameters:
//   - token0, token1: Token contract paths
//   - fee: Pool fee tier (500=0.05%, 3000=0.3%, 10000=1%)
//   - tickLower, tickUpper: Price range boundaries
//   - amount0Desired, amount1Desired: Target token amounts
//   - amount0Min, amount1Min: Minimum amounts (slippage protection)
//   - deadline: Transaction expiration timestamp
//   - referrer: Optional referral address
//
// Native token support:
//   - Accepts GNOT via std.OriginSend()
//   - Auto-wraps to WUGNOT for liquidity
//   - Minimum 1 GNOT required
//
// Returns:
//   - positionId: New NFT token ID
//   - liquidity: Amount of liquidity minted
//   - amount0, amount1: Actual tokens deposited
//   - poolPath: Pool identifier
func (s *stakerV1) MintAndStake(
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

	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())

	// if one click native
	if token0 == GNOT_DENOM || token1 == GNOT_DENOM {
		// check sent ugnot
		sent := banker.OriginSend()
		ugnotSent := sent.AmountOf("ugnot")

		// not enough ugnot sent
		if ugnotSent < UGNOT_MIN_DEPOSIT_TO_WRAP {
			panic(ufmt.Errorf(
				"%v: too less ugnot sent(%d), minimum:%d",
				errWugnotMinimum, ugnotSent, UGNOT_MIN_DEPOSIT_TO_WRAP,
			))
		}

		// send it over to position to wrap
		positionAddr := access.MustGetAddress(prbac.ROLE_POSITION.String())
		banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
		banker_.SendCoins(stakerAddr, positionAddr, chain.Coins{{Denom: GNOT_DENOM, Amount: ugnotSent}})
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
		runtime.PreviousRealm().Address(),
		referrer,
	)

	poolPath := s.StakeToken(positionId, referrer)

	return positionId, liquidity, amount0, amount1, poolPath
}
