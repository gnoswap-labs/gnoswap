package staker

import (
	"std"

	"gno.land/r/gnoswap/consts"

	"gno.land/p/demo/ufmt"
)

var warmUp = make(map[int64]int64) // map[percent]block

func init() {
	// warmUp[100] = 1296001 // 30d ~
	// warmUp[70] = 432001   // 10d ~ 30d
	// warmUp[50] = 216001   // 5d ~ 10d
	// warmUp[30] = 1        // ~ 5d

	warmUp[100] = 901 // 30m ~
	warmUp[70] = 301  // 10m ~ 30m
	warmUp[50] = 151  // 5m ~ 10m
	warmUp[30] = 1    // ~ 5m
}

func GetWarmUp(percent int64) int64 {
	value, exist := warmUp[percent]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] reward_math_warm_up.gno__GetWarmUp() || percent(%d) must be 30, 50, 70, 100", percent))
	}

	return value
}

func SetWarmUp(percent int64, block int64) {
	if _, exist := warmUp[percent]; !exist {
		panic(ufmt.Sprintf("[STAKER] reward_math_warm_up.gno__SetWarmUp() || percent(%d) must be 30, 50, 70, 100", percent))
	}

	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(
			ufmt.Sprintf(
				"[STAKER] reward_math_warm_up.gno__SetWarmUp() || only admin(%s) or governance(%s) can set warm up period, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_ADDR,
				caller,
			),
		)
	}

	warmUp[percent] = block
}
