package launchpad

import (
	ufmt "gno.land/p/nt/ufmt/v0"
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

// assertIsValidAmount panics if the amount is below the minimum deposit or is not a multiple of it.
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
func (lp *launchpadV1) assertHasProject(caller address) {
	if !lp.store.GetProjectRecipients().Has(caller.String()) {
		panic(makeErrorWithDetails(
			errInvalidOwner,
			ufmt.Sprintf("caller %s is not the owner of any project", caller.String()),
		))
	}
}

func assertNotImplementYet() {
	panic("NotImplementYet")
}
