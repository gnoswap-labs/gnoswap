// governance proposal multi execute

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"

	"gno.land/r/gnoswap/v1/gov/governance"
	gs "gno.land/r/gnoswap/v1/gov/staker"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr, _     = access.GetAddress(prbac.ROLE_ADMIN.String())
	currentBlockTime = int64(2)
)

func main() {
	config := governance.GetLatestConfig()

	println("[SCENARIO] 1. Delegate gns to admin")
	delegateGnsToAdmin()
	println()

	println("[SCENARIO] 2. Skip vote weight smoothing duration for create proposal")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println("[INFO] current height:", runtime.ChainHeight())
	println()

	println("[SCENARIO] 3. Propose Multi Execute (SetPoolCreationFee + CommunityPoolSpend)")
	proposalID := proposeMultiExecute()
	println()

	println("[SCENARIO] 4. Skip voting start delay for ready to vote")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	println("[INFO] current height:", runtime.ChainHeight())
	println()

	println("[SCENARIO] 5. Vote for the proposal")
	voteProposal(proposalID)
	println()

	println("[SCENARIO] 6. Skip voting period and execution delay for ready to execute")
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)
	testing.SkipHeights(int64(config.ExecutionDelay) / currentBlockTime)
	println("[INFO] current height:", runtime.ChainHeight())
	println()

	println("[SCENARIO] 7. Execute Multi Proposal")
	executeMultiProposal(proposalID)
	println()
}

// [SCENARIO] 1. Delegate gns to admin
func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	govStakerAddr := address("g17e3ykyqk9jmqe2y9wxe9zhep3p7cw56davjqwa")
	gns.Approve(cross, govStakerAddr, delegatedAmount)
	gs.Delegate(cross, adminAddr, int64(delegatedAmount), "")

	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

// [SCENARIO] 2. Propose Multi Execute
func proposeMultiExecute() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalID := governance.ProposeParameterChange(
		cross,
		"test_title",
		"test_description",
		int64(2),
		"gno.land/r/gnoswap/pool*EXE*SetPoolCreationFee*EXE*1000*GOV*gno.land/r/gnoswap/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/gns,g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d,905",
	)
	ufmt.Printf("[INFO] Multi Execute Proposal ID: %d\n", proposalID)
	return proposalID
}

// [SCENARIO] 3. Vote for the proposal
func voteProposal(proposalID int64) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	prevYea := governance.GetYeaByProposalId(proposalID)
	prevNay := governance.GetNayByProposalId(proposalID)

	governance.Vote(cross, proposalID, true)

	afterYea := governance.GetYeaByProposalId(proposalID)
	afterNay := governance.GetNayByProposalId(proposalID)

	ufmt.Printf("[EXPECTED] before voting - yea: %d, nay: %d\n", prevYea, prevNay)
	ufmt.Printf("[EXPECTED] after voting - yea: %d, nay: %d\n", afterYea, afterNay)
}

// [SCENARIO] 4. Execute Multi Proposal
func executeMultiProposal(proposalID int64) {
	communityPoolAddr := address("g13lpjmjhl2du7whed3wxe4n5508txxja6ezxeg7")

	prevBlockTime := currentBlockTime
	prevCommunityPool := gns.BalanceOf(communityPoolAddr)
	governance.Execute(cross, proposalID)

	afterBlockTime := currentBlockTime
	afterCommunityPool := gns.BalanceOf(communityPoolAddr)
	ufmt.Printf("[EXPECTED] before executing - block time: %d, community pool: %d\n", prevBlockTime, prevCommunityPool)
	ufmt.Printf("[EXPECTED] after executing - block time: %d, community pool: %d\n", afterBlockTime, afterCommunityPool)

	state := governance.GetExecutionStateByProposalId(proposalID)
	ufmt.Printf("[EXPECTED] proposal executed: %v\n", state)
}

// Output:
// [SCENARIO] 1. Delegate gns to admin
// [INFO] gns delegated to g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d (amount: 1000000000)
//
// [SCENARIO] 2. Skip vote weight smoothing duration for create proposal
// [INFO] current height: 43323
//
// [SCENARIO] 3. Propose Multi Execute (SetPoolCreationFee + CommunityPoolSpend)
// [INFO] Multi Execute Proposal ID: 1
//
// [SCENARIO] 4. Skip voting start delay for ready to vote
// [INFO] current height: 86523
//
// [SCENARIO] 5. Vote for the proposal
// [EXPECTED] before voting - yea: 0, nay: 0
// [EXPECTED] after voting - yea: 1000000000, nay: 0
//
// [SCENARIO] 6. Skip voting period and execution delay for ready to execute
// [INFO] current height: 432123
//
// [SCENARIO] 7. Execute Multi Proposal
// [EXPECTED] before executing - block time: 2, community pool: 154109584800
// [EXPECTED] after executing - block time: 2, community pool: 770547923095
// [EXPECTED] proposal executed: executed
