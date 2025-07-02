// staker protocol fee reward

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/staker"
	pf "gno.land/r/gnoswap/v1/protocol_fee"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	admin       = consts.ADMIN
	adminRealm  = std.NewUserRealm(admin)
	aliceAddr   = testutils.TestAddress("alice")
	bobAddr     = testutils.TestAddress("bob")
	bobRealm    = std.NewUserRealm(bobAddr)
	stakerRealm = std.NewUserRealm(consts.STAKER_ADDR)

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"
)

func main() {
	println("[SCENARIO] 1. Admin delegates GNS to Alice")
	adminDelegateToAlice()
	println()

	println("[SCENARIO] 2. Mock protocol fee deposit (bar, qux)")
	mockProtocolFeeDeposit()
	println()

	println("[SCENARIO] 3. Bob delegates GNS to Bob")
	bobDelegateToBob()
	println()

	println("[SCENARIO] 4. Mock protocol fee deposit again (bar, qux)")
	mockProtocolFeeDepositAgain()
	println()

	println("[SCENARIO] 5. Skip blocks and distribute protocol fee")
	skipBlocksAndDistribute()
	println()

	println("[SCENARIO] 6. Check and collect protocol fee reward for Bob")
	protocolFeeRewardBob()
	println()

	println("[SCENARIO] 7. Check and collect protocol fee reward for Admin")
	protocolFeeRewardAdmin()
	println()
}

func adminDelegateToAlice() {
	amount := int64(1_000_000)
	testing.SetRealm(adminRealm)
	gns.Approve(cross, consts.GOV_STAKER_ADDR, amount)
	staker.Delegate(cross, aliceAddr, uint64(amount), "")
	ufmt.Printf("[INFO] delegated %d GNS from admin to alice\n", amount)
}

func mockProtocolFeeDeposit() {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 1000)
	qux.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 2500)
	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, barPath, 1000)
	pf.AddToProtocolFee(cross, quxPath, 2500)
	ufmt.Printf("[INFO] protocol fee deposited: bar(1000), qux(2500)\n")
}

func bobDelegateToBob() {
	amount := int64(5_000_000)
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, bobAddr, amount)
	testing.SetRealm(bobRealm)
	gns.Approve(cross, consts.GOV_STAKER_ADDR, amount)
	staker.Delegate(cross, bobAddr, uint64(amount), "")
	ufmt.Printf("[INFO] delegated %d GNS from bob to bob\n", amount)
}

func mockProtocolFeeDepositAgain() {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 1000)
	qux.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 2500)
	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, barPath, 1000)
	pf.AddToProtocolFee(cross, quxPath, 2500)
	ufmt.Printf("[INFO] protocol fee deposited again: bar(1000), qux(2500)\n")
}

func skipBlocksAndDistribute() {
	testing.SkipHeights(10)
	ufmt.Printf("[INFO] skipped 10 blocks\n")
}

func protocolFeeRewardBob() {
	gcr := staker.GetClaimableRewardByAddress(bobAddr)
	ufmt.Printf("[INFO] claimable reward (bob): %s\n", gcr)
	testing.SetRealm(bobRealm)
	staker.CollectReward(cross)
	ufmt.Printf("[INFO] collected protocol fee reward for bob\n")
}

func protocolFeeRewardAdmin() {
	gcr := staker.GetClaimableRewardByAddress(admin)
	ufmt.Printf("[INFO] claimable reward (admin): %s\n", gcr)

	prevBarBalance := bar.BalanceOf(admin)
	prevQuxBalance := qux.BalanceOf(admin)

	testing.SetRealm(adminRealm)
	staker.CollectReward(cross)

	afterBarBalance := bar.BalanceOf(admin)
	afterQuxBalance := qux.BalanceOf(admin)

	ufmt.Printf("[INFO] collected protocol fee reward for admin\n")
	ufmt.Printf("[EXPECTED] collected bar amount: %d\n", afterBarBalance-prevBarBalance)
	ufmt.Printf("[EXPECTED] collected qux amount: %d\n", afterQuxBalance-prevQuxBalance)
}

// Output:
// [SCENARIO] 1. Admin delegates GNS to Alice
// [INFO] delegated 1000000 GNS from admin to alice
//
// [SCENARIO] 2. Mock protocol fee deposit (bar, qux)
// [INFO] protocol fee deposited: bar(1000), qux(2500)
//
// [SCENARIO] 3. Bob delegates GNS to Bob
// [INFO] delegated 5000000 GNS from bob to bob
//
// [SCENARIO] 4. Mock protocol fee deposit again (bar, qux)
// [INFO] protocol fee deposited again: bar(1000), qux(2500)
//
// [SCENARIO] 5. Skip blocks and distribute protocol fee
// [INFO] skipped 10 blocks
//
// [SCENARIO] 6. Check and collect protocol fee reward for Bob
// [INFO] claimable reward (bob): {"height":"133","now":"1234567940","emissionReward":"0","protocolFees":[{"tokenPath":"gno.land/r/onbloc/bar","amount":"833"},{"tokenPath":"gno.land/r/onbloc/qux","amount":"2083"}]}
// [INFO] collected protocol fee reward for bob
//
// [SCENARIO] 7. Check and collect protocol fee reward for Admin
// [INFO] claimable reward (admin): {"height":"133","now":"1234567940","emissionReward":"0","protocolFees":[{"tokenPath":"gno.land/r/onbloc/bar","amount":"1166"},{"tokenPath":"gno.land/r/onbloc/qux","amount":"2916"}]}
// [INFO] collected protocol fee reward for admin
// [EXPECTED] collected bar amount: 1166
// [EXPECTED] collected qux amount: 2916
