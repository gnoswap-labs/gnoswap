package pool

import (
	"std"
	"strconv"

	pusers "gno.land/p/demo/users"

	u256 "gno.land/p/gnoswap/uint256"
)

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func u256Min(num1, num2 *u256.Uint) *u256.Uint {
	if num1.Lt(num2) {
		return num1
	}

	return num2
}

func uint8ToStr(i uint8) string {
	return strconv.FormatInt(int64(i), 10)
}

func int32ToStr(i int32) string {
	return strconv.FormatInt(int64(i), 10)
}

func uint64ToStr(i uint64) string {
	return strconv.FormatInt(int64(i), 10)
}

func boolToStr(b bool) string {
	if b {
		return "true"
	}

	return "false"
}

func origCaller() string {
	return std.GetOrigCaller().String()
}

func prevRealm() string {
	return std.PrevRealm().PkgPath()
}

func callType() string {
	if prevRealm() == "" {
		return "DIRECT"
	}

	return "INDIRECT"
}
