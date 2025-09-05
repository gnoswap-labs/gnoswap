package launchpad

import (
	"std"

	"gno.land/p/nt/ufmt"
)

// assertIsDepositOwner asserts that the caller is the owner of the deposit.
// Panics if the caller is not the owner of the deposit.
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
// Panics if the caller is not the owner of any project.
func assertHasProject(caller std.Address) {
	hasProject := false

	projects.Iterate("", "", func(key string, value interface{}) bool {
		project, ok := value.(*Project)
		if !ok {
			panic(ufmt.Sprintf("failed to cast projects's element to *Project: %T", value))
		}

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
