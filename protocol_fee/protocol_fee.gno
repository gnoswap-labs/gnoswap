package protocol_fee

import (
	"std"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	"gno.land/p/demo/ufmt"
)

var (
	devOpsPct      uint64 = 3000 // 30%
	gnsToDevOps    uint64
	gnsToGovStaker uint64

	accuToGovStaker = make(map[string]uint64) // tokenPath -> amount
)

func DistributeProtocolFee() {
	common.IsHalted()

	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_GOVERNANCE_ADDR {
		panic(
			ufmt.Sprintf(
				"only admin(%s) or governance(%s) can distribute protocol fee, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		)
	}

	tokens := GetRegisteredTokens()
	for _, token := range tokens {
		// default distribute protocol fee percent
		// devOps 30%
		// govStaker 70%
		// ...

		balance := balanceOfByRegisterCall(token, consts.PROTOCOL_FEE_ADDR)
		if balance > 0 {
			toDevOps := balance * devOpsPct / 10000 // default 30%
			toGovStaker := balance - toDevOps       // default 70%

			if token == consts.GNS_PATH {
				gnsToDevOps = toDevOps
				gnsToGovStaker = toGovStaker
			}

			accuToGovStaker[token] += toGovStaker

			transferByRegisterCall(token, consts.DEV_OPS, toDevOps)
			transferByRegisterCall(token, consts.GOV_STAKER_ADDR, toGovStaker)
		}
	}
}

func GetDevOpsPct() uint64 {
	return devOpsPct
}

func SetDevOpsPct(pct uint64) {
	common.IsHalted()

	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_GOVERNANCE_ADDR {
		panic(
			ufmt.Sprintf(
				"only admin(%s) or governance(%s) can change protocol fee distribution percent for dev ops, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		)
	}

	if pct > 10000 {
		panic("pct should not be bigger than 10000")
	}

	devOpsPct = pct
}

func GetLastTransferToDevOps() uint64 {
	return gnsToDevOps
}

func GetAccuTransferToGovStaker() map[string]uint64 {
	return accuToGovStaker
}

func ClearAccuTransferToGovStaker() {
	common.IsHalted()

	if std.PrevRealm().PkgPath() != consts.GOV_STAKER_PATH {
		panic("only gov staker can clear accu transfer to gov staker")
	}
	accuToGovStaker = make(map[string]uint64)
}
