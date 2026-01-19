// check delegation voting power transfer accuracy
//
// Scenario:
// 1. Alice delegates GNS to Bob - verify voting weight is minted to delegatee (Bob)
// 2. Alice undelegates from Bob - verify voting weight is burned from delegatee (Bob)

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"

	gs "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr     = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())

	aliceAddr = testutils.TestAddress("alice")
	bobAddr   = testutils.TestAddress("bob")

	currentBlockTime              = int64(2)
	votingWeightSmoothingDuration = int64(0)
)

func main() {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	config := governance.GetLatestConfig()
	votingWeightSmoothingDuration = int64(config.VotingWeightSmoothingDuration)

	println("[SCENARIO] 1. Transfer GNS to alice for delegation")
	transferGnsToAlice()
	println()

	println("[SCENARIO] 2. Check initial voting power (before delegation)")
	checkVotingPower("alice", aliceAddr)
	checkVotingPower("bob", bobAddr)
	println()

	println("[SCENARIO] 3. Alice delegates GNS to Bob")
	delegateFromAliceToBob()
	println()

	println("[SCENARIO] 4. Skip voting weight smoothing duration")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println()

	println("[SCENARIO] 5. Check voting power after delegation")
	checkVotingPowerAfterDelegation()
	println()

	println("[SCENARIO] 6. Alice undelegates from Bob")
	undelegateFromBob()
	println()

	println("[SCENARIO] 7. Skip voting weight smoothing duration for voting power update")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println()

	println("[SCENARIO] 8. Check voting power after undelegation")
	checkVotingPowerAfterUndelegation()
	println()
}

func transferGnsToAlice() {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, aliceAddr, 2_000_000_000)
	ufmt.Printf("[INFO] transferred 2,000,000,000 GNS to alice\n")
}

func checkVotingPower(name string, addr address) {
	votingWeight, _ := gs.GetUserDelegationAmountAtSnapshot(addr, time.Now().Unix()-votingWeightSmoothingDuration)
	ufmt.Printf("[INFO] %s voting weight: %d\n", name, votingWeight)
}

func delegateFromAliceToBob() {
	delegateAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(aliceAddr))

	gns.Approve(cross, govStakerAddr, delegateAmount)
	gs.Delegate(cross, bobAddr, delegateAmount, "")

	ufmt.Printf("[INFO] alice delegated %d GNS to bob\n", delegateAmount)
}

func checkVotingPowerAfterDelegation() {
	aliceVotingWeight, _ := gs.GetUserDelegationAmountAtSnapshot(aliceAddr, time.Now().Unix()-votingWeightSmoothingDuration)
	bobVotingWeight, _ := gs.GetUserDelegationAmountAtSnapshot(bobAddr, time.Now().Unix()-votingWeightSmoothingDuration)

	ufmt.Printf("[INFO] alice voting weight after delegation: %d\n", aliceVotingWeight)
	ufmt.Printf("[INFO] bob voting weight after delegation: %d\n", bobVotingWeight)

	// voting weight is minted to delegatee (bob) when delegation occurs
	if bobVotingWeight == 1_000_000_000 {
		println("[EXPECTED] bob received voting weight from delegation")
	}
}

func undelegateFromBob() {
	undelegateAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(aliceAddr))

	gs.Undelegate(cross, bobAddr, undelegateAmount)

	ufmt.Printf("[INFO] alice undelegated %d GNS from bob\n", undelegateAmount)
}

func checkVotingPowerAfterUndelegation() {
	aliceVotingWeight, _ := gs.GetUserDelegationAmountAtSnapshot(aliceAddr, time.Now().Unix()-votingWeightSmoothingDuration)
	bobVotingWeight, _ := gs.GetUserDelegationAmountAtSnapshot(bobAddr, time.Now().Unix()-votingWeightSmoothingDuration)

	ufmt.Printf("[INFO] alice voting weight after undelegation: %d\n", aliceVotingWeight)
	ufmt.Printf("[INFO] bob voting weight after undelegation: %d\n", bobVotingWeight)

	if bobVotingWeight == 0 {
		println("[EXPECTED] bob voting weight is 0 after undelegation")
	}

	// Alice's GNS is in lockup during undelegation period
	println("[INFO] alice's GNS is locked during undelegation lockup period")
}

// Output:
// [SCENARIO] 1. Transfer GNS to alice for delegation
// [INFO] transferred 2,000,000,000 GNS to alice
//
// [SCENARIO] 2. Check initial voting power (before delegation)
// [INFO] alice voting weight: 0
// [INFO] bob voting weight: 0
//
// [SCENARIO] 3. Alice delegates GNS to Bob
// [INFO] alice delegated 1000000000 GNS to bob
//
// [SCENARIO] 4. Skip voting weight smoothing duration
//
// [SCENARIO] 5. Check voting power after delegation
// [INFO] alice voting weight after delegation: 0
// [INFO] bob voting weight after delegation: 1000000000
// [EXPECTED] bob received voting weight from delegation
//
// [SCENARIO] 6. Alice undelegates from Bob
// [INFO] alice undelegated 1000000000 GNS from bob
//
// [SCENARIO] 7. Skip voting weight smoothing duration for voting power update
//
// [SCENARIO] 8. Check voting power after undelegation
// [INFO] alice voting weight after undelegation: 0
// [INFO] bob voting weight after undelegation: 0
// [EXPECTED] bob voting weight is 0 after undelegation
// [INFO] alice's GNS is locked during undelegation lockup period
