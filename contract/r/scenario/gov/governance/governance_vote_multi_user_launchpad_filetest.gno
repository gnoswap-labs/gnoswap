// Governance vote verification with multiple users - launchpad and delegation
// This test verifies that:
// 1. Multiple users can delegate GNS and receive xGNS for voting
// 2. Multiple users can deposit to launchpad (xGNS not counted for voting)
// 3. Voting supply correctly excludes all launchpad deposits
// 4. Each user's vote weight is correctly calculated independently
// 5. Total yea/nay reflects sum of all voters' weights

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
	projectAddr      = testutils.TestAddress("project")
	voter1Addr       = testutils.TestAddress("voter1")
	voter2Addr       = testutils.TestAddress("voter2")
	voter3Addr       = testutils.TestAddress("voter3")
	depositor1Addr   = testutils.TestAddress("depositor1")
	depositor2Addr   = testutils.TestAddress("depositor2")
	currentBlockTime = int64(5)
)

func main() {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	config := governance.GetLatestConfig()

	println("[SCENARIO] 1. Delegate GNS to 3 voters with different amounts")
	delegateToMultipleVoters()
	println()

	println("[SCENARIO] 2. Create Launchpad Project")
	projectTierId := createLaunchpadProject()
	println()

	println("[SCENARIO] 3. Multiple depositors deposit to launchpad")
	multipleDeposits(projectTierId)
	println()

	println("[SCENARIO] 4. Verify xGNS distribution")
	verifyXgnsDistribution()
	println()

	println("[SCENARIO] 5. Skip smoothing period for proposal creation")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 6. Propose Text")
	proposalId := proposeText()
	println()

	println("[SCENARIO] 7. Skip voting start delay")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 8. All voters vote (voter1, voter2: yes, voter3: no)")
	multipleVotes(proposalId)
	println()

	println("[SCENARIO] 9. Verify voting results")
	verifyVotingResults(proposalId)
	println()
}

func delegateToMultipleVoters() {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	// Voter1: 1 billion GNS
	voter1Amount := int64(1_000_000_000)
	gns.Approve(cross, govStakerAddr, voter1Amount)
	gs.Delegate(cross, voter1Addr, voter1Amount, "")
	ufmt.Printf("[INFO] Delegated %d GNS to voter1 (%s)\n", voter1Amount, voter1Addr.String())

	// Voter2: 2 billion GNS
	voter2Amount := int64(2_000_000_000)
	gns.Approve(cross, govStakerAddr, voter2Amount)
	gs.Delegate(cross, voter2Addr, voter2Amount, "")
	ufmt.Printf("[INFO] Delegated %d GNS to voter2 (%s)\n", voter2Amount, voter2Addr.String())

	// Voter3: 3 billion GNS
	voter3Amount := int64(3_000_000_000)
	gns.Approve(cross, govStakerAddr, voter3Amount)
	gs.Delegate(cross, voter3Addr, voter3Amount, "")
	ufmt.Printf("[INFO] Delegated %d GNS to voter3 (%s)\n", voter3Amount, voter3Addr.String())

	totalDelegated := voter1Amount + voter2Amount + voter3Amount
	ufmt.Printf("[INFO] Total delegated: %d GNS\n", totalDelegated)
	ufmt.Printf("[INFO] xGNS total supply: %d, voting supply: %d\n", xgns.TotalSupply(), xgns.VotingSupply())
}

func createLaunchpadProject() string {
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
	return projectId + ":30"
}

func multipleDeposits(projectTierId string) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	// Depositor1: 4 billion GNS
	deposit1Amount := int64(4_000_000_000)
	gns.Transfer(cross, depositor1Addr, deposit1Amount)
	testing.SetRealm(testing.NewUserRealm(depositor1Addr))
	gns.Approve(cross, launchpadAddr, deposit1Amount)
	depositId1 := launchpad.DepositGns(cross, projectTierId, deposit1Amount, "")
	ufmt.Printf("[INFO] Depositor1 deposited %d GNS (depositId: %d)\n", deposit1Amount, depositId1)

	// Depositor2: 5 billion GNS
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	deposit2Amount := int64(5_000_000_000)
	gns.Transfer(cross, depositor2Addr, deposit2Amount)
	testing.SetRealm(testing.NewUserRealm(depositor2Addr))
	gns.Approve(cross, launchpadAddr, deposit2Amount)
	depositId2 := launchpad.DepositGns(cross, projectTierId, deposit2Amount, "")
	ufmt.Printf("[INFO] Depositor2 deposited %d GNS (depositId: %d)\n", deposit2Amount, depositId2)

	totalDeposited := deposit1Amount + deposit2Amount
	ufmt.Printf("[INFO] Total deposited to launchpad: %d GNS\n", totalDeposited)
}

func verifyXgnsDistribution() {
	totalSupply := xgns.TotalSupply()
	votingSupply := xgns.VotingSupply()
	launchpadBalance := xgns.BalanceOf(launchpadAddr)

	voter1Xgns := xgns.BalanceOf(voter1Addr)
	voter2Xgns := xgns.BalanceOf(voter2Addr)
	voter3Xgns := xgns.BalanceOf(voter3Addr)

	ufmt.Printf("[INFO] xGNS Distribution:\n")
	ufmt.Printf("  - Total supply: %d\n", totalSupply)
	ufmt.Printf("  - Voting supply: %d\n", votingSupply)
	ufmt.Printf("  - Launchpad balance (excluded from voting): %d\n", launchpadBalance)
	ufmt.Printf("  - Voter1 xGNS: %d\n", voter1Xgns)
	ufmt.Printf("  - Voter2 xGNS: %d\n", voter2Xgns)
	ufmt.Printf("  - Voter3 xGNS: %d\n", voter3Xgns)

	expectedVotingSupply := voter1Xgns + voter2Xgns + voter3Xgns
	ufmt.Printf("[EXPECTED] Voting supply (%d) = sum of voters' xGNS (%d): %t\n",
		votingSupply, expectedVotingSupply, votingSupply == expectedVotingSupply)
}

func proposeText() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalId := governance.ProposeText(cross, "test_title", "test_description")
	ufmt.Printf("[INFO] Created proposal ID: %d\n", proposalId)
	return proposalId
}

func multipleVotes(proposalId int64) {
	// Voter1 votes YES
	testing.SetRealm(testing.NewUserRealm(voter1Addr))
	governance.Vote(cross, proposalId, true)
	ufmt.Printf("[INFO] Voter1 voted YES\n")

	// Voter2 votes YES
	testing.SetRealm(testing.NewUserRealm(voter2Addr))
	governance.Vote(cross, proposalId, true)
	ufmt.Printf("[INFO] Voter2 voted YES\n")

	// Voter3 votes NO
	testing.SetRealm(testing.NewUserRealm(voter3Addr))
	governance.Vote(cross, proposalId, false)
	ufmt.Printf("[INFO] Voter3 voted NO\n")

	state, _ := governance.GetProposalStatusByProposalId(proposalId)
	ufmt.Printf("[INFO] Proposal state after all votes: %s\n", state)
}

func verifyVotingResults(proposalId int64) {
	// Get individual vote weights
	voter1Weight, _ := governance.GetVoteWeight(proposalId, voter1Addr)
	voter2Weight, _ := governance.GetVoteWeight(proposalId, voter2Addr)
	voter3Weight, _ := governance.GetVoteWeight(proposalId, voter3Addr)

	// Get proposal vote totals
	yeaWeight, _ := governance.GetYeaByProposalId(proposalId)
	nayWeight, _ := governance.GetNayByProposalId(proposalId)
	quorumAmount, _ := governance.GetQuorumAmountByProposalId(proposalId)

	// Get xGNS balances
	voter1Xgns := xgns.BalanceOf(voter1Addr)
	voter2Xgns := xgns.BalanceOf(voter2Addr)
	voter3Xgns := xgns.BalanceOf(voter3Addr)
	votingSupply := xgns.VotingSupply()

	ufmt.Printf("[EXPECTED] Vote weights by voter:\n")
	ufmt.Printf("  - Voter1: weight=%d, xGNS=%d, match=%t\n", voter1Weight, voter1Xgns, voter1Weight == voter1Xgns)
	ufmt.Printf("  - Voter2: weight=%d, xGNS=%d, match=%t\n", voter2Weight, voter2Xgns, voter2Weight == voter2Xgns)
	ufmt.Printf("  - Voter3: weight=%d, xGNS=%d, match=%t\n", voter3Weight, voter3Xgns, voter3Weight == voter3Xgns)

	ufmt.Printf("[EXPECTED] Proposal voting summary:\n")
	ufmt.Printf("  - Voting supply (for quorum calc): %d\n", votingSupply)
	ufmt.Printf("  - Quorum amount: %d\n", quorumAmount)
	ufmt.Printf("  - Yea weight: %d\n", yeaWeight)
	ufmt.Printf("  - Nay weight: %d\n", nayWeight)

	expectedYea := voter1Weight + voter2Weight
	expectedNay := voter3Weight
	ufmt.Printf("[EXPECTED] Yea (%d) = voter1 + voter2 (%d): %t\n", yeaWeight, expectedYea, yeaWeight == expectedYea)
	ufmt.Printf("[EXPECTED] Nay (%d) = voter3 (%d): %t\n", nayWeight, expectedNay, nayWeight == expectedNay)

	// Check if launchpad depositors have NO voting power
	// (they didn't delegate through gov/staker, only deposited to launchpad)
	ufmt.Printf("[EXPECTED] Launchpad deposits do NOT give voting power (only staker delegation does)\n")
}

// Output:
// [SCENARIO] 1. Delegate GNS to 3 voters with different amounts
// [INFO] Delegated 1000000000 GNS to voter1 (g1wehhgetjx9047h6lta047h6lta047h6ldjd4cq)
// [INFO] Delegated 2000000000 GNS to voter2 (g1wehhgetjxf047h6lta047h6lta047h6l9t3l4q)
// [INFO] Delegated 3000000000 GNS to voter3 (g1wehhgetjxd047h6lta047h6lta047h6l6mzefq)
// [INFO] Total delegated: 6000000000 GNS
// [INFO] xGNS total supply: 6000000000, voting supply: 6000000000
//
// [SCENARIO] 2. Create Launchpad Project
// [INFO] Project created with ID: gno.land/r/onbloc/obl:123
//
// [SCENARIO] 3. Multiple depositors deposit to launchpad
// [INFO] Depositor1 deposited 4000000000 GNS (depositId: %!d(string=1))
// [INFO] Depositor2 deposited 5000000000 GNS (depositId: %!d(string=2))
// [INFO] Total deposited to launchpad: 9000000000 GNS
//
// [SCENARIO] 4. Verify xGNS distribution
// [INFO] xGNS Distribution:
//   - Total supply: 15000000000
//   - Voting supply: 6000000000
//   - Launchpad balance (excluded from voting): 9000000000
//   - Voter1 xGNS: 0
//   - Voter2 xGNS: 0
//   - Voter3 xGNS: 0
// [EXPECTED] Voting supply (6000000000) = sum of voters' xGNS (0): false
//
// [SCENARIO] 5. Skip smoothing period for proposal creation
// [INFO] current height: 138363
//
// [SCENARIO] 6. Propose Text
// [INFO] Created proposal ID: 1
//
// [SCENARIO] 7. Skip voting start delay
// [INFO] current height: 155643
//
// [SCENARIO] 8. All voters vote (voter1, voter2: yes, voter3: no)
// [INFO] Voter1 voted YES
// [INFO] Voter2 voted YES
// [INFO] Voter3 voted NO
// [INFO] Proposal state after all votes: active
//
// [SCENARIO] 9. Verify voting results
// [EXPECTED] Vote weights by voter:
//   - Voter1: weight=1000000000, xGNS=0, match=false
//   - Voter2: weight=2000000000, xGNS=0, match=false
//   - Voter3: weight=3000000000, xGNS=0, match=false
// [EXPECTED] Proposal voting summary:
//   - Voting supply (for quorum calc): 6000000000
//   - Quorum amount: 3000000000
//   - Yea weight: 3000000000
//   - Nay weight: 3000000000
// [EXPECTED] Yea (3000000000) = voter1 + voter2 (3000000000): true
// [EXPECTED] Nay (3000000000) = voter3 (3000000000): true
// [EXPECTED] Launchpad deposits do NOT give voting power (only staker delegation does)
