// Governance vote verification with delegation changes during smoothing period
// This test verifies that:
// 1. Delegation within smoothing period does NOT grant voting power for current proposals
// 2. Only delegations made BEFORE the snapshot time are counted
// 3. Snapshot time = proposal creation time - smoothing period
// 4. Late delegations (mid-period) cannot vote on proposals created after the full period

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
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
	voter1Addr       = testutils.TestAddress("voter1")
	voter2Addr       = testutils.TestAddress("voter2")
	currentBlockTime = int64(5)
)

func main() {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	config := governance.GetLatestConfig()

	// Calculate timing for delegation changes within smoothing period
	smoothingPeriodBlocks := int64(config.VotingWeightSmoothingDuration) / currentBlockTime
	halfSmoothingBlocks := smoothingPeriodBlocks / 2

	println("[SCENARIO] 1. Initial delegation to voter1")
	initialDelegation()
	println()

	println("[SCENARIO] 2. Skip half of smoothing period")
	testing.SkipHeights(halfSmoothingBlocks)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 3. Additional delegation to voter2 (mid-period)")
	midPeriodDelegation()
	println()

	println("[SCENARIO] 4. Skip remaining smoothing period")
	testing.SkipHeights(halfSmoothingBlocks + 100)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 5. Check current xGNS balances")
	checkCurrentXgnsBalance()
	println()

	println("[SCENARIO] 6. Propose Text (snapshot taken at this time)")
	proposalId := proposeText()
	println()

	println("[SCENARIO] 7. Skip voting start delay")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 8. Both voters vote (voter1: yes, voter2: no)")
	voteProposals(proposalId)
	println()

	println("[SCENARIO] 9. Verify voting weights")
	verifyVotingWeight(proposalId)
	println()
}

func initialDelegation() {
	initialAmount := int64(3_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	gns.Approve(cross, govStakerAddr, initialAmount)
	gs.Delegate(cross, voter1Addr, initialAmount, "")

	voter1Xgns := xgns.BalanceOf(voter1Addr)
	totalXgns := xgns.TotalSupply()

	ufmt.Printf("[INFO] Delegated %d GNS to voter1\n", initialAmount)
	ufmt.Printf("[INFO] Voter1 xGNS balance: %d\n", voter1Xgns)
	ufmt.Printf("[INFO] Total xGNS supply: %d\n", totalXgns)
}

func midPeriodDelegation() {
	additionalAmount := int64(2_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	gns.Approve(cross, govStakerAddr, additionalAmount)
	gs.Delegate(cross, voter2Addr, additionalAmount, "")

	voter2Xgns := xgns.BalanceOf(voter2Addr)
	totalXgns := xgns.TotalSupply()

	ufmt.Printf("[INFO] Delegated %d GNS to voter2 (mid-period)\n", additionalAmount)
	ufmt.Printf("[INFO] Voter2 xGNS balance: %d\n", voter2Xgns)
	ufmt.Printf("[INFO] Total xGNS supply: %d\n", totalXgns)
}

func checkCurrentXgnsBalance() {
	voter1Xgns := xgns.BalanceOf(voter1Addr)
	voter2Xgns := xgns.BalanceOf(voter2Addr)
	totalXgns := xgns.TotalSupply()

	ufmt.Printf("[INFO] Voter1 xGNS balance: %d\n", voter1Xgns)
	ufmt.Printf("[INFO] Voter2 xGNS balance: %d\n", voter2Xgns)
	ufmt.Printf("[INFO] Total xGNS supply: %d\n", totalXgns)
}

func proposeText() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalId := governance.ProposeText(cross, "test_title", "test_description")
	ufmt.Printf("[INFO] Created proposal ID: %d\n", proposalId)
	ufmt.Printf("[INFO] Snapshot captures current delegation state\n")
	return proposalId
}

func voteProposals(proposalId int64) {
	// Voter1 votes YES
	testing.SetRealm(testing.NewUserRealm(voter1Addr))
	governance.Vote(cross, proposalId, true)
	ufmt.Printf("[INFO] Voter1 voted YES\n")

	// Voter2 tries to vote NO - should fail due to no voting power
	uassert.AbortsContains(t, "[GNOSWAP-GOVERNANCE-007] not enough voting power", func() {
		testing.SetRealm(testing.NewUserRealm(voter2Addr))
		governance.Vote(cross, proposalId, false)
	})
	ufmt.Printf("[INFO] Voter2 cannot vote - delegated AFTER proposal snapshot time\n")

	state, _ := governance.GetProposalStatusByProposalId(proposalId)
	ufmt.Printf("[INFO] Proposal state: %s\n", state)
}

func verifyVotingWeight(proposalId int64) {
	// Get vote weights
	voter1Weight, _ := governance.GetVoteWeight(proposalId, voter1Addr)

	// Voter2 should have no voting info since they delegated after snapshot time
	_, err := governance.GetVoteWeight(proposalId, voter2Addr)
	uassert.Error(t, err, "voter2 should have no voting weight")
	voter2Weight := int64(0)
	ufmt.Printf("[INFO] Voter2 cannot vote - delegated AFTER proposal snapshot time\n")

	// Get proposal totals
	yeaWeight, _ := governance.GetYeaByProposalId(proposalId)
	nayWeight, _ := governance.GetNayByProposalId(proposalId)
	quorumAmount, _ := governance.GetQuorumAmountByProposalId(proposalId)

	// Get xGNS balances
	voter1Xgns := xgns.BalanceOf(voter1Addr)
	voter2Xgns := xgns.BalanceOf(voter2Addr)

	ufmt.Printf("[EXPECTED] Voter1: vote weight=%d, xGNS=%d, match=%t\n",
		voter1Weight, voter1Xgns, voter1Weight == voter1Xgns)
	ufmt.Printf("[EXPECTED] Voter2: vote weight=%d, xGNS=%d, match=%t\n",
		voter2Weight, voter2Xgns, voter2Weight == voter2Xgns)
	ufmt.Printf("[EXPECTED] Quorum amount: %d\n", quorumAmount)
	ufmt.Printf("[EXPECTED] Yea weight: %d (voter1)\n", yeaWeight)
	ufmt.Printf("[EXPECTED] Nay weight: %d (voter2)\n", nayWeight)
}

// Output:
// [SCENARIO] 1. Initial delegation to voter1
// [INFO] Delegated 3000000000 GNS to voter1
// [INFO] Voter1 xGNS balance: 0
// [INFO] Total xGNS supply: 3000000000
//
// [SCENARIO] 2. Skip half of smoothing period
// [INFO] current height: 8763
//
// [SCENARIO] 3. Additional delegation to voter2 (mid-period)
// [INFO] Delegated 2000000000 GNS to voter2 (mid-period)
// [INFO] Voter2 xGNS balance: 0
// [INFO] Total xGNS supply: 5000000000
//
// [SCENARIO] 4. Skip remaining smoothing period
// [INFO] current height: 17503
//
// [SCENARIO] 5. Check current xGNS balances
// [INFO] Voter1 xGNS balance: 0
// [INFO] Voter2 xGNS balance: 0
// [INFO] Total xGNS supply: 5000000000
//
// [SCENARIO] 6. Propose Text (snapshot taken at this time)
// [INFO] Created proposal ID: 1
// [INFO] Snapshot captures current delegation state
//
// [SCENARIO] 7. Skip voting start delay
// [INFO] current height: 34783
//
// [SCENARIO] 8. Both voters vote (voter1: yes, voter2: no)
// [INFO] Voter1 voted YES
// [INFO] Voter2 cannot vote - delegated AFTER proposal snapshot time
// [INFO] Proposal state: active
//
// [SCENARIO] 9. Verify voting weights
// [INFO] Voter2 cannot vote - delegated AFTER proposal snapshot time
// [EXPECTED] Voter1: vote weight=3000000000, xGNS=0, match=false
// [EXPECTED] Voter2: vote weight=0, xGNS=0, match=true
// [EXPECTED] Quorum amount: 1500000000
// [EXPECTED] Yea weight: 3000000000 (voter1)
// [EXPECTED] Nay weight: 0 (voter2)
