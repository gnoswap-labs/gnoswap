package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/consts"

	en "gno.land/r/gnoswap/v2/emission"

	"gno.land/r/gnoswap/v2/gns"
)

func GnsSetAvgBlockTimeInMs(ms int64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(
			ufmt.Sprintf(
				"[STAKER] wrap_gns_block_time_change.gno__GnsSetAvgBlockTimeInMs() || only admin(%s) or governance(%s) can set avg block time, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_ADDR,
				caller,
			),
		)
	}

	en.MintAndDistributeGns()
	CalcPoolPosition()

	gns.SetAvgBlockTimeInMs(ms)
}
