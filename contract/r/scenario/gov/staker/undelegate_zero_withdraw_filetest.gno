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
}

func fundAndApprove(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), delegatorAddr, delegateAmount*2)

	testing.SetRealm(delegatorRealm)
	gns.Approve(cross(cur), govStakerAddr, delegateAmount*2)
	ufmt.Printf("[INFO] approved %d GNS for delegation\n", delegateAmount*2)
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

// Output:
// [SCENARIO] 1. Fund and approve the delegator
// [INFO] approved 2000000 GNS for delegation
//
// [SCENARIO] 2. Fully undelegate the first delegation
// [INFO] first delegation ID: 1, withdrawal count: 1
//
// [SCENARIO] 3. Delegate and undelegate again before the first lockup expires
//
// [SCENARIO] 4. Verify no zero withdrawal was added to the first delegation
// [EXPECTED] first delegation withdrawal count remains 1: true
// [EXPECTED] second delegation withdrawal count is 1: true
