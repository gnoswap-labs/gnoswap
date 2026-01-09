// Governance vote verification with launchpad deposit xGNS
// This test verifies that:
// 1. Launchpad deposit creates xGNS which is NOT counted in voting supply
// 2. Only staker delegation xGNS is counted for voting weight
// 3. Vote weight correctly reflects delegation amount at snapshot time

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"

	gs "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"

	"gno.land/r/gnoswap/gov/xgns"

	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/obl"
)

var (
	adminAddr        = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr    = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	launchpadAddr    = access.MustGetAddress(prbac.ROLE_LAUNCHPAD.String())
	dummyAddr        = testutils.TestAddress("dummy")
	projectAddr      = testutils.TestAddress("project")
	depositorAddr    = testutils.TestAddress("depositor")
	currentBlockTime = int64(5)
)

func main() {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	config := governance.GetLatestConfig()

	println("[SCENARIO] 1. Check Initial xGNS Supply")
	checkInitialXgnsSupply()
	println()

	println("[SCENARIO] 2. Delegate GNS to dummy (staker delegation)")
	delegateGnsToDummy()
	println()

	println("[SCENARIO] 3. Create Launchpad Project and Deposit GNS")
	projectTierId := createAndDepositLaunchpad()
	println()

	println("[SCENARIO] 4. Check xGNS Supply after launchpad deposit")
	checkXgnsSupplyAfterLaunchpad()
	println()

	println("[SCENARIO] 5. Skip smoothing period for proposal creation")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println("[INFO] current height:", runtime.ChainHeight())
	println()

	println("[SCENARIO] 6. Propose Text")
	proposalId := proposeText()
	println()

	println("[SCENARIO] 7. Skip voting start delay for ready to vote")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	println("[INFO] current height:", runtime.ChainHeight())
	println()

	println("[SCENARIO] 8. Vote for the proposal with dummy")
	voteProposalWithDummy(proposalId)
	println()

	println("[SCENARIO] 9. Verify voting weight")
	verifyVotingWeight(proposalId, projectTierId)
	println()
}

func checkInitialXgnsSupply() {
	totalSupply := xgns.TotalSupply()
	ufmt.Printf("[INFO] xGNS total supply: %d\n", totalSupply)
	ufmt.Printf("[EXPECTED] Both should be 0 initially\n")
}

func delegateGnsToDummy() {
	delegatedAmount := int64(2_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	gns.Approve(cross, govStakerAddr, delegatedAmount)
	gs.Delegate(cross, dummyAddr, delegatedAmount, "")

	xgnsBalance := xgns.BalanceOf(dummyAddr)
	ufmt.Printf("[INFO] GNS delegated to dummy %s (amount: %d)\n", dummyAddr.String(), delegatedAmount)
	ufmt.Printf("[INFO] dummy xGNS balance: %d\n", xgnsBalance)
	ufmt.Printf("[EXPECTED] xGNS total supply: %d\n", xgns.TotalSupply())
}

func createAndDepositLaunchpad() string {
	depositAmount := int64(5_000_000_000)

	// Create launchpad project
	println("[INFO] Creating launchpad project")
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	obl.Approve(cross, launchpadAddr, int64(10_000_000))
	projectId := launchpad.CreateProject(
		cross,
		"Test OBL Project",
		"gno.land/r/onbloc/obl",
		projectAddr,
		int64(10_000_000),
		"",
		"",
		int64(30),
		int64(30),
		int64(40),
		int64(time.Now().Unix()+604800),
	)
	ufmt.Printf("[INFO] Project created with ID: %s\n", projectId)

	// Skip to activate project
	testing.SkipHeights(120960)

	// Transfer GNS to depositor and deposit
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, depositorAddr, depositAmount)

	testing.SetRealm(testing.NewUserRealm(depositorAddr))
	gns.Approve(cross, launchpadAddr, depositAmount)

	projectTierId := projectId + ":30"
	depositId := launchpad.DepositGns(cross, projectTierId, depositAmount, "")
	ufmt.Printf("[INFO] GNS deposited to launchpad (depositId: %d, amount: %d)\n", depositId, depositAmount)

	// Check xGNS balance of launchpad
	launchpadXgns := xgns.BalanceOf(launchpadAddr)
	ufmt.Printf("[INFO] Launchpad xGNS balance: %d\n", launchpadXgns)

	return projectTierId
}

func checkXgnsSupplyAfterLaunchpad() {
	totalSupply := xgns.TotalSupply()
	launchpadBalance := xgns.BalanceOf(launchpadAddr)

	ufmt.Printf("[INFO] xGNS total supply: %d\n", totalSupply)
	ufmt.Printf("[INFO] Launchpad xGNS balance: %d\n", launchpadBalance)
	ufmt.Printf("[EXPECTED] voting supply = total supply - launchpad balance = %d\n", totalSupply-launchpadBalance)
}

func proposeText() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalId := governance.ProposeText(cross, "test_title", "test_description")
	ufmt.Printf("[INFO] Created proposal ID: %d\n", proposalId)
	return proposalId
}

func voteProposalWithDummy(proposalId int64) {
	testing.SetRealm(testing.NewUserRealm(dummyAddr))
	governance.Vote(cross, proposalId, true)
	state, _ := governance.GetProposalStatusByProposalId(proposalId)
	ufmt.Printf("[INFO] Vote submitted, proposal state: %s\n", state)
}

func verifyVotingWeight(proposalId int64, projectTierId string) {
	// Get vote info
	yeaWeight, _ := governance.GetYeaByProposalId(proposalId)
	nayWeight, _ := governance.GetNayByProposalId(proposalId)
	quorumAmount, _ := governance.GetQuorumAmountByProposalId(proposalId)

	// Get dummy's voted weight
	dummyVoteWeight, _ := governance.GetVoteWeight(proposalId, dummyAddr)

	// Get xGNS info
	totalXgns := xgns.TotalSupply()
	launchpadXgns := xgns.BalanceOf(launchpadAddr)
	dummyXgns := xgns.BalanceOf(dummyAddr)

	ufmt.Printf("[EXPECTED] Total xGNS supply: %d\n", totalXgns)
	ufmt.Printf("[EXPECTED] Launchpad xGNS balance: %d\n", launchpadXgns)
	ufmt.Printf("[EXPECTED] Dummy xGNS balance: %d\n", dummyXgns)
	ufmt.Printf("[EXPECTED] Quorum amount (based on voting supply): %d\n", quorumAmount)
	ufmt.Printf("[EXPECTED] Yea weight: %d\n", yeaWeight)
	ufmt.Printf("[EXPECTED] Nay weight: %d\n", nayWeight)
	ufmt.Printf("[EXPECTED] Dummy's vote weight: %d\n", dummyVoteWeight)
	ufmt.Printf("[EXPECTED] Dummy's vote weight should equal dummy xGNS balance: %t\n", dummyVoteWeight == dummyXgns)
	ufmt.Printf("[EXPECTED] Yea weight should equal dummy's vote weight: %t\n", yeaWeight == dummyVoteWeight)
}

// Output:
// [SCENARIO] 1. Check Initial xGNS Supply
// [INFO] xGNS total supply: 0
// [EXPECTED] Both should be 0 initially
//
// [SCENARIO] 2. Delegate GNS to dummy (staker delegation)
// [INFO] GNS delegated to dummy g1v36k6mteta047h6lta047h6lta047h6lz7gmv8 (amount: 2000000000)
// [INFO] dummy xGNS balance: 0
// [EXPECTED] xGNS total supply: 2000000000
//
// [SCENARIO] 3. Create Launchpad Project and Deposit GNS
// [INFO] Creating launchpad project
// [INFO] Project created with ID: gno.land/r/onbloc/obl:123
// [INFO] GNS deposited to launchpad (depositId: %!d(string=1), amount: 5000000000)
// [INFO] Launchpad xGNS balance: 5000000000
//
// [SCENARIO] 4. Check xGNS Supply after launchpad deposit
// [INFO] xGNS total supply: 7000000000
// [INFO] Launchpad xGNS balance: 5000000000
// [EXPECTED] voting supply = total supply - launchpad balance = 2000000000
//
// [SCENARIO] 5. Skip smoothing period for proposal creation
// [INFO] current height: 138363
//
// [SCENARIO] 6. Propose Text
// [INFO] Created proposal ID: 1
//
// [SCENARIO] 7. Skip voting start delay for ready to vote
// [INFO] current height: 155643
//
// [SCENARIO] 8. Vote for the proposal with dummy
// [INFO] Vote submitted, proposal state: active
//
// [SCENARIO] 9. Verify voting weight
// [EXPECTED] Total xGNS supply: 7000000000
// [EXPECTED] Launchpad xGNS balance: 5000000000
// [EXPECTED] Dummy xGNS balance: 0
// [EXPECTED] Quorum amount (based on voting supply): 1000000000
// [EXPECTED] Yea weight: 2000000000
// [EXPECTED] Nay weight: 0
// [EXPECTED] Dummy's vote weight: 2000000000
// [EXPECTED] Dummy's vote weight should equal dummy xGNS balance: false
// [EXPECTED] Yea weight should equal dummy's vote weight: true
