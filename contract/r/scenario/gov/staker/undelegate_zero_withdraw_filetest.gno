// zero amount undelegation withdrawal

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

var (
	adminAddr      = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm     = testing.NewUserRealm(adminAddr)
	govStakerAddr  = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm = testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker")

	delegatorAddr  = testutils.TestAddress("zero_withdraw")
	delegatorRealm = testing.NewUserRealm(delegatorAddr)
	validatorAddr  = testutils.TestAddress("zero_validator")
	redelegateFrom = testutils.TestAddress("zero_re_val1")
	redelegateTo   = testutils.TestAddress("zero_re_val2")

	delegateAmount = int64(1_000_000)

	firstDelegationID                      int64
	firstWithdrawalsBeforeSecondUndelegate int
	firstWithdrawalsBeforeRedelegate       int
)

func main(cur realm) {
	println("[SCENARIO] 1. Fund and approve the delegator")
	fundAndApprove(cur)
	println()

	println("[SCENARIO] 2. Create delegation A, then fully undelegate it")
	fullyUndelegateFirstDelegation(cur)
	println()

	println("[SCENARIO] 3. Create delegation B while A is lockup-pending, then undelegate B")
	undelegateSecondDelegation(cur)
	println()

	println("[SCENARIO] 4. Inspect the Undelegate path")
	verifyWithdrawalCounts(cur)
	println()

	println("[SCENARIO] 5. Create pending delegation C, then redelegate active delegation D")
	redelegatePastPendingUndelegation(cur)
	println()

	println("[SCENARIO] 6. Inspect the Redelegate path")
	verifyRedelegation(cur)
	println()
}

func fundAndApprove(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), delegatorAddr, delegateAmount*4)

	testing.SetRealm(delegatorRealm)
	gns.Approve(cross(cur), govStakerAddr, delegateAmount*4)
	ufmt.Printf("[INFO] approved %d GNS for delegation\n", delegateAmount*4)
}

func fullyUndelegateFirstDelegation(cur realm) {
	testing.SetRealm(delegatorRealm)
	staker.Delegate(cross(cur), validatorAddr, delegateAmount, "")

	testing.SetRealm(govStakerRealm)
	firstDelegationID = staker.GetUserDelegationIDs(delegatorAddr, validatorAddr)[0]

	testing.SetRealm(delegatorRealm)
	staker.Undelegate(cross(cur), validatorAddr, delegateAmount)
	firstWithdrawalsBeforeSecondUndelegate = staker.GetDelegationWithdrawCount(firstDelegationID)
	ufmt.Printf("[INFO] A is fully undelegated and has %d pending withdrawal\n", firstWithdrawalsBeforeSecondUndelegate)
}

func undelegateSecondDelegation(cur realm) {
	testing.SetRealm(delegatorRealm)
	staker.Delegate(cross(cur), validatorAddr, delegateAmount, "")
	staker.Undelegate(cross(cur), validatorAddr, delegateAmount)
}

func verifyWithdrawalCounts(cur realm) {
	testing.SetRealm(govStakerRealm)
	delegationIDs := staker.GetUserDelegationIDs(delegatorAddr, validatorAddr)
	if len(delegationIDs) != 2 {
		panic("expected two delegation records")
	}

	firstCount := staker.GetDelegationWithdrawCount(firstDelegationID)
	secondCount := staker.GetDelegationWithdrawCount(delegationIDs[1])
	if firstWithdrawalsBeforeSecondUndelegate != 1 || firstCount != firstWithdrawalsBeforeSecondUndelegate || secondCount != 1 {
		panic("zero amount withdrawal was recorded")
	}

	ufmt.Printf("[CHECK] A withdrawals: before B undelegation=%d, after=%d\n", firstWithdrawalsBeforeSecondUndelegate, firstCount)
	ufmt.Printf("[CHECK] B withdrawals after its undelegation=%d\n", secondCount)
	println("[RESULT] PASS: B's undelegation did not append a zero withdrawal to A")
}

func redelegatePastPendingUndelegation(cur realm) {
	testing.SetRealm(delegatorRealm)
	staker.Delegate(cross(cur), redelegateFrom, delegateAmount, "")

	testing.SetRealm(govStakerRealm)
	firstRedelegationID := staker.GetUserDelegationIDs(delegatorAddr, redelegateFrom)[0]

	testing.SetRealm(delegatorRealm)
	staker.Undelegate(cross(cur), redelegateFrom, delegateAmount)
	firstWithdrawalsBeforeRedelegate = staker.GetDelegationWithdrawCount(firstRedelegationID)
	staker.Delegate(cross(cur), redelegateFrom, delegateAmount, "")
	staker.Redelegate(cross(cur), redelegateFrom, redelegateTo, delegateAmount)

	if firstWithdrawalsBeforeRedelegate != 1 || staker.GetDelegationWithdrawCount(firstRedelegationID) != firstWithdrawalsBeforeRedelegate {
		panic("zero amount withdrawal was recorded during redelegation")
	}
}

func verifyRedelegation(cur realm) {
	testing.SetRealm(govStakerRealm)
	previousDelegationIDs := staker.GetUserDelegationIDs(delegatorAddr, redelegateFrom)
	newDelegationIDs := staker.GetUserDelegationIDs(delegatorAddr, redelegateTo)
	if len(previousDelegationIDs) != 1 || len(newDelegationIDs) != 1 {
		panic("redelegation records are inconsistent")
	}

	pendingWithdrawalCount := staker.GetDelegationWithdrawCount(previousDelegationIDs[0])
	redelegatedWithdrawalCount := staker.GetDelegationWithdrawCount(newDelegationIDs[0])
	if pendingWithdrawalCount != firstWithdrawalsBeforeRedelegate || redelegatedWithdrawalCount != 0 {
		panic("redelegation withdrawal records are inconsistent")
	}

	ufmt.Printf("[CHECK] C withdrawals: before redelegation=%d, after=%d\n", firstWithdrawalsBeforeRedelegate, pendingWithdrawalCount)
	ufmt.Printf("[CHECK] D target withdrawal count=%d\n", redelegatedWithdrawalCount)
	println("[RESULT] PASS: redelegation did not append a zero withdrawal to C")
}

// Output:
// [SCENARIO] 1. Fund and approve the delegator
// [INFO] approved 4000000 GNS for delegation
//
// [SCENARIO] 2. Create delegation A, then fully undelegate it
// [INFO] A is fully undelegated and has 1 pending withdrawal
//
// [SCENARIO] 3. Create delegation B while A is lockup-pending, then undelegate B
//
// [SCENARIO] 4. Inspect the Undelegate path
// [CHECK] A withdrawals: before B undelegation=1, after=1
// [CHECK] B withdrawals after its undelegation=1
// [RESULT] PASS: B's undelegation did not append a zero withdrawal to A
//
// [SCENARIO] 5. Create pending delegation C, then redelegate active delegation D
//
// [SCENARIO] 6. Inspect the Redelegate path
// [CHECK] C withdrawals: before redelegation=1, after=1
// [CHECK] D target withdrawal count=0
// [RESULT] PASS: redelegation did not append a zero withdrawal to C
