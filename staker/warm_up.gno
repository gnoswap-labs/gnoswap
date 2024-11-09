package staker

import (
	"std"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	"gno.land/p/demo/ufmt"
)

var warmUp = make(map[int64]int64) // map[percent]block

func init() {
	// 30d ~
	warmUp[100] = (30 * (consts.TIMESTAMP_DAY / consts.BLOCK_GENERATION_INTERVAL)) + 1

	// 10d ~ 30d
	warmUp[70] = (10 * (consts.TIMESTAMP_DAY / consts.BLOCK_GENERATION_INTERVAL)) + 1

	// 5d ~ 10d
	warmUp[50] = (5 * (consts.TIMESTAMP_DAY / consts.BLOCK_GENERATION_INTERVAL)) + 1

	// ~ 5d
	warmUp[30] = 1
}

func GetWarmUp(percent int64) int64 {
	value, exist := warmUp[percent]
	if !exist {
		panic(addDetailToError(
			errInvalidWarmUpPercent,
			ufmt.Sprintf("warm_up.gno__GetWarmUp() || percent(%d) must be 30, 50, 70, 100", percent),
		))
	}

	return value
}

func SetWarmUp(percent int64, block int64) {
	common.IsHalted()

	if _, exist := warmUp[percent]; !exist {
		panic(addDetailToError(
			errInvalidWarmUpPercent,
			ufmt.Sprintf("warm_up.gno__SetWarmUp() || percent(%d) must be 30, 50, 70, 100", percent),
		))
	}

	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN && caller != consts.GOV_GOVERNANCE_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"warm_up.gno__SetWarmUp() || only admin(%s) or governance(%s) can set warm up period, called from %s",
				consts.ADMIN,
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		),
		)
	}

	warmUp[percent] = block
}
