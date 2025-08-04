package launchpad

import (
	"std"

	"gno.land/p/demo/ufmt"
)

// assertIsDepositOwner asserts that the caller is the owner of the deposit.
// If the caller is not the owner of the deposit, it panics with an error.
//
// Parameters:
//   - depositID (string): The ID of the deposit to check ownership for
//   - caller (std.Address): The address of the caller to check ownership for
func assertIsDepositOwner(depositID string, caller std.Address) {
	deposit, err := getDeposit(depositID)
	if err != nil {
		panic(err.Error())
	}

	if !deposit.IsOwner(caller) {
		panic(makeErrorWithDetails(errInvalidOwner, ufmt.Sprintf("(%s)", caller.String())).Error())
	}
}

// assertIsValidAmount panics if the amount is zero.
func assertIsValidAmount(amount int64) {
	if amount < minimumDepositAmount {
		panic(makeErrorWithDetails(
			errInvalidAmount,
			ufmt.Sprintf("amount(%d) should greater than minimum deposit amount(%d)", amount, minimumDepositAmount),
		))
	}
	
	if (amount % minimumDepositAmount) != 0 {
		panic(makeErrorWithDetails(
			errInvalidAmount,
			ufmt.Sprintf("amount(%d) must be a multiple of 1_000_000", amount),
		))
	}
}

// assertHasProject asserts that the caller is the owner of at least one project.
// If the caller is not the owner of any project, it panics with an error.
//
// Parameters:
//   - caller (std.Address): The address of the caller to check ownership for
func assertHasProject(caller std.Address) {
	hasProject := false

	projects.Iterate("", "", func(key string, value interface{}) bool {
		project := value.(*Project)
		hasProject = project.IsOwner(caller)

		// if true, break the loop
		return hasProject
	})

	if !hasProject {
		panic(makeErrorWithDetails(
			errInvalidOwner,
			ufmt.Sprintf("caller %s is not the owner of any project", caller.String()),
		))
	}
}
