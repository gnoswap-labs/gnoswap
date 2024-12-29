package gns

import (
	"strconv"
	"strings"
	"std"

	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v1/common"
)

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

func EncodeUint(num uint64) string {
	// Convert the value to a decimal string.
	s := strconv.FormatUint(num, 10)

	// Zero-pad to a total length of 20 characters.
	zerosNeeded := 20 - len(s)
	return strings.Repeat("0", zerosNeeded) + s
}

func DecodeUint(s string) uint64 {
	num, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		panic(err)
	}
	return num
}
func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func assertShouldNotBeHalted() {
	common.IsHalted()
}

func assertCallerIsEmission() {
	caller := std.PrevRealm().Addr()
	if err := common.EmissionOnly(caller); err != nil {
		panic(err)
	}
}

func i64Min(x, y int64) int64 {
	if x < y {
		return x
	}
	return y
}
