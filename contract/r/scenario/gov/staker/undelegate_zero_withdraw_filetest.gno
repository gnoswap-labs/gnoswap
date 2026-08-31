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

	delegateAmount    = int64(1_000_000)
	firstDelegationID int64
)

func main(cur realm) {
	println("[SCENARIO] 1. Fund and approve the delegator")
	fundAndApprove(cur)
	println()

	println("[SCENARIO] 2. Fully undelegate the first delegation")
	fullyUndelegateFirstDelegation(cur)
	println()

	println("[SCENARIO] 3. Delegate and undelegate again before the first lockup expires")
	undelegateSecondDelegation(cur)
	println()

	println("[SCENARIO] 4. Verify no zero withdrawal was added to the first delegation")
	verifyWithdrawalCounts(cur)
	println()

	println("[SCENARIO] 5. Redelegate past a lockup-pending delegation")
	redelegatePastPendingUndelegation(cur)
	println()

	println("[SCENARIO] 6. Verify redelegation preserved the pending withdrawal")
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
	ufmt.Printf("[INFO] first delegation ID: %d, withdrawal count: %d\n", firstDelegationID, staker.GetDelegationWithdrawCount(firstDelegationID))
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
	if firstCount != 1 || secondCount != 1 {
		panic("zero amount withdrawal was recorded")
	}

	ufmt.Printf("[EXPECTED] first delegation withdrawal count remains 1: %t\n", firstCount == 1)
	ufmt.Printf("[EXPECTED] second delegation withdrawal count is 1: %t\n", secondCount == 1)
}

func redelegatePastPendingUndelegation(cur realm) {
	testing.SetRealm(delegatorRealm)
	staker.Delegate(cross(cur), redelegateFrom, delegateAmount, "")

	testing.SetRealm(govStakerRealm)
	firstRedelegationID := staker.GetUserDelegationIDs(delegatorAddr, redelegateFrom)[0]

	testing.SetRealm(delegatorRealm)
	staker.Undelegate(cross(cur), redelegateFrom, delegateAmount)
	staker.Delegate(cross(cur), redelegateFrom, delegateAmount, "")
	staker.Redelegate(cross(cur), redelegateFrom, redelegateTo, delegateAmount)

	testing.SetRealm(govStakerRealm)
	if staker.GetDelegationWithdrawCount(firstRedelegationID) != 1 {
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

	ufmt.Printf("[EXPECTED] pending delegation remains at previous validator: %t\n", len(previousDelegationIDs) == 1)
	ufmt.Printf("[EXPECTED] redelegated delegation exists at new validator: %t\n", len(newDelegationIDs) == 1)
}

// Output:
// [SCENARIO] 1. Fund and approve the delegator
// [INFO] approved 4000000 GNS for delegation
//
// [SCENARIO] 2. Fully undelegate the first delegation
// [INFO] first delegation ID: 1, withdrawal count: 1
//
// [SCENARIO] 3. Delegate and undelegate again before the first lockup expires
//
// [SCENARIO] 4. Verify no zero withdrawal was added to the first delegation
// [EXPECTED] first delegation withdrawal count remains 1: true
// [EXPECTED] second delegation withdrawal count is 1: true
//
// [SCENARIO] 5. Redelegate past a lockup-pending delegation
//
// [SCENARIO] 6. Verify redelegation preserved the pending withdrawal
// [EXPECTED] pending delegation remains at previous validator: true
// [EXPECTED] redelegated delegation exists at new validator: true
