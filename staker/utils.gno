package staker

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/users"
)

// get current pool tier and reward ratio
func getPoolTierAndRatio(poolPath string) (bigint, float64) {
	poolPath = poolKeyDivide(poolPath)

	// current pool's tier
	tier, ok := poolTiers[poolPath]
	if !ok {
		return 0, 0
	}

	// that tiers ratio
	ratio := getTierRatio(tier)

	// finally current pools ratio
	numTier1, numTier2, numTier3 := getNumPoolTiers()

	// 소수점 자리수 끊어야 함
	switch tier {
	case 1:
		return tier, ratio / float64(numTier1)
	case 2:
		return tier, ratio / float64(numTier2)
	case 3:
		return tier, ratio / float64(numTier3)
	}
}

// get number of pools for each tier
func getNumPoolTiers() (uint64, uint64, uint64) {
	var tier1, tier2, tier3 uint64

	for _, v := range poolTiers {
		switch v {
		case 1:
			tier1++
		case 2:
			tier2++
		case 3:
			tier3++
		default:
			continue
		}
	}

	return tier1, tier2, tier3
}

// get staking tier
func getStakingTier(timestamp bigint) float64 {
	switch {
	case timestamp >= 2592001: // 30d 1s ~
		return 1.0
	case timestamp >= 864001: // 10d 1s ~ 30d
		return 0.7
	case timestamp >= 432001: // 5d 1s ~ 10d
		return 0.5
	case timestamp >= 1: // 1s ~ 5d
		return 0.3
	default: // 0s
		return 0.0
	}
}

// return all ratio for each tier
func listTierRatio() (float64, float64, float64) {
	// basic
	// tier1 50%
	// tier2 30%
	// tier3 20%

	numTier1, numTier2, numTier3 := getNumPoolTiers()
	require(numTier1 > 0, ufmt.Sprintf("[STAKER] staker.gno__getTierRatio() || numTier1(%s) > 0 (numTier2:(%s), numTier3:(%s))", numTier1, numTier2, numTier3))

	if numTier2 == 0 && numTier3 == 0 { // only tier 1 exists
		return 1.0, 0.0, 0.0
	} else if numTier2 == 0 && numTier3 >= 1 { // tier 1 and 3 exists ( tier2 ratio goes to tier1 )
		return 0.8, 0.0, 0.2
	} else if numTier2 >= 1 && numTier3 == 0 { // tier 1 and 2 exists ( tier3 ratio goes to tier1 )
		return 0.7, 0.3, 0.0
	} else if numTier2 >= 1 && numTier3 >= 1 { // all tiers exists
		return 0.5, 0.3, 0.2
	} else {
		panic("[STAKER] staker.gno__getTierRatio() || invalid tier ratio")
	}
}

func getTierRatio(tier bigint) float64 {
	require(tier >= 1 && tier <= 3, ufmt.Sprintf("[STAKER] staker.gno__getTierRatio() || tier(%s) >= 1 && tier(%s) <= 3", tier, tier))

	ratio1, ratio2, ratio3 := listTierRatio()
	switch tier {
	case 1:
		return ratio1
	case 2:
		return ratio2
	case 3:
		return ratio3
	default:
		panic("[STAKER] staker.gno__getTierRatio() || invalid ratio")
	}
}

func poolKeyDivide(poolKey string) string {
	res := strings.Split(poolKey, "_")
	if len(res) != 3 {
		panic(ufmt.Sprintf("[STAKER] staker.gno__poolKeyDivide() || invalid poolKey(%s)", poolKey))
	}

	pToken0, pToken1, fee := res[0], res[1], res[2]

	if pToken0 < pToken1 {
		return ufmt.Sprintf("%s/%s_%s", strings.ToUpper(pToken0), strings.ToUpper(pToken1), fee)
	}

	return ufmt.Sprintf("%s/%s_%s", strings.ToUpper(pToken1), strings.ToUpper(pToken0), fee)
}

func require(condition bool, message string) {
	if !condition {
		panic(message)
	}
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func tid(tokenId interface{}) grc721.TokenID {
	if tokenId == nil {
		panic("[STAKER] utils.gno__tid() || tokenId is nil")
	}

	switch tokenId.(type) {
	case bigint:
		return grc721.TokenID(string(tokenId.(bigint)))
	case string:
		return grc721.TokenID(tokenId.(string))
	case grc721.TokenID:
		return tokenId.(grc721.TokenID)
	default:
		panic("[STAKER] utils.gno__tid() || tokenId is not a type of string or grc721.TokenID")
	}
}

func max(x, y bigint) bigint {
	if x > y {
		return x
	}
	return y
}

func min(x, y bigint) bigint {
	if x < y {
		return x
	}
	return y
}

func requireUnsigned(x bigint, msg string) {
	if x < 0 {
		panic(msg)
	}
}
