package position

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

// a2u converts std.Address to pusers.AddressOrName.
// pusers is a package that contains the user-related functions.
//
// Input:
//   - addr: the address to convert
//
// Output:
//   - pusers.AddressOrName: the converted address
func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

// derivePkgAddr derives the Realm address from it's pkgpath parameter
func derivePkgAddr(pkgPath string) std.Address {
	return std.DerivePkgAddr(pkgPath)
}

// getOrigPkgAddr returns the original package address.
// In position contract, original package address is the position address.
func getOrigPkgAddr() std.Address {
	return consts.POSITION_ADDR
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

// isUserCall returns true if the caller is a user.
func isUserCall() bool {
	return std.PrevRealm().IsUser()
}

// checkDeadline checks if the deadline is expired.
// If the deadline is expired, it panics.
// The deadline is expired if the current time is greater than the deadline.
// Input:
//   - deadline: the deadline to check
func checkDeadline(deadline int64) {
	now := time.Now().Unix()
	if now > deadline {
		panic(newErrorWithDetail(
			errExpired,
			ufmt.Sprintf("transaction too old, now(%d) > deadline(%d)", now, deadline),
		))
	}
}

// assertOnlyUserOrStaker panics if the caller is not a user or staker.
func assertOnlyUserOrStaker(caller std.Realm) {
	if !caller.IsUser() {
		if err := common.StakerOnly(caller.Addr()); err != nil {
			panic(newErrorWithDetail(
				errNoPermission,
				ufmt.Sprintf("from (%s)", caller.Addr()),
			))
		}
	}
}

// assertOnlyNotHalted panics if the contract is halted.
func assertOnlyNotHalted() {
	common.IsHalted()
}

// assertOnlyValidAddress panics if the address is invalid.
func assertOnlyValidAddress(addr std.Address) {
	if !addr.IsValid() {
		panic(newErrorWithDetail(
			errInvalidAddress,
			ufmt.Sprintf("(%s)", addr),
		))
	}
}

// assertOnlyValidAddress panics if the address is invalid or previous address is not
// different from the other address.
func assertOnlyValidAddressWith(prevAddr, otherAddr std.Address) {
	assertOnlyValidAddress(prevAddr)
	assertOnlyValidAddress(otherAddr)

	if prevAddr != otherAddr {
		panic(newErrorWithDetail(
			errInvalidAddress,
			ufmt.Sprintf("(%s, %s)", prevAddr, otherAddr),
		))
	}
}
