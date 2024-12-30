package emission

import (
	"std"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v1/common"
)

const MAX_BPS_PCT uint64 = 10000

// a2u converts std.Address to pusers.AddressOrName.
func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

// getPrevRealm returns object of the previous realm.
func getPrevRealm() std.Realm {
	return std.PrevRealm()
}

// getPrevAddr returns the address of the previous realm.
func getPrevAddr() std.Address {
	return std.PrevRealm().Addr()
}

// getPrev returns the address and package path of the previous realm.
func getPrevAsString() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

// assertOnlyAdmin panics if the caller is not the admin.
func assertOnlyAdmin() {
	caller := getPrevAddr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err.Error())
	}
}

// assertStakerOnly panics if the caller is not the staker.
func assertStakerOnly() {
	caller := getPrevAddr()
	if err := common.StakerOnly(caller); err != nil {
		panic(err.Error())
	}
}

// assertOnlyGovernance panics if the caller is not the governance.
func assertOnlyGovernance() {
	caller := getPrevAddr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err.Error())
	}
}

// assertOnlyGovStaker panics if the caller is not the gov staker.
func assertOnlyGovStaker() {
	caller := getPrevAddr()
	if err := common.GovStakerOnly(caller); err != nil {
		panic(err.Error())
	}
}

// assertDistributionTarget panics if the target is invalid.
func assertDistributionTarget(target int) {
	if target != LIQUIDITY_STAKER && target != DEVOPS && target != COMMUNITY_POOL && target != GOV_STAKER {
		panic(addDetailToError(
			errInvalidEmissionTarget,
			ufmt.Sprintf("invalid target(%d)", target),
		))
	}
}

// assertOnlyNotHalted panics if the contract is halted.
func assertOnlyNotHalted() {
	common.IsHalted()
}

// assertSumDistributionPct ensures the sum of all distribution percentages is 100%
func assertSumDistributionPct(pct01, pct02, pct03, pct04 uint64) {
	sum := pct01 + pct02 + pct03 + pct04

	if sum != MAX_BPS_PCT {
		panic(addDetailToError(
			errInvalidEmissionPct,
			ufmt.Sprintf("sum of all pct should be 100%% (10000 bps), got %d", sum),
		))
	}
}
