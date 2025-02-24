package protocol_fee

import (
	"std"

	"gno.land/r/gnoswap/v1/halt"
)

func getPrev() (string, string) {
	prev := std.PreviousRealm()
	return prev.Address().String(), prev.PkgPath()
}

// assertOnlyNotHalted panics if the contract is halted.
func assertOnlyNotHalted() {
	if err := halt.IsHalted(); err != nil {
		panic(err)
	}
}
