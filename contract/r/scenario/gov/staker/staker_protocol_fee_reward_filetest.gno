// staker protocol fee reward

package main

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	pf "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	stakerAddr  = access.MustGetAddress(prbac.ROLE_STAKER.String())
	stakerRealm = testing.NewUserRealm(stakerAddr)

	protocolFeeAddr = access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())

	gnoStakerAddr  = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	gnoStakerRealm = testing.NewUserRealm(gnoStakerAddr)

	aliceAddr = testutils.TestAddress("alice")
	bobAddr   = testutils.TestAddress("bob")
	bobRealm  = testing.NewUserRealm(bobAddr)

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
	gns.Approve(cross, gnoStakerAddr, amount)
	staker.Delegate(cross, aliceAddr, int64(amount), "")
	ufmt.Printf("[INFO] delegated %d GNS from adminAddr to alice\n", amount)
}

func mockProtocolFeeDeposit() {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, protocolFeeAddr, 1000)
	qux.Transfer(cross, protocolFeeAddr, 2500)
	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, barPath, 1000)
	pf.AddToProtocolFee(cross, quxPath, 2500)
	print("[INFO] protocol fee deposited: bar(1000), qux(2500)\n")
}

func bobDelegateToBob() {
	amount := int64(5_000_000)
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, bobAddr, amount)
	testing.SetRealm(bobRealm)
	gns.Approve(cross, gnoStakerAddr, amount)
	staker.Delegate(cross, bobAddr, int64(amount), "")
	ufmt.Printf("[INFO] delegated %d GNS from bob to bob\n", amount)
}

func mockProtocolFeeDepositAgain() {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, protocolFeeAddr, 1000)
	qux.Transfer(cross, protocolFeeAddr, 2500)
	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, barPath, 1000)
	pf.AddToProtocolFee(cross, quxPath, 2500)
	println("[INFO] protocol fee deposited again: bar(1000), qux(2500)")
}

func skipBlocksAndDistribute() {
	testing.SkipHeights(10)
	println("[INFO] skipped 10 blocks")
}

func formatProtocolFees(fees map[string]int64) string {
	if len(fees) == 0 {
		return "map[]"
	}
	result := "map["
	first := true
	for k, v := range fees {
		if !first {
			result += " "
		}
		result += k + ":" + ufmt.Sprintf("%d", v)
		first = false
	}
	result += "]"
	return result
}

func protocolFeeRewardBob() {
	testing.SetRealm(gnoStakerRealm)
	emissionReward, protocolFees := staker.GetClaimableRewardByAddress(bobAddr)
	ufmt.Printf("[INFO] claimable reward (bob): emissionReward=%d, protocolFees=%s\n", emissionReward, formatProtocolFees(protocolFees))
	testing.SetRealm(bobRealm)
	staker.CollectReward(cross)
	println("[INFO] collected protocol fee reward for bob")
}

func protocolFeeRewardAdmin() {
	testing.SetRealm(gnoStakerRealm)
	emissionReward, protocolFees := staker.GetClaimableRewardByAddress(adminAddr)
	ufmt.Printf("[INFO] claimable reward (adminAddr): emissionReward=%d, protocolFees=%s\n", emissionReward, formatProtocolFees(protocolFees))

	prevBarBalance := bar.BalanceOf(adminAddr)
	prevQuxBalance := qux.BalanceOf(adminAddr)

	testing.SetRealm(adminRealm)
	staker.CollectReward(cross)

	afterBarBalance := bar.BalanceOf(adminAddr)
	afterQuxBalance := qux.BalanceOf(adminAddr)

	println("[INFO] collected protocol fee reward for adminAddr")
	ufmt.Printf("[EXPECTED] collected bar amount: %d\n", afterBarBalance-prevBarBalance)
	ufmt.Printf("[EXPECTED] collected qux amount: %d\n", afterQuxBalance-prevQuxBalance)
}

// Output:
// [SCENARIO] 1. Admin delegates GNS to Alice
// [INFO] delegated 1000000 GNS from adminAddr to alice
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
// [INFO] claimable reward (bob): emissionReward=0, protocolFees=map[gno.land/r/onbloc/bar:833 gno.land/r/onbloc/qux:2083]
// [INFO] collected protocol fee reward for bob
//
// [SCENARIO] 7. Check and collect protocol fee reward for Admin
// [INFO] claimable reward (adminAddr): emissionReward=0, protocolFees=map[gno.land/r/onbloc/bar:1166 gno.land/r/onbloc/qux:2916]
// [INFO] collected protocol fee reward for adminAddr
// [EXPECTED] collected bar amount: 1166
// [EXPECTED] collected qux amount: 2916
