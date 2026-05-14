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
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/sol"
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

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	solPath = "gno.land/r/gnoswap/test_token/sol"
)

func main() {
	println("[SCENARIO] 1. Alice delegates before any protocol fee token exists")
	delegateWithMint(aliceAddr, 1_000_000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 2. Deposit atom before bob delegation")
	depositProtocolFee(atomPath, 1000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 3. Bob delegates after atom already exists")
	delegateWithMint(bobAddr, 1_000_000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 4. Deposit sol after both delegations exist")
	depositProtocolFee(solPath, 500)
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
	case atomPath:
		atom.Transfer(cross, stakerAddr, amount)
	case solPath:
		sol.Transfer(cross, stakerAddr, amount)
	default:
		panic("unsupported token path")
	}

	testing.SetRealm(stakerRealm)
	switch tokenPath {
	case atomPath:
		atom.Approve(cross, protocolFeeAddr, amount)
	case solPath:
		sol.Approve(cross, protocolFeeAddr, amount)
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
	assertInt64Equal(aliceProtocolFees[atomPath], 999, "alice claimable atom")
	assertInt64Equal(aliceProtocolFees[solPath], 249, "alice claimable sol")
	assertInt64Equal(bobProtocolFees[atomPath], 0, "bob claimable atom")
	assertInt64Equal(bobProtocolFees[solPath], 249, "bob claimable sol")

	ufmt.Printf("[EXPECTED] alice claimable atom: %d\n", aliceProtocolFees[atomPath])
	ufmt.Printf("[EXPECTED] alice claimable sol: %d\n", aliceProtocolFees[solPath])
	ufmt.Printf("[EXPECTED] bob claimable atom: %d\n", bobProtocolFees[atomPath])
	ufmt.Printf("[EXPECTED] bob claimable sol: %d\n", bobProtocolFees[solPath])
}

func collectAndCheck(user address, expectedAtom, expectedSol int64) {
	testing.SetRealm(testing.NewUserRealm(user))
	atomBefore := common.BalanceOf(atomPath, user)
	solBefore := common.BalanceOf(solPath, user)

	staker.CollectReward(cross)

	atomCollected := common.BalanceOf(atomPath, user) - atomBefore
	solCollected := common.BalanceOf(solPath, user) - solBefore

	assertInt64Equal(atomCollected, expectedAtom, user.String()+" collected atom")
	assertInt64Equal(solCollected, expectedSol, user.String()+" collected sol")

	ufmt.Printf("[EXPECTED] %s collected atom: %d\n", user, atomCollected)
	ufmt.Printf("[EXPECTED] %s collected sol: %d\n", user, solCollected)
}

func checkRemainingRewards() {
	remainingAtom := common.BalanceOf(atomPath, gnoStakerAddr)
	remainingSol := common.BalanceOf(solPath, gnoStakerAddr)

	assertInt64Equal(remainingAtom, 1, "remaining atom reward")
	assertInt64Equal(remainingSol, 2, "remaining sol reward")

	ufmt.Printf("[EXPECTED] remaining atom reward: %d\n", remainingAtom)
	ufmt.Printf("[EXPECTED] remaining sol reward: %d\n", remainingSol)
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
// [SCENARIO] 2. Deposit atom before bob delegation
// [INFO] protocol fee deposited: gno.land/r/gnoswap/test_token/atom(1000)
//
// [SCENARIO] 3. Bob delegates after atom already exists
// [INFO] delegated 1000000 GNS from g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu to g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 4. Deposit sol after both delegations exist
// [INFO] protocol fee deposited: gno.land/r/gnoswap/test_token/sol(500)
//
// [SCENARIO] 5. Distribute protocol fee and check claimable rewards
// [EXPECTED] alice claimable atom: 999
// [EXPECTED] alice claimable sol: 249
// [EXPECTED] bob claimable atom: 0
// [EXPECTED] bob claimable sol: 249
//
// [SCENARIO] 6. Collect protocol fee reward for alice
// [EXPECTED] g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh collected atom: 999
// [EXPECTED] g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh collected sol: 249
//
// [SCENARIO] 7. Collect protocol fee reward for bob
// [EXPECTED] g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu collected atom: 0
// [EXPECTED] g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu collected sol: 249
//
// [SCENARIO] 8. Check remaining gov/staker balances
// [EXPECTED] remaining atom reward: 1
// [EXPECTED] remaining sol reward: 2
