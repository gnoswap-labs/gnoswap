package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/halt"
)

func assertIsNotHaltedWithdraw() {
	if halt.IsHaltedGovStaker() {
		panic("gov/staker contract access is currently disabled")
	}

	if halt.IsHaltedWithdraw() {
		panic("gov/staker contract withdrawals are currently disabled")
	}
}

// assertCallerIsLaunchpad panics if the caller is not the launchpad
func assertCallerIsLaunchpad(caller std.Address) {
	access.AssertIsLaunchpad(caller)
}

func assertValidAddress(address std.Address) {
	if !address.IsValid() {
		panic(makeErrorWithDetail(
			errInvalidAddress,
			ufmt.Sprintf("invalid address %s", address.String()),
		))
	}
}

func assertCallerIsDelegator(caller std.Address, from std.Address) {
	if caller.String() != from.String() {
		panic(makeErrorWithDetail(
			errInvalidAddress,
			ufmt.Sprintf("caller and from address are the same"),
		))
	}
}