package protocol_fee

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

var (
	devOpsPct      uint64 = 0 // 0%
	gnsToDevOps    uint64
	gnsToGovStaker uint64

	accuToGovStaker = avl.NewTree()
)

// DistributeProtocolFee distributes the protocol fee to devOps and gov/staker.
func DistributeProtocolFee() {
	assertOnlyNotHalted()

	tokens := common.ListRegisteredTokens()
	if len(tokens) == 0 {
		return
	}

	for _, token := range tokens {
		// default distribute protocol fee percent
		// govStaker 100%
		// ...

		balance := common.BalanceOf(token, consts.PROTOCOL_FEE_ADDR)
		if balance > 0 {
			toDevOps := balance * devOpsPct / 10000 // default 0%
			toGovStaker := balance - toDevOps       // default 100%

			if token == consts.GNS_PATH {
				gnsToDevOps = toDevOps
				gnsToGovStaker = toGovStaker
			}

			addAccuToGovStaker(token, toGovStaker)

			tokenTeller := common.GetTokenTeller(token)
			if toDevOps > 0 {
				tokenTeller.Transfer(consts.DEV_OPS, toDevOps)
			}

			if toGovStaker > 0 {
				tokenTeller.Transfer(consts.GOV_STAKER_ADDR, toGovStaker)
			}
		}
	}
}

func GetDevOpsPct() uint64 {
	return devOpsPct
}

// SetDevOpsPctByAdmin sets the devOpsPct.
func SetDevOpsPctByAdmin(pct uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	setDevOpsPct(pct)
}

// SetDevOpsPct sets the devOpsPct.
// Only governance contract can execute this function via proposal
func SetDevOpsPct(pct uint64) {
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}

	setDevOpsPct(pct)
}

// setDevOpsPct sets the devOpsPct.
func setDevOpsPct(pct uint64) {
	if pct > 10000 {
		panic(addDetailToError(
			errInvalidPct,
			ufmt.Sprintf("pct(%d) should not be bigger than 10000", pct),
		))
	}

	devOpsPct = pct

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetDevOpsPct",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"pct", ufmt.Sprintf("%d", pct),
	)
}

// GetLastTransferToDevOps returns the last transfer to devOps.
func GetLastTransferToDevOps() uint64 {
	return gnsToDevOps
}

// GetAccuTransferToGovStaker returns the accuToGovStaker.
func GetAccuTransferToGovStaker() *avl.Tree {
	return accuToGovStaker
}

// GetAccuTransferToGovStakerByTokenPath returns the accumulated transfer to gov/staker by token path.
func GetAccuTransferToGovStakerByTokenPath(path string) uint64 {
	amountI, exists := accuToGovStaker.Get(path)
	if !exists {
		return 0
	}

	return amountI.(uint64)
}

// ClearAccuTransferToGovStaker clears the accuToGovStaker.
// Only gov/staker can execute this function.
func ClearAccuTransferToGovStaker() {
	assertOnlyNotHalted()

	caller := std.PrevRealm().Addr()
	if err := common.GovStakerOnly(caller); err != nil {
		panic(err)
	}

	accuToGovStaker = avl.NewTree()
}

// assertOnlyNotHalted panics if the contract is halted.
func assertOnlyNotHalted() {
	common.IsHalted()
}

// addAccuToGovStaker adds the amount to the accuToGovStaker by token path.
func addAccuToGovStaker(path string, amount uint64) {
	before := GetAccuTransferToGovStakerByTokenPath(path)
	after := before + amount
	accuToGovStaker.Set(path, after)
}
