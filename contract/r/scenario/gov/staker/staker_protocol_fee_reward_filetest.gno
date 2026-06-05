// PKGPATH: gno.land/r/gnoswap/v1/main

// staker protocol fee reward

package main

import (
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/protocol_fee"
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
	protocolFeeV1Realm = testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1")

	gnoStakerAddr  = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	gnoStakerRealm = testing.NewUserRealm(gnoStakerAddr)

	aliceAddr = testutils.TestAddress("alice")
	bobAddr   = testutils.TestAddress("bob")
	bobRealm  = testing.NewUserRealm(bobAddr)

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"
)

func fundAndApproveProtocolFeeCallerBar(cur realm, amount int64) {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), stakerAddr, amount)
	testing.SetRealm(stakerRealm)
	bar.Approve(cross(cur), protocolFeeAddr, amount)
	bar.Approve(cross(cur), protocolFeeV1Realm.Address(), amount)
}

func fundAndApproveProtocolFeeCallerQux(cur realm, amount int64) {
	testing.SetRealm(adminRealm)
	qux.Transfer(cross(cur), stakerAddr, amount)
	testing.SetRealm(stakerRealm)
	qux.Approve(cross(cur), protocolFeeAddr, amount)
	qux.Approve(cross(cur), protocolFeeV1Realm.Address(), amount)
}

func main(cur realm) {
	println("[SCENARIO] 1. Admin delegates GNS to Alice")
	adminDelegateToAlice(cur)
	println()

	println("[SCENARIO] 2. Mock protocol fee deposit (bar, qux)")
	mockProtocolFeeDeposit(cur)
	println()

	println("[SCENARIO] 3. Bob delegates GNS to Bob")
	bobDelegateToBob(cur)
	println()

	println("[SCENARIO] 4. Mock protocol fee deposit again (bar, qux)")
	mockProtocolFeeDepositAgain(cur)
	println()

	println("[SCENARIO] 5. Skip blocks and distribute protocol fee")
	skipBlocksAndDistribute(cur)
	println()

	println("[SCENARIO] 6. Check and collect protocol fee reward for Bob")
	protocolFeeRewardBob(cur)
	println()

	println("[SCENARIO] 7. Check and collect protocol fee reward for Admin")
	protocolFeeRewardAdmin(cur)
	println()
}

func adminDelegateToAlice(cur realm) {
	amount := int64(1_000_000)
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), gnoStakerAddr, amount)
	staker.Delegate(cross(cur), aliceAddr, int64(amount), "")
	ufmt.Printf("[INFO] delegated %d GNS from adminAddr to alice\n", amount)
}

func mockProtocolFeeDeposit(cur realm) {
	fundAndApproveProtocolFeeCallerBar(cur, 1000)
	fundAndApproveProtocolFeeCallerQux(cur, 2500)
	testing.SetRealm(stakerRealm)
	bar.Approve(cross(cur), protocolFeeAddr, 1000)
	qux.Approve(cross(cur), protocolFeeAddr, 2500)
	pf.AddToProtocolFee(cross(cur), barPath, 1000)
	pf.AddToProtocolFee(cross(cur), quxPath, 2500)
	print("[INFO] protocol fee deposited: bar(1000), qux(2500)\n")
}

func bobDelegateToBob(cur realm) {
	amount := int64(5_000_000)
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), bobAddr, amount)
	testing.SetRealm(bobRealm)
	gns.Approve(cross(cur), gnoStakerAddr, amount)
	staker.Delegate(cross(cur), bobAddr, int64(amount), "")
	ufmt.Printf("[INFO] delegated %d GNS from bob to bob\n", amount)
}

func mockProtocolFeeDepositAgain(cur realm) {
	fundAndApproveProtocolFeeCallerBar(cur, 1000)
	fundAndApproveProtocolFeeCallerQux(cur, 2500)
	testing.SetRealm(stakerRealm)
	bar.Approve(cross(cur), protocolFeeAddr, 1000)
	qux.Approve(cross(cur), protocolFeeAddr, 2500)
	pf.AddToProtocolFee(cross(cur), barPath, 1000)
	pf.AddToProtocolFee(cross(cur), quxPath, 2500)
	println("[INFO] protocol fee deposited again: bar(1000), qux(2500)")
}

func skipBlocksAndDistribute(cur realm) {
	testing.SkipHeights(10)
	println("[INFO] skipped 10 blocks")
}

func formatProtocolFees(cur realm, fees map[string]int64) string {
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

func protocolFeeRewardBob(cur realm) {
	testing.SetRealm(gnoStakerRealm)
	emission.MintAndDistributeGns(cross(cur))
	protocol_fee.DistributeProtocolFee(cross(cur))
	emissionReward, protocolFees, _ := staker.GetClaimableRewardByAddress(bobAddr)
	ufmt.Printf("[INFO] claimable reward (bob): emissionReward=%d, protocolFees=%s\n", emissionReward, formatProtocolFees(cur, protocolFees))
	testing.SetRealm(bobRealm)
	staker.CollectReward(cross(cur))
	println("[INFO] collected protocol fee reward for bob")
}

func protocolFeeRewardAdmin(cur realm) {
	testing.SetRealm(gnoStakerRealm)
	emission.MintAndDistributeGns(cross(cur))
	protocol_fee.DistributeProtocolFee(cross(cur))
	emissionReward, protocolFees, _ := staker.GetClaimableRewardByAddress(adminAddr)
	ufmt.Printf("[INFO] claimable reward (adminAddr): emissionReward=%d, protocolFees=%s\n", emissionReward, formatProtocolFees(cur, protocolFees))

	prevBarBalance := bar.BalanceOf(adminAddr)
	prevQuxBalance := qux.BalanceOf(adminAddr)

	testing.SetRealm(adminRealm)
	staker.CollectReward(cross(cur))

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
