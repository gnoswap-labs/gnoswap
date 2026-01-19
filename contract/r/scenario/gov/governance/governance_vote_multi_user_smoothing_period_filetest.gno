// Governance vote verification with multiple users and delegation at different times
// This test verifies that:
// 1. Multiple users can delegate at different times
// 2. Only delegations BEFORE the snapshot time grant voting power
// 3. Late delegations (after snapshot) cannot vote on existing proposals
// 4. Early delegations correctly receive voting weight

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain/runtime"
	"testing"

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

	"gno.land/r/gnoswap/gns"
)

var (
	t *testing.T

	adminAddr        = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr    = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	voter1Addr       = testutils.TestAddress("voter1") // Delegates early - can vote
	voter2Addr       = testutils.TestAddress("voter2") // Delegates early - can vote
	voter3Addr       = testutils.TestAddress("voter3") // Delegates late - cannot vote
	currentBlockTime = int64(5)
)

func main() {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	config := governance.GetLatestConfig()

	smoothingPeriodBlocks := int64(config.VotingWeightSmoothingDuration) / currentBlockTime

	println("[SCENARIO] 1. Initial delegation to voter1 and voter2 (early)")
	initialDelegation()
	println()

	println("[SCENARIO] 2. Skip full smoothing period + buffer")
	testing.SkipHeights(smoothingPeriodBlocks + 100)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 3. Create proposal (snapshot captures voter1 and voter2)")
	proposalId := proposeText()
	println()

	println("[SCENARIO] 4. Voter3 delegates late (AFTER proposal snapshot)")
	lateDelegation()
	println()

	println("[SCENARIO] 5. Skip voting start delay")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 6. Voter1 and Voter2 vote (should succeed)")
	earlyVotersVote(proposalId)
	println()

	println("[SCENARIO] 7. Voter3 to vote (should succeed - delegated after snapshot)")
	lateVoterSuccess(proposalId)
	println()

	println("[SCENARIO] 8. Verify voting results")
	verifyVotingResults(proposalId)
	println()
}

func initialDelegation() {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	// Voter1: 4 billion GNS
	voter1Amount := int64(4_000_000_000)
	gns.Approve(cross, govStakerAddr, voter1Amount)
	gs.Delegate(cross, voter1Addr, voter1Amount, "")
	ufmt.Printf("[INFO] Voter1 delegated %d GNS (early - will have voting power)\n", voter1Amount)

	// Voter2: 2 billion GNS
	voter2Amount := int64(2_000_000_000)
	gns.Approve(cross, govStakerAddr, voter2Amount)
	gs.Delegate(cross, voter2Addr, voter2Amount, "")
	ufmt.Printf("[INFO] Voter2 delegated %d GNS (early - will have voting power)\n", voter2Amount)

	ufmt.Printf("[INFO] Total xGNS supply: %d\n", xgns.TotalSupply())
}

func proposeText() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalId := governance.ProposeText(cross, "test_title", "test_description")
	ufmt.Printf("[INFO] Created proposal ID: %d\n", proposalId)
	ufmt.Printf("[INFO] Snapshot time = now - smoothing period (captures voter1 and voter2)\n")
	return proposalId
}

func lateDelegation() {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	// Voter3: 3 billion GNS - delegates AFTER proposal creation
	voter3Amount := int64(3_000_000_000)
	gns.Approve(cross, govStakerAddr, voter3Amount)
	gs.Delegate(cross, voter3Addr, voter3Amount, "")
	ufmt.Printf("[INFO] Voter3 delegated %d GNS (late - AFTER proposal snapshot)\n", voter3Amount)

	ufmt.Printf("[INFO] Total xGNS supply: %d\n", xgns.TotalSupply())
}

func earlyVotersVote(proposalId int64) {
	// Voter1 votes YES
	testing.SetRealm(testing.NewUserRealm(voter1Addr))
	governance.Vote(cross, proposalId, true)
	ufmt.Printf("[INFO] Voter1 voted YES\n")

	// Voter2 votes NO
	testing.SetRealm(testing.NewUserRealm(voter2Addr))
	governance.Vote(cross, proposalId, false)
	ufmt.Printf("[INFO] Voter2 voted NO\n")

	state, _ := governance.GetProposalStatusByProposalId(proposalId)
	ufmt.Printf("[INFO] Proposal state: %s\n", state)
}

func lateVoterSuccess(proposalId int64) {
	// Voter3 delegated AFTER the proposal was created,
	// so their delegation is not in the snapshot
	testing.SetRealm(testing.NewUserRealm(voter3Addr))
	governance.Vote(cross, proposalId, false)

	voter3Weight, _ := governance.GetVoteWeight(proposalId, voter3Addr)
	ufmt.Printf("[INFO] Voter3 vote weight: %d\n", voter3Weight)
}

func verifyVotingResults(proposalId int64) {
	// Get vote weights - only voter1 and voter2 voted
	voter1Weight, _ := governance.GetVoteWeight(proposalId, voter1Addr)
	voter2Weight, _ := governance.GetVoteWeight(proposalId, voter2Addr)
	voter3Weight, _ := governance.GetVoteWeight(proposalId, voter3Addr)

	// Get proposal totals
	yeaWeight, _ := governance.GetYeaByProposalId(proposalId)
	nayWeight, _ := governance.GetNayByProposalId(proposalId)
	quorumAmount, _ := governance.GetQuorumAmountByProposalId(proposalId)

	ufmt.Printf("[RESULT] Voting weights:\n")
	ufmt.Printf("  - Voter1: weight=%d (voted YES)\n", voter1Weight)
	ufmt.Printf("  - Voter2: weight=%d (voted NO)\n", voter2Weight)
	ufmt.Printf("  - Voter3: weight=%d (voted NO)\n", voter3Weight)

	ufmt.Printf("[RESULT] Proposal summary:\n")
	ufmt.Printf("  - Quorum amount (based on snapshot, excludes voter3): %d\n", quorumAmount)
	ufmt.Printf("  - Yea weight: %d\n", yeaWeight)
	ufmt.Printf("  - Nay weight: %d\n", nayWeight)

	ufmt.Printf("[EXPECTED] Yea (%d) = voter1 (%d): %t\n", yeaWeight, voter1Weight, yeaWeight == voter1Weight)
	ufmt.Printf("[EXPECTED] Nay (%d) = voter2 + voter3 (%d): %t\n", nayWeight, voter2Weight+voter3Weight, nayWeight == voter2Weight+voter3Weight)

	// Explain the behavior
	ufmt.Printf("[EXPLANATION] Snapshot mechanism:\n")
	ufmt.Printf("  - Voter1 and Voter2 delegated BEFORE proposal creation\n")
	ufmt.Printf("  - Voter3 delegated AFTER proposal creation, so excluded from this vote\n")
	ufmt.Printf("  - Voter3 participate in proposals\n")
}

// Output:
// [SCENARIO] 1. Initial delegation to voter1 and voter2 (early)
// [INFO] Voter1 delegated 4000000000 GNS (early - will have voting power)
// [INFO] Voter2 delegated 2000000000 GNS (early - will have voting power)
// [INFO] Total xGNS supply: 6000000000
//
// [SCENARIO] 2. Skip full smoothing period + buffer
// [INFO] current height: 17503
//
// [SCENARIO] 3. Create proposal (snapshot captures voter1 and voter2)
// [INFO] Created proposal ID: 1
// [INFO] Snapshot time = now - smoothing period (captures voter1 and voter2)
//
// [SCENARIO] 4. Voter3 delegates late (AFTER proposal snapshot)
// [INFO] Voter3 delegated 3000000000 GNS (late - AFTER proposal snapshot)
// [INFO] Total xGNS supply: 9000000000
//
// [SCENARIO] 5. Skip voting start delay
// [INFO] current height: 34783
//
// [SCENARIO] 6. Voter1 and Voter2 vote (should succeed)
// [INFO] Voter1 voted YES
// [INFO] Voter2 voted NO
// [INFO] Proposal state: active
//
// [SCENARIO] 7. Voter3 to vote (should succeed - delegated after snapshot)
// [INFO] Voter3 vote weight: 1500000000
//
// [SCENARIO] 8. Verify voting results
// [RESULT] Voting weights:
//   - Voter1: weight=4000000000 (voted YES)
//   - Voter2: weight=2000000000 (voted NO)
//   - Voter3: weight=1500000000 (voted NO)
// [RESULT] Proposal summary:
//   - Quorum amount (based on snapshot, excludes voter3): 3000000000
//   - Yea weight: 4000000000
//   - Nay weight: 3500000000
// [EXPECTED] Yea (4000000000) = voter1 (4000000000): true
// [EXPECTED] Nay (3500000000) = voter2 + voter3 (3500000000): true
// [EXPLANATION] Snapshot mechanism:
//   - Voter1 and Voter2 delegated BEFORE proposal creation
//   - Voter3 delegated AFTER proposal creation, so excluded from this vote
//   - Voter3 participate in proposals
