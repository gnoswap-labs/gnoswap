package protocol_fee

import (
	"std"

	"gno.land/p/demo/ufmt"

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
	for _, token := range tokens {
		// default distribute protocol fee percent
		// govStaker 100%
		// ...

		balance := balanceOfByRegisterCall(token, consts.PROTOCOL_FEE_ADDR)
		if balance > 0 {
			toDevOps := balance * devOpsPct / 10000 // default 0%
			toGovStaker := balance - toDevOps       // default 100%

			if token == consts.GNS_PATH {
				gnsToDevOps = toDevOps
				gnsToGovStaker = toGovStaker
			}

			accuToGovStaker[token] += toGovStaker

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
	if caller != consts.ADMIN {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("protocol_fee.gno__SetDevOpsPctByAdmin() || must be called by admin, called from %s", caller.String()),
		))
	}

	setDevOpsPct(pct)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetDevOpsPctByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"pct", ufmt.Sprintf("%d", pct),
	)
}

// SetDevOpsPct sets the devOpsPct.
// Panics if the caller is not the governance contract.
func SetDevOpsPct(pct uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("protocol_fee.gno__SetDevOpsPct() || must be called by governance, called from %s", caller.String()),
		))
	}

	setDevOpsPct(pct)

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SetDevOpsPct",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"pct", ufmt.Sprintf("%d", pct),
	)
}

func setDevOpsPct(pct uint64) {
	common.IsHalted()

	if pct > 10000 {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("protocol_fee.gno__setDevOpsPct() || pct should not be bigger than 10000, pct(%d)", pct),
		))
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

	prev := std.PrevRealm().PkgPath()
	if prev != consts.GOV_STAKER_PATH {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("protocol_fee.gno__ClearAccuTransferToGovStaker() || only gov/staker can clear accu transfer to gov staker, called from %s", prev),
		))
	}

	accuToGovStaker = make(map[string]uint64)
}
