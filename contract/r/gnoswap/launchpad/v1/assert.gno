package launchpad

import (
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/launchpad"
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

// assertIsDepositNotWithdrawn asserts that the deposit is not withdrawn.
func assertIsDepositNotWithdrawn(deposit launchpad.Deposit) {
	if deposit.IsWithdrawn() {
		panic(makeErrorWithDetails(errAlreadyCollected, ufmt.Sprintf("(%s)", deposit.ID())))
	}
}

// assertIsDepositEnded asserts that the deposit is ended.
func assertIsDepositEnded(deposit launchpad.Deposit, currentTime int64) {
	if !deposit.IsEnded(currentTime) {
		panic(makeErrorWithDetails(errNotYetEndedProject, ufmt.Sprintf("(%s)", deposit.ID())))
	}
}

// assertHasTierReward asserts that the tier has rewards to distribute.
// A zero-rate tier cannot settle rewards, which would lock withdrawals.
func assertHasTierReward(tier *launchpad.ProjectTier) {
	if tier.DistributeAmountPerSecondX128().IsZero() {
		panic(makeErrorWithDetails(errNoLeftReward, ufmt.Sprintf("(%s)", tier.ID())))
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
