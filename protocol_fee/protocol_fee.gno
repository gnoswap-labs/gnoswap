package protocol_fee

import (
	"std"

	"gno.land/r/gnoswap/consts"

	"gno.land/p/demo/ufmt"
)

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
		// distribute protocol fee
		// xGNS 50%
		// devOps 50%
		// ...

		balance := balanceOfByRegisterCall(token, consts.PROTOCOL_FEE_ADDR)
		if balance > 0 {
			toDevOps := balance / 2
			toXGns := balance - toDevOps

			transferByRegisterCall(token, consts.DEV_OPS, toDevOps)
			transferByRegisterCall(token, consts.X_GNS_ADDR, toXGns)
		}
	}
}
