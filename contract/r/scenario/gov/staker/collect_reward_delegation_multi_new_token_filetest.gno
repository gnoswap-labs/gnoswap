// staker protocol fee reward - new token introduced after delegation

package main

import (
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"

	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/gns"
	pf "gno.land/r/gnoswap/protocol_fee"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	stakerAddr  = access.MustGetAddress(prbac.ROLE_STAKER.String())
	stakerRealm = testing.NewUserRealm(stakerAddr)

	gnoStakerAddr  = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	gnoStakerRealm = testing.NewUserRealm(gnoStakerAddr)

	protocolFeeAddr = access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())

	aliceAddr = testutils.TestAddress("alice")
	bobAddr   = testutils.TestAddress("bob")

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"
)

func main() {
	println("[SCENARIO] 1. Alice delegates before any protocol fee token exists")
	delegateWithMint(aliceAddr, 1_000_000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 2. Deposit bar before bob delegation")
	depositProtocolFee(barPath, 1000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 3. Bob delegates after bar already exists")
	delegateWithMint(bobAddr, 1_000_000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 4. Deposit qux after both delegations exist")
	depositProtocolFee(quxPath, 500)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 5. Distribute protocol fee and check claimable rewards")
	checkClaimableRewards()
	println()

	println("[SCENARIO] 6. Collect protocol fee reward for alice")
	collectAndCheck(aliceAddr, 999, 249)
	println()

	println("[SCENARIO] 7. Collect protocol fee reward for bob")
	collectAndCheck(bobAddr, 0, 249)
	println()

	println("[SCENARIO] 8. Check remaining gov/staker balances")
	checkRemainingRewards()
	println()
}

func delegateWithMint(user address, amount int64) {
	if user != adminAddr {
		testing.SetRealm(adminRealm)
		gns.Transfer(cross, user, amount)
	}

	testing.SetRealm(testing.NewUserRealm(user))
	gns.Approve(cross, gnoStakerAddr, amount)
	staker.Delegate(cross, user, amount, "")

	ufmt.Printf("[INFO] delegated %d GNS from %s to %s\n", amount, user, user)
}

func depositProtocolFee(tokenPath string, amount int64) {
	testing.SetRealm(adminRealm)
	switch tokenPath {
	case barPath:
		bar.Transfer(cross, stakerAddr, amount)
	case quxPath:
		qux.Transfer(cross, stakerAddr, amount)
	default:
		panic("unsupported token path")
	}

	testing.SetRealm(stakerRealm)
	switch tokenPath {
	case barPath:
		bar.Approve(cross, protocolFeeAddr, amount)
	case quxPath:
		qux.Approve(cross, protocolFeeAddr, amount)
	}
	pf.AddToProtocolFee(cross, tokenPath, amount)

	ufmt.Printf("[INFO] protocol fee deposited: %s(%d)\n", tokenPath, amount)
}

func checkClaimableRewards() {
	testing.SetRealm(gnoStakerRealm)
	pf.DistributeProtocolFee(cross)

	aliceEmission, aliceProtocolFees, _ := staker.GetClaimableRewardByAddress(aliceAddr)
	bobEmission, bobProtocolFees, _ := staker.GetClaimableRewardByAddress(bobAddr)

	assertInt64Equal(aliceEmission, 0, "alice emission reward")
	assertInt64Equal(bobEmission, 0, "bob emission reward")
	assertInt64Equal(aliceProtocolFees[barPath], 999, "alice claimable bar")
	assertInt64Equal(aliceProtocolFees[quxPath], 249, "alice claimable qux")
	assertInt64Equal(bobProtocolFees[barPath], 0, "bob claimable bar")
	assertInt64Equal(bobProtocolFees[quxPath], 249, "bob claimable qux")

	ufmt.Printf("[EXPECTED] alice claimable bar: %d\n", aliceProtocolFees[barPath])
	ufmt.Printf("[EXPECTED] alice claimable qux: %d\n", aliceProtocolFees[quxPath])
	ufmt.Printf("[EXPECTED] bob claimable bar: %d\n", bobProtocolFees[barPath])
	ufmt.Printf("[EXPECTED] bob claimable qux: %d\n", bobProtocolFees[quxPath])
}

func collectAndCheck(user address, expectedBar, expectedQux int64) {
	testing.SetRealm(testing.NewUserRealm(user))
	barBefore := common.BalanceOf(barPath, user)
	quxBefore := common.BalanceOf(quxPath, user)

	staker.CollectReward(cross)

	barCollected := common.BalanceOf(barPath, user) - barBefore
	quxCollected := common.BalanceOf(quxPath, user) - quxBefore

	assertInt64Equal(barCollected, expectedBar, user.String()+" collected bar")
	assertInt64Equal(quxCollected, expectedQux, user.String()+" collected qux")

	ufmt.Printf("[EXPECTED] %s collected bar: %d\n", user, barCollected)
	ufmt.Printf("[EXPECTED] %s collected qux: %d\n", user, quxCollected)
}

func checkRemainingRewards() {
	remainingBar := common.BalanceOf(barPath, gnoStakerAddr)
	remainingQux := common.BalanceOf(quxPath, gnoStakerAddr)

	assertInt64Equal(remainingBar, 1, "remaining bar reward")
	assertInt64Equal(remainingQux, 2, "remaining qux reward")

	ufmt.Printf("[EXPECTED] remaining bar reward: %d\n", remainingBar)
	ufmt.Printf("[EXPECTED] remaining qux reward: %d\n", remainingQux)
}

func assertInt64Equal(actual, expected int64, label string) {
	if actual != expected {
		panic(ufmt.Sprintf("%s mismatch: expected %d, got %d", label, expected, actual))
	}
}

// Output:
// [SCENARIO] 1. Alice delegates before any protocol fee token exists
// [INFO] delegated 1000000 GNS from g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh to g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
//
// [SCENARIO] 2. Deposit bar before bob delegation
// [INFO] protocol fee deposited: gno.land/r/onbloc/bar(1000)
//
// [SCENARIO] 3. Bob delegates after bar already exists
// [INFO] delegated 1000000 GNS from g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu to g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 4. Deposit qux after both delegations exist
// [INFO] protocol fee deposited: gno.land/r/onbloc/qux(500)
//
// [SCENARIO] 5. Distribute protocol fee and check claimable rewards
// [EXPECTED] alice claimable bar: 999
// [EXPECTED] alice claimable qux: 249
// [EXPECTED] bob claimable bar: 0
// [EXPECTED] bob claimable qux: 249
//
// [SCENARIO] 6. Collect protocol fee reward for alice
// [EXPECTED] g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh collected bar: 999
// [EXPECTED] g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh collected qux: 249
//
// [SCENARIO] 7. Collect protocol fee reward for bob
// [EXPECTED] g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu collected bar: 0
// [EXPECTED] g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu collected qux: 249
//
// [SCENARIO] 8. Check remaining gov/staker balances
// [EXPECTED] remaining bar reward: 1
// [EXPECTED] remaining qux reward: 2
