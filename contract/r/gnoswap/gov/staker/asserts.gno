package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/halt"
)

func assertIsNotHaltedWithdraw() {
	currentLevel := halt.GetCurrentHaltLevel()

	if currentLevel != halt.LvMainnetSafeMode {
		// Check if withdrawals are specifically halted, not just if the system is halted
		if err := halt.IsHalted(halt.OpTypeWithdraw); err != nil {
			panic(err)
		}

		if halt.IsContractHalted(halt.OpTypeGovStaker) {
			panic("gov/staker contract operations are currently disabled")
		}
	}
}

// assertCallerIsAdmin panics if the caller is not an admin
func assertCallerIsAdmin(caller std.Address) {
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}
}

// assertCallerIsLaunchpad panics if the caller is not the launchpad
func assertCallerIsLaunchpad(caller std.Address) {
	if err := common.LaunchpadOnly(caller); err != nil {
		panic(err)
	}
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