package launchpad

import (
	b64 "encoding/base64"
	"std"
	"strconv"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

func strToInt(str string) int {
	res, err := strconv.Atoi(str)
	if err != nil {
		panic(err.Error())
	}

	return res
}

func strToU256U64(str string) uint64 {
	strValue := u256.MustFromDecimal(str)
	return strValue.Uint64()
}

func contains(slice []string, str string) bool {
	for _, v := range slice {
		if v == str {
			return true
		}
	}
	return false
}

func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

func b64Encode(data string) string {
	return string(b64.StdEncoding.EncodeToString([]byte(data)))
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func minU64(x, y uint64) uint64 {
	if x < y {
		return x
	}
	return y
}

// GetOrigPkgAddr returns the original package address.
// In position contract, original package address is the position address.
func GetOrigPkgAddr() std.Address {
	return consts.LAUNCHPAD_ADDR
}

// isUserCall returns true if the caller is a user.
func isUserCall() bool {
	return std.PrevRealm().IsUser()
}

// getPrev returns the address and package path of the previous realm.
func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

// getPrevRealm returns object of the previous realm.
func getPrevRealm() std.Realm {
	return std.PrevRealm()
}

// getPrevAddr returns the address of the previous realm.
func getPrevAddr() std.Address {
	return std.PrevRealm().Addr()
}

// getPrevPkgPath returns the package path of the previous realm.
func getPrevPkgPath() string {
	return std.PrevRealm().PkgPath()
}

// formatUint returns the string representation of the uint64 value.
func formatUint(value uint64) string {
	return strconv.FormatUint(value, 10)
}

// formatInt returns the string representation of the int64 value.
func formatInt(value int64) string {
	return strconv.FormatInt(value, 10)
}

// assertOnlyNotHalted panics if the contract is halted.
func assertOnlyNotHalted() {
	common.IsHalted()
}

// assertOnlyAdmin panics if the caller is not an admin.
func assertOnlyAdmin() {
	caller := getPrevAddr()
	if err := common.AdminOnly(caller); err != nil {
		panic(addDetailToError(errInvalidAddress, err.Error()))
	}
}

// assertOnlyValidAddress panics if the address is invalid.
func assertOnlyValidAddress(addr std.Address) {
	if !addr.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("(%s)", addr),
		))
	}
}
