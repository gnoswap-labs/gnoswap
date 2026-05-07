// dao contract delegate lifecycle

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
	"gno.land/r/gnoswap/gov/xgns"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

var (
	adminAddr     = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm = testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker")

	originAddr  = testutils.TestAddress("dao-origin")
	originRealm = testing.NewUserRealm(originAddr)

	daoPath  = "gno.land/r/onbloc/dao"
	daoRealm = testing.NewCodeRealm(daoPath)
	daoAddr  = daoRealm.Address()

	validator1Addr = testutils.TestAddress("validator1")
	validator2Addr = testutils.TestAddress("validator2")

	transferredAmount = int64(7_000_000)
	delegateAmount    = int64(5_000_000)
	undelegateAmount  = int64(2_000_000)
	lockupHeights     = int64(120960)

	initialDaoDelegationID    int64
	redelegatedDaoDelegationID int64
)

func main() {
	println("[SCENARIO] 1. Fund DAO contract and verify initial balances")
	setupDaoBalance()
	println()

	println("[SCENARIO] 2. DAO contract delegates to validator1")
	daoDelegateToValidator1()
	println()

	println("[SCENARIO] 3. Verify delegation belongs to DAO contract, not origin user")
	verifyDaoOwnedDelegationAfterDelegate()
	println()

	println("[SCENARIO] 4. DAO contract redelegates from validator1 to validator2")
	daoRedelegateToValidator2()
	println()

	println("[SCENARIO] 5. DAO contract undelegates partial amount from validator2")
	daoUndelegatePartial()
	println()

	println("[SCENARIO] 6. DAO contract collect before lockup returns zero")
	collectBeforeLockup()
	println()

	println("[SCENARIO] 7. Skip undelegation lockup and collect as DAO contract")
	collectAfterLockup()
	println()
	}

func setupDaoBalance() {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, daoAddr, transferredAmount)

	ufmt.Printf("[INFO] transferred %d GNS to DAO contract\n", transferredAmount)
	ufmt.Printf("[EXPECTED] DAO GNS balance: %d\n", gns.BalanceOf(daoAddr))
	ufmt.Printf("[EXPECTED] origin user GNS balance: %d\n", gns.BalanceOf(originAddr))
	ufmt.Printf("[EXPECTED] DAO xGNS balance: %d\n", xgns.BalanceOf(daoAddr))
	ufmt.Printf("[EXPECTED] origin user xGNS balance: %d\n", xgns.BalanceOf(originAddr))
}

func daoDelegateToValidator1() {
	testing.SetRealm(daoRealm)
	gns.Approve(cross, govStakerAddr, delegateAmount)

	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	func(cur realm) {
		testing.SetRealm(daoRealm)
		staker.Delegate(cross, validator1Addr, delegateAmount, "")
	}(cross)

	ufmt.Printf("[INFO] DAO delegated %d GNS to validator1\n", delegateAmount)
	ufmt.Printf("[EXPECTED] DAO GNS balance after delegate: %d\n", gns.BalanceOf(daoAddr))
	ufmt.Printf("[EXPECTED] DAO xGNS balance after delegate: %d\n", xgns.BalanceOf(daoAddr))
	ufmt.Printf("[EXPECTED] origin user xGNS balance after delegate: %d\n", xgns.BalanceOf(originAddr))
}

func verifyDaoOwnedDelegationAfterDelegate() {
	testing.SetRealm(govStakerRealm)
	daoDelegationIDs := staker.GetUserDelegationIDs(daoAddr, validator1Addr)
	originDelegationIDs := staker.GetUserDelegationIDs(originAddr, validator1Addr)

	ufmt.Printf("[EXPECTED] DAO delegation count to validator1: %d\n", len(daoDelegationIDs))
	ufmt.Printf("[EXPECTED] origin delegation count to validator1: %d\n", len(originDelegationIDs))

	if len(daoDelegationIDs) == 0 {
		panic("dao delegation not found")
	}

	daoDelegation, err := staker.GetDelegation(daoDelegationIDs[0])
	if err != nil {
		panic(err)
	}

	initialDaoDelegationID = daoDelegationIDs[0]

	ufmt.Printf("[EXPECTED] delegation owner is DAO contract: %t\n", daoDelegation.DelegateFrom() == daoAddr)
	ufmt.Printf("[EXPECTED] delegation target is validator1: %t\n", daoDelegation.DelegateTo() == validator1Addr)
	ufmt.Printf("[EXPECTED] initial DAO delegation ID: %d\n", initialDaoDelegationID)
	ufmt.Printf("[EXPECTED] delegation record ID matches DAO lookup ID: %t\n", daoDelegation.ID() == initialDaoDelegationID)
	ufmt.Printf("[EXPECTED] DAO total delegated amount: %d\n", daoDelegation.TotalDelegatedAmount())
	ufmt.Printf("[EXPECTED] total locked amount after delegate: %d\n", staker.GetTotalLockedAmount())
}

func daoRedelegateToValidator2() {
	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	func(cur realm) {
		testing.SetRealm(daoRealm)
		staker.Redelegate(cross, validator1Addr, validator2Addr, delegateAmount)
	}(cross)

	testing.SetRealm(govStakerRealm)
	oldDelegationIDs := staker.GetUserDelegationIDs(daoAddr, validator1Addr)
	newDelegationIDs := staker.GetUserDelegationIDs(daoAddr, validator2Addr)
	if len(oldDelegationIDs) == 0 || len(newDelegationIDs) == 0 {
		panic("dao redelegation ids missing")
	}

	oldDelegation, err := staker.GetDelegation(oldDelegationIDs[0])
	if err != nil {
		panic(err)
	}
	newDelegation, err := staker.GetDelegation(newDelegationIDs[0])
	if err != nil {
		panic(err)
	}

	redelegatedDaoDelegationID = newDelegationIDs[0]

	ufmt.Printf("[INFO] DAO redelegated %d GNS from validator1 to validator2\n", delegateAmount)
	ufmt.Printf("[EXPECTED] DAO delegation count to validator1 after redelegate: %d\n", len(oldDelegationIDs))
	ufmt.Printf("[EXPECTED] DAO delegation count to validator2 after redelegate: %d\n", len(newDelegationIDs))
	ufmt.Printf("[EXPECTED] validator1 delegation ID preserved after redelegate: %t\n", oldDelegationIDs[0] == initialDaoDelegationID)
	ufmt.Printf("[EXPECTED] validator1 record ID matches preserved lookup ID: %t\n", oldDelegation.ID() == initialDaoDelegationID)
	ufmt.Printf("[EXPECTED] validator2 delegation uses a new ID: %t\n", redelegatedDaoDelegationID != initialDaoDelegationID)
	ufmt.Printf("[EXPECTED] validator2 record ID matches new lookup ID: %t\n", newDelegation.ID() == redelegatedDaoDelegationID)
	ufmt.Printf("[EXPECTED] DAO xGNS balance after redelegate: %d\n", xgns.BalanceOf(daoAddr))
	ufmt.Printf("[EXPECTED] total locked amount after redelegate: %d\n", staker.GetTotalLockedAmount())
}

func daoUndelegatePartial() {
	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	func(cur realm) {
		testing.SetRealm(daoRealm)
		staker.Undelegate(cross, validator2Addr, undelegateAmount)
	}(cross)

	testing.SetRealm(govStakerRealm)
	daoDelegationIDs := staker.GetUserDelegationIDs(daoAddr, validator2Addr)
	if len(daoDelegationIDs) == 0 {
		panic("dao delegation missing after undelegate")
	}

	daoDelegation, err := staker.GetDelegation(daoDelegationIDs[0])
	if err != nil {
		panic(err)
	}
	withdraws, err := staker.GetDelegationWithdraws(daoDelegationIDs[0], 0, 10)
	if err != nil {
		panic(err)
	}
	if len(withdraws) == 0 {
		panic("dao withdraw missing after undelegate")
	}

	remainingDelegatedAmount := daoDelegation.TotalDelegatedAmount() - daoDelegation.UnDelegatedAmount()

	ufmt.Printf("[INFO] DAO undelegated %d GNS from validator2\n", undelegateAmount)
	ufmt.Printf("[EXPECTED] validator2 delegation ID preserved after undelegate: %t\n", daoDelegationIDs[0] == redelegatedDaoDelegationID)
	ufmt.Printf("[EXPECTED] withdraw delegation ID matches validator2 delegation ID: %t\n", withdraws[0].DelegationID() == redelegatedDaoDelegationID)
	ufmt.Printf("[EXPECTED] remaining delegated amount on validator2: %d\n", remainingDelegatedAmount)
	ufmt.Printf("[EXPECTED] undelegated amount tracked on validator2: %d\n", daoDelegation.UnDelegatedAmount())
	ufmt.Printf("[EXPECTED] withdraw entry count: %d\n", len(withdraws))
	ufmt.Printf("[EXPECTED] total locked amount before collect: %d\n", staker.GetTotalLockedAmount())
}

func collectBeforeLockup() {
	balanceBefore := gns.BalanceOf(daoAddr)

	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	var collected int64
	func(cur realm) {
		testing.SetRealm(daoRealm)
		collected = staker.CollectUndelegatedGns(cross)
	}(cross)

	ufmt.Printf("[EXPECTED] collected before lockup: %d\n", collected)
	ufmt.Printf("[EXPECTED] DAO GNS balance before lockup collect: %d\n", gns.BalanceOf(daoAddr))
	ufmt.Printf("[EXPECTED] DAO GNS balance unchanged before lockup: %t\n", balanceBefore == gns.BalanceOf(daoAddr))
}

func collectAfterLockup() {
	testing.SkipHeights(lockupHeights)
	balanceBefore := gns.BalanceOf(daoAddr)

	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	var collected int64
	func(cur realm) {
		testing.SetRealm(daoRealm)
		collected = staker.CollectUndelegatedGns(cross)
	}(cross)

	ufmt.Printf("[EXPECTED] collected after lockup: %d\n", collected)
	ufmt.Printf("[EXPECTED] DAO GNS balance after collect: %d\n", gns.BalanceOf(daoAddr))
	ufmt.Printf("[EXPECTED] DAO xGNS balance after collect: %d\n", xgns.BalanceOf(daoAddr))
	ufmt.Printf("[EXPECTED] origin user GNS balance after collect: %d\n", gns.BalanceOf(originAddr))
	ufmt.Printf("[EXPECTED] total locked amount after collect: %d\n", staker.GetTotalLockedAmount())
	ufmt.Printf("[EXPECTED] DAO GNS delta after collect: %d\n", gns.BalanceOf(daoAddr)-balanceBefore)

	testing.SetRealm(govStakerRealm)
	validator1DelegationIDs := staker.GetUserDelegationIDs(daoAddr, validator1Addr)
	validator2DelegationIDs := staker.GetUserDelegationIDs(daoAddr, validator2Addr)
	validator2Withdraws, err := staker.GetDelegationWithdraws(redelegatedDaoDelegationID, 0, 10)
	if err != nil {
		panic(err)
	}

	ufmt.Printf("[EXPECTED] validator1 delegation removed after collect: %t\n", len(validator1DelegationIDs) == 0)
	ufmt.Printf("[EXPECTED] validator2 delegation count after collect: %d\n", len(validator2DelegationIDs))
	ufmt.Printf("[EXPECTED] validator2 delegation ID preserved after collect: %t\n", len(validator2DelegationIDs) == 1 && validator2DelegationIDs[0] == redelegatedDaoDelegationID)
	ufmt.Printf("[EXPECTED] collected withdraw removed after collect: %t\n", len(validator2Withdraws) == 0)
}

// Output:
// [SCENARIO] 1. Fund DAO contract and verify initial balances
// [INFO] transferred 7000000 GNS to DAO contract
// [EXPECTED] DAO GNS balance: 7000000
// [EXPECTED] origin user GNS balance: 0
// [EXPECTED] DAO xGNS balance: 0
// [EXPECTED] origin user xGNS balance: 0
//
// [SCENARIO] 2. DAO contract delegates to validator1
// [INFO] DAO delegated 5000000 GNS to validator1
// [EXPECTED] DAO GNS balance after delegate: 2000000
// [EXPECTED] DAO xGNS balance after delegate: 5000000
// [EXPECTED] origin user xGNS balance after delegate: 0
//
// [SCENARIO] 3. Verify delegation belongs to DAO contract, not origin user
// [EXPECTED] DAO delegation count to validator1: 1
// [EXPECTED] origin delegation count to validator1: 0
// [EXPECTED] delegation owner is DAO contract: true
// [EXPECTED] delegation target is validator1: true
// [EXPECTED] initial DAO delegation ID: 1
// [EXPECTED] delegation record ID matches DAO lookup ID: true
// [EXPECTED] DAO total delegated amount: 5000000
// [EXPECTED] total locked amount after delegate: 5000000
//
// [SCENARIO] 4. DAO contract redelegates from validator1 to validator2
// [INFO] DAO redelegated 5000000 GNS from validator1 to validator2
// [EXPECTED] DAO delegation count to validator1 after redelegate: 1
// [EXPECTED] DAO delegation count to validator2 after redelegate: 1
// [EXPECTED] validator1 delegation ID preserved after redelegate: true
// [EXPECTED] validator1 record ID matches preserved lookup ID: true
// [EXPECTED] validator2 delegation uses a new ID: true
// [EXPECTED] validator2 record ID matches new lookup ID: true
// [EXPECTED] DAO xGNS balance after redelegate: 5000000
// [EXPECTED] total locked amount after redelegate: 5000000
//
// [SCENARIO] 5. DAO contract undelegates partial amount from validator2
// [INFO] DAO undelegated 2000000 GNS from validator2
// [EXPECTED] validator2 delegation ID preserved after undelegate: true
// [EXPECTED] withdraw delegation ID matches validator2 delegation ID: true
// [EXPECTED] remaining delegated amount on validator2: 3000000
// [EXPECTED] undelegated amount tracked on validator2: 2000000
// [EXPECTED] withdraw entry count: 1
// [EXPECTED] total locked amount before collect: 5000000
//
// [SCENARIO] 6. DAO contract collect before lockup returns zero
// [EXPECTED] collected before lockup: 0
// [EXPECTED] DAO GNS balance before lockup collect: 2000000
// [EXPECTED] DAO GNS balance unchanged before lockup: true
//
// [SCENARIO] 7. Skip undelegation lockup and collect as DAO contract
// [EXPECTED] collected after lockup: 2000000
// [EXPECTED] DAO GNS balance after collect: 4000000
// [EXPECTED] DAO xGNS balance after collect: 3000000
// [EXPECTED] origin user GNS balance after collect: 0
// [EXPECTED] total locked amount after collect: 3000000
// [EXPECTED] DAO GNS delta after collect: 2000000
// [EXPECTED] validator1 delegation removed after collect: true
// [EXPECTED] validator2 delegation count after collect: 1
// [EXPECTED] validator2 delegation ID preserved after collect: true
// [EXPECTED] collected withdraw removed after collect: true
