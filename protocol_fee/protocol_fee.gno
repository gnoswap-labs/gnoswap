package protocol_fee

import (
	"std"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/p/demo/ufmt"
)

var xGnsPctBps uint64 = 5000 // 50%

func DistributeProtocolFee() {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(
			ufmt.Sprintf(
				"only admin(%s) or governance(%s) can distribute protocol fee, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_ADDR,
				caller,
			),
		)
	}

	tokens := GetRegisteredTokens()
	for _, token := range tokens {
		// default distribute protocol fee percent
		// xGNS 50%
		// devOps 50%
		// ...

		balance := balanceOfByRegisterCall(token, consts.PROTOCOL_FEE_ADDR)
		if balance > 0 {
			toDevOps := balance * 5000 / 10000
			toXGns := balance - toDevOps

			transferByRegisterCall(token, consts.DEV_OPS, toDevOps)
			transferByRegisterCall(token, consts.X_GNS_ADDR, toXGns)
		}
	}
}

func ChagneXGnsDistributePercent(fee uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(
			ufmt.Sprintf(
				"only admin(%s) or governance(%s) can change protocol fee distribution percent, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_ADDR,
				caller,
			),
		)
	}

	if fee > 10000 {
		panic("fee should be less than 10000")
	}

	xGnsPctBps = fee
}

func GetXGnsDistributePercent() uint64 {
	return xGnsPctBps
}
