package gns

import (
	"std"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

func getPrevAddr() std.Address {
	return std.PrevRealm().Addr()
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func assertShouldNotBeHalted() {
	common.IsHalted()
}

func assertCallerIsEmission() {
	caller := getPrevAddr()
	if err := common.EmissionOnly(caller); err != nil {
		panic(err)
	}
}

func assertCallerIsAdmin() {
	caller := getPrevAddr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}
}

func assertCallerIsGovernance() {
	caller := getPrevAddr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}
}

func assertValidYear(year int64) {
	if year < HALVING_START_YEAR || year > HALVING_END_YEAR {
		panic(addDetailToError(errInvalidYear, ufmt.Sprintf("year: %d", year)))
	}
}

func i64Min(x, y int64) int64 {
	if x < y {
		return x
	}
	return y
}

func secToMs(sec int64) int64 {
	return sec * consts.SECOND_IN_MILLISECOND
}
