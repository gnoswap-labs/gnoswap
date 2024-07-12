package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/consts"

	pos "gno.land/r/gnoswap/position"

	"gno.land/r/gnoswap/gns"
)

func rewardMathComputeInternalRewardAmount(tokenId uint64) uint64 {
	deposit := deposits[tokenId]

	// using block
	stakeHeight := deposit.stakeHeight
	currentHeight := std.GetHeight()
	stakedDuration := currentHeight - stakeHeight
	durationRatio := getRewardRatio(stakedDuration)

	// 100% amount
	gnsFullAmount := positionGns[tokenId]
	if gnsFullAmount == 0 {
		return 0
	}

	gnsAmountToGive := (gnsFullAmount * durationRatio) / 100

	//  transfer to protocol_fee contract
	_gnsAmountLeft := gnsFullAmount - gnsAmountToGive
	_stakerGns := gnsBalance(consts.STAKER_ADDR)
	toFee := min(_gnsAmountLeft, _stakerGns)
	gns.Transfer(a2u(consts.PROTOCOL_FEE_ADDR), toFee)

	poolGns[deposit.targetPoolPath] -= gnsFullAmount
	return gnsAmountToGive
}

func rewardMathComputeExternalRewardAmount(tokenId uint64, incentiveId string, durationRatio uint64) uint64 {
	externals := positionExternal[tokenId]
	for _, external := range externals {
		if external.incentiveId == incentiveId {
			tokenAmount := external.tokenAmount

			if tokenAmount == 0 {
				return 0
			}

			amountToGive := (tokenAmount * durationRatio) / 100
			return amountToGive
		}
	}

	return 0
}

func getPoolTotalStakedLiquidity(poolPath string) *u256.Uint {
	poolStakedLiquidity := u256.Zero()
	// get all staked liquidity
	for tokenId, deposit := range deposits { // key is tokenId // used in this range loop only
		if deposit.targetPoolPath == poolPath {
			isInRange := pos.PositionIsInRange(tokenId)
			if isInRange == false {
				continue
			}

			tokenLiquidity := pos.PositionGetPositionLiquidity(tokenId)
			poolStakedLiquidity = new(u256.Uint).Add(poolStakedLiquidity, tokenLiquidity)
		}
	}

	return poolStakedLiquidity
}

func getMyLiquidityRatio(poolPath string, tokenId uint64) *u256.Uint {
	_q96 := u256.MustFromDecimal(consts.Q96)

	poolStakedLiquidity := getPoolTotalStakedLiquidity(poolPath)

	// my(current tokenId) liquidity
	myLiquidity := pos.PositionGetPositionLiquidity(tokenId)

	isInRange := pos.PositionIsInRange(tokenId)
	if isInRange == false {
		return u256.Zero()
	}

	// my liquidity ratio
	myLiquidityX96 := new(u256.Uint).Mul(myLiquidity, _q96)
	myLiquidityX96X100 := new(u256.Uint).Mul(myLiquidityX96, u256.NewUint(100))

	poolStakedLiquidityX96 := new(u256.Uint).Mul(poolStakedLiquidity, _q96)

	myLiquidityRatio := new(u256.Uint).Div(myLiquidityX96X100, poolStakedLiquidityX96) // this value needs to be divided by 100
	myLiquidityRatio = new(u256.Uint).Mul(myLiquidityRatio, _q96)                      // so first mul consts.Q96
	myLiquidityRatioX96 := new(u256.Uint).Div(myLiquidityRatio, u256.NewUint(100))     // then divided by 100

	return myLiquidityRatioX96
}

// get current pool tier and reward ratio
func getPoolTierAndRatio(poolPath string) (uint64, *u256.Uint) {
	_q96 := u256.MustFromDecimal(consts.Q96)

	// current pool's tier
	internal, ok := poolTiers[poolPath]
	if !ok {
		return 0, u256.Zero()
	}
	tier := internal.tier

	// that tiers ratio
	ratio := getTierRatio(tier)
	ratioX96 := new(u256.Uint).Mul(u256.NewUint(ratio), _q96) // first consts.Q96

	// finally current pools ratio
	numTier1, numTier2, numTier3 := getNumPoolTiers()

	var weight *u256.Uint
	switch tier {
	case 1:
		weight = new(u256.Uint).Div(ratioX96, u256.NewUint(numTier1))
	case 2:
		weight = new(u256.Uint).Div(ratioX96, u256.NewUint(numTier2))
	case 3:
		weight = new(u256.Uint).Div(ratioX96, u256.NewUint(numTier3))
	default:
		panic(ufmt.Sprintf("[STAKER] reward_math.gno__getPoolTierAndRatio() || invalid tier(%d)", tier))
	}

	return tier, weight
}

// get number of pools for each tier
func getNumPoolTiers() (uint64, uint64, uint64) {
	var tier1, tier2, tier3 uint64

	for _, v := range poolTiers {
		switch v.tier {
		case 1:
			tier1++
		case 2:
			tier2++
		case 3:
			tier3++
		default:
			panic(ufmt.Sprintf("[STAKER] reward_math.gno__getNumPoolTiers() || invalid tier(%d)", v))
		}
	}

	return tier1, tier2, tier3
}

// get reward ratio by staking duration height
func getRewardRatio(height int64) uint64 {
	switch {
	case height >= warmUp[100]:
		return 100
	case height >= warmUp[70]:
		return 70
	case height >= warmUp[50]:
		return 50
	case height >= warmUp[30]:
		return 30
	default:
		return 0
	}
}

func getTierRatio(tier uint64) uint64 {
	if tier < 1 || tier > 3 {
		panic(ufmt.Sprintf("[STAKER] reward_math.gno__getTierRatio() || tier(%d) must be 1 ~ 3", tier))
	}

	ratio1, ratio2, ratio3 := listTierRatio()
	switch tier {
	case 1:
		return ratio1 // default 50
	case 2:
		return ratio2 // default 30
	case 3:
		return ratio3 // default 20
	default:
		panic("[STAKER] reward_math.gno__getTierRatio() || invalid ratio")
	}
}

// return all ratio for each tier
func listTierRatio() (uint64, uint64, uint64) {
	// basic
	// tier1 50%
	// tier2 30%
	// tier3 20%

	// since `float` type has determinisim issue, we use `int` instead
	// so instead of return 50%, we return 50
	// we'll divide by 100 later

	numTier1, numTier2, numTier3 := getNumPoolTiers()
	if numTier1 <= 0 {
		panic(ufmt.Sprintf("[STAKER] reward_math.gno__listTierRatio() || at least 1 numTier1 need(%d), [numTier2:(%d), numTier3:(%d)]", numTier1, numTier2, numTier3))
	}

	if numTier2 == 0 && numTier3 == 0 { // only tier 1 exists
		return 100, 0, 0
	} else if numTier2 == 0 && numTier3 >= 1 { // tier 1 and 3 exists ( tier2 ratio goes to tier1 )
		return 80, 0, 20
	} else if numTier2 >= 1 && numTier3 == 0 { // tier 1 and 2 exists ( tier3 ratio goes to tier1 )
		return 70, 30, 0
	} else if numTier2 >= 1 && numTier3 >= 1 { // all tiers exists
		return 50, 30, 20
	} else {
		panic("[STAKER] reward_math.gno__listTierRatio() || invalid tier ratio")
	}
}

func getTiersAmount(amount uint64) (uint64, uint64, uint64) {
	tier1Ratio, tier2Ratio, tier3Ratio := listTierRatio()

	tier1Amount := (amount * tier1Ratio) / 100
	tier2Amount := (amount * tier2Ratio) / 100
	tier3Amount := (amount * tier3Ratio) / 100

	return tier1Amount, tier2Amount, tier3Amount
}
