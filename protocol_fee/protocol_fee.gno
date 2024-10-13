package protocol_fee

import (
	"std"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"
)

var (
	devOpsPct      uint64 = 0 // 0%
	gnsToDevOps    uint64
	gnsToGovStaker uint64

	accuToGovStaker = make(map[string]uint64) // tokenPath -> amount
)

func DistributeProtocolFee() {
	common.IsHalted()

	tokens := GetRegisteredTokens()
	println("PF_REGISTERED_TOKENS", tokens)
	for _, token := range tokens {
		println(" > token", token)
		// default distribute protocol fee percent
		// govStaker 100%
		// ...

		balance := balanceOfByRegisterCall(token, consts.PROTOCOL_FEE_ADDR)
		println(" > balance", balance)
		if balance > 0 {
			toDevOps := balance * devOpsPct / 10000 // default 0%
			toGovStaker := balance - toDevOps       // default 100%
			println(" > toDevOps", toDevOps)
			println(" > toGovStaker", toGovStaker)

			if token == consts.GNS_PATH {
				gnsToDevOps = toDevOps
				gnsToGovStaker = toGovStaker
			}

			accuToGovStaker[token] += toGovStaker
			println("TO_GOV_STAKER", token, toGovStaker)

			if toDevOps > 0 {
				transferByRegisterCall(token, consts.DEV_OPS, toDevOps)
			}

			if toGovStaker > 0 {
				transferByRegisterCall(token, consts.GOV_STAKER_ADDR, toGovStaker)
			}
		}
	}
}

func GetDevOpsPct() uint64 {
	return devOpsPct
}

// SetDevOpsPctByAdmin sets the devOpsPct.
// Panics if the caller is not the admin.
func SetDevOpsPctByAdmin(pct uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN {
		panic("must be called by admin")
	}

	setDevOpsPct(pct)
	std.Emit(
		"SetDevOpsPctByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"pct", pct,
	)
}

// SetDevOpsPct sets the devOpsPct.
// Panics if the caller is not the governance contract.
func SetDevOpsPct(pct uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic("must be called by governance")
	}

	setDevOpsPct(pct)
	std.Emit(
		"SetDevOpsPct",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"pct", pct,
	)
}

func setDevOpsPct(pct uint64) {
	common.IsHalted()

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
