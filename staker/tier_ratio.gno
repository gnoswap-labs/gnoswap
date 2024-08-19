package staker

import (
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// getPoolTierAndRatio returns current pool's tier and ratio
//
// Parameters:
//   - poolPath (string): pool path
//
// Returns:
//   - tier       (uint64): tier of the pool
//   - ratio  (*u256.Uint): ratio of the pool in Q96 notation
func getPoolTierAndRatio(poolPath string) (uint64, *u256.Uint) {
	internal, exist := poolTiers[poolPath]
	if !exist {
		return 0, u256.Zero()
	}
	tier := internal.tier

	// that tier's ratio
	ratio := getTierRatio(tier)
	ratioX96 := new(u256.Uint).Mul(u256.NewUint(ratio), _q96)

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
		panic(ufmt.Sprintf("[STAKER] tier_ratio.gno__getPoolTierAndRatio() || invalid tier(%d)", tier))
	}

	return tier, weight
}

// getTierRatio returns ratio for given tier
//
// Parameters:
//   - tier (uint64): tier
//
// Returns:
//   - ratio (uint64): ratio
//
// Panics:
//   - tier must be 1 ~ 3
func getTierRatio(tier uint64) uint64 {
	ratio1, ratio2, ratio3 := listTierRatio()

	switch tier {
	case 1:
		return ratio1
	case 2:
		return ratio2
	case 3:
		return ratio3
	default:
		panic(ufmt.Sprintf("[STAKER] tier_ratio.gno__getTierRatio() || invalid tier(%d), must be 1 ~ 3", tier))
	}
}

// listTierRatio returns each tier's ratio
//
// Returns:
//   - tier1Ratio (uint64): tier1 ratio
//   - tier2Ratio (uint64): tier2 ratio
//   - tier3Ratio (uint64): tier3 ratio
//
// Panics:
//   - tier1 pool does not exist
func listTierRatio() (uint64, uint64, uint64) {
	// basic
	// tier1 50%
	// tier2 30%
	// tier3 20%

	// since `float` type has determinisim issue, we use `int` instead
	// so instead of return 50%(=0.5), we return 50
	// we'll divide by 100 later

	numTier1, numTier2, numTier3 := getNumPoolTiers()
	if numTier1 <= 0 {
		panic(ufmt.Sprintf("[STAKER] tier_ratio.gno__listTierRatio() || at least 1 of numTier1 need(%d), [numTier2:(%d), numTier3:(%d)]", numTier1, numTier2, numTier3))
	}
	
	hasTier2 := numTier2 > 0
	hasTier3 := numTier3 > 0

	switch {
	case !hasTier2 && !hasTier3:
		return 100, 0, 0
	case !hasTier2 && hasTier3:
		return 80, 0, 20
	case hasTier2 && !hasTier3:
		return 70, 30, 0
	case hasTier2 && hasTier3:
		return 50, 30, 20
	}

	panic(ufmt.Sprintf("[STAKER] tier_ratio.gno__listTierRatio() || should not happen, [numTier1:(%d), numTier2:(%d), numTier3:(%d)]", numTier1, numTier2, numTier3))
}

// getNumPoolTiers returns number of pools for each tier
//
// Returns:
//   - numTier1 (uint64): number of tier1 pools
//   - numTier2 (uint64): number of tier2 pools
//   - numTier3 (uint64): number of tier3 pools
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
			panic(ufmt.Sprintf("[STAKER] tier_ratio.gno__getNumPoolTiers() || invalid tier(%d)", v))
		}
	}

	return tier1, tier2, tier3
}

// getRewardRatio returns reward ratio for given height based on warm-up period
//
// Parameters:
//   - height (int64): height
//
// Returns:
//   - ratio (uint64): ratio
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

// getTiersAmount returns amount for each tier's ratio
//
// Parameters:
//   - amount (uint64): total amount
//
// Returns:
//   - tier1Amount (uint64): tier1 amount
//   - tier2Amount (uint64): tier2 amount
//   - tier3Amount (uint64): tier3 amount
func getTiersAmount(amount uint64) (uint64, uint64, uint64) {
	tier1Ratio, tier2Ratio, tier3Ratio := listTierRatio()

	tier1Amount := (amount * tier1Ratio) / 100
	tier2Amount := (amount * tier2Ratio) / 100
	tier3Amount := (amount * tier3Ratio) / 100

	return tier1Amount, tier2Amount, tier3Amount
}

// calcAmount calculates full amount and duration amount
//
// Parameters:
//   - avgBlockAmountX96 (u256.Uint): average block amount in Q96 notation
//   - dur (uint64): duration in block
//   - pct (uint64): percentage
//
// Returns:
//   - fullAmount (uint64): full amount
//   - durAmount  (uint64): duration amount based on warm-up percentage
func calcAmount(avgBlockAmountX96 *u256.Uint, dur, pct uint64) (uint64, uint64) {
	durAmountX96 := new(u256.Uint).Mul(avgBlockAmountX96, u256.NewUint(dur))
	fullAmount := new(u256.Uint).Div(durAmountX96, _q96).Uint64()

	durAmountX96 = durAmountX96.Mul(durAmountX96, u256.NewUint(pct))
	durAmountX96 = durAmountX96.Div(durAmountX96, u256.NewUint(100))

	durAmount := new(u256.Uint).Div(durAmountX96, _q96).Uint64()
	return fullAmount, durAmount
}
