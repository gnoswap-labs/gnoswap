package v1

import (
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/gov/staker"
)

// assertIsDepositOwner asserts that the caller is the owner of the deposit.
// Panics if the caller is not the owner of the deposit.
func (lp *launchpadV1) assertIsDepositOwner(depositID string, caller address) {
	deposit, err := lp.getDeposit(depositID)
	if err != nil {
		panic(err.Error())
	}

	if !deposit.IsDepositor(caller) {
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
// Queries gov/staker for O(log N) reverse index lookup.
func (lp *launchpadV1) assertHasProject(caller address) {
	hasProject := staker.HasLaunchpadProject(cross, caller)

	if !hasProject {
		panic(makeErrorWithDetails(
			errInvalidOwner,
			ufmt.Sprintf("caller %s is not the owner of any project", caller.String()),
		))
	}
}
