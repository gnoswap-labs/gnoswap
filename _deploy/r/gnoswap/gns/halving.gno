package gns

import (
	"std"

	"gno.land/r/gnoswap/consts"

	"gno.land/p/demo/ufmt"
)

/*
	NOTE: assume block will be created every 2 second
	2 second = 1 block
	1 minute = 30 block
	1 hour = 1800 block
	1 day = 43200 block
	(365 days) 1 year = 15768000 block

	2 year = +31536000 block
	4 year = +63072000 block
	6 year = +94608000 block
	8 year = +126144000 block
	12 year = +189216000 block
*/

type halvingTierAmountType map[int64]int64     // map[tier]mintAmount
var halvingTierAmount = halvingTierAmountType{ // u amount per year
	1:  18_750_000_000_000 * 12, // 225_000_000_000_000
	2:  18_750_000_000_000 * 12, // 225_000_000_000_000
	3:  9_375_000_000_000 * 12,  // 112_500_000_000_000
	4:  9_375_000_000_000 * 12,  // 112_500_000_000_000
	5:  4_687_500_000_000 * 12,  // 56_250_000_000_000
	6:  4_687_500_000_000 * 12,  // 56_250_000_000_000
	7:  2_343_750_000_000 * 12,  // 28_125_000_000_000
	8:  2_343_750_000_000 * 12,  // 28_125_000_000_000
	9:  1_171_875_000_000 * 12,  // 14_062_500_000_000
	10: 1_171_875_000_000 * 12,  // 14_062_500_000_000
	11: 1_171_875_000_000 * 12,  // 14_062_500_000_000
	12: 1_171_875_000_000 * 12,  // 14_062_500_000_000
}

type halvingTierBlockType map[int64]int64 // map[block[tier]mintAmount
var halvingTierBlock = make(halvingTierBlockType, 5)

func init() {
	// init 12 years halving tier block
	height := std.GetHeight()
	for i := int64(1); i < 13; i++ {
		halvingTierBlock[i] = height + 15768000*i
	}
}

func SetHalvingTierBlock(tier int64, block int64) {
	// admin or governance only
	caller := std.PrevRealm().Addr()

	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(
			ufmt.Sprintf(
				"only admin(%s) or governance(%s) can set halving tier block, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_ADDR,
				caller,
			),
		)
	}

	// cannot set non exist tier
	if tier < 1 || tier > 12 {
		panic(ufmt.Sprintf("invalid tier %d", tier))
	}

	// cannot set block less than current block
	if block < std.GetHeight() {
		panic(ufmt.Sprintf("cannot set block less than current block %d", std.GetHeight()))
	}

	halvingTierBlock[tier] = block
}

func getAmountByHeight(height int64) uint64 {
	halvingTier := getHalvingTierByBlock(height)
	halvingAmountYear := halvingTierAmount[halvingTier] // amount per year
	halvingAmountDay := halvingAmountYear / 365
	halvingAmountBlock := halvingAmountDay / 43200 // 1 day = 43200 block

	return uint64(halvingAmountBlock)
}

func getHalvingTierByBlock(height int64) int64 {
	// determine which halving tier block is in
	for tier, block := range halvingTierBlock {
		if height <= block {
			return tier
		}
	}

	return 0
}
