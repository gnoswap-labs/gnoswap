// governance proposal multi execute

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
	gns "gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/governance"
	gs "gno.land/r/gnoswap/v1/gov/staker"
)

var (
	adminAddr, _     = access.GetAddress(access.ROLE_ADMIN)
	currentBlockTime = int64(2)
)

func main() {
	config := governance.GetLatestConfig()

	println("[SCENARIO] 1. Delegate gns to admin")
	delegateGnsToAdmin()
	println()

	println("[SCENARIO] 2. Skip vote weight smoothing duration for create proposal")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 3. Propose Multi Execute (SetAvgBlockTimeInMs + CommunityPoolSpend)")
	proposalID := proposeMultiExecute()
	println()

	println("[SCENARIO] 4. Skip voting start delay for ready to vote")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 5. Vote for the proposal")
	voteProposal(proposalID)
	println()

	println("[SCENARIO] 6. Skip voting period and execution delay for ready to execute")
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)
	testing.SkipHeights(int64(config.ExecutionDelay) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 7. Execute Multi Proposal")
	executeMultiProposal(proposalID)
	println()
}

// [SCENARIO] 1. Delegate gns to admin
func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(std.NewUserRealm(adminAddr))

	gns.Approve(cross, consts.GOV_STAKER_ADDR, delegatedAmount)
	gs.Delegate(cross, adminAddr, uint64(delegatedAmount), "")

	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

// [SCENARIO] 2. Propose Multi Execute
func proposeMultiExecute() uint64 {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	proposalID := governance.ProposeParameterChange(
		cross,
		"test_title",
		"test_description",
		uint64(2),
		"gno.land/r/gnoswap/v1/gns*EXE*SetAvgBlockTimeInMs*EXE*123*GOV*gno.land/r/gnoswap/v1/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/v1/gns,g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d,905",
	)
	ufmt.Printf("[INFO] Multi Execute Proposal ID: %d\n", proposalID)
	return proposalID
}

// [SCENARIO] 3. Vote for the proposal
func voteProposal(proposalID uint64) {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	prevYea := governance.GetYeaByProposalId(proposalID)
	prevNay := governance.GetNayByProposalId(proposalID)

	governance.Vote(cross, proposalID, true)

	afterYea := governance.GetYeaByProposalId(proposalID)
	afterNay := governance.GetNayByProposalId(proposalID)

	ufmt.Printf("[EXPECTED] before voting - yea: %s, nay: %s\n", prevYea, prevNay)
	ufmt.Printf("[EXPECTED] after voting - yea: %s, nay: %s\n", afterYea, afterNay)
}

// [SCENARIO] 4. Execute Multi Proposal
func executeMultiProposal(proposalID uint64) {
	prevBlockTime := gns.GetAvgBlockTimeInMs()
	prevCommunityPool := gns.BalanceOf(consts.COMMUNITY_POOL_ADDR)
	err := governance.Execute(cross, proposalID)
	if err != nil {
		ufmt.Printf("[INFO] execute error: %v\n", err)
	}
	afterBlockTime := gns.GetAvgBlockTimeInMs()
	afterCommunityPool := gns.BalanceOf(consts.COMMUNITY_POOL_ADDR)
	ufmt.Printf("[EXPECTED] before executing - block time: %d, community pool: %d\n", prevBlockTime, prevCommunityPool)
	ufmt.Printf("[EXPECTED] after executing - block time: %d, community pool: %d\n", afterBlockTime, afterCommunityPool)
	state := governance.GetExecutionStateByProposalId(proposalID)
	ufmt.Printf("[EXPECTED] proposal executed: %v\n", state.Executed)
}

// Output:
// [SCENARIO] 1. Delegate gns to admin
// [INFO] gns delegated to g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d (amount: 1000000000)
//
// [SCENARIO] 2. Skip vote weight smoothing duration for create proposal
// [INFO] current height: 43323
//
// [SCENARIO] 3. Propose Multi Execute (SetAvgBlockTimeInMs + CommunityPoolSpend)
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
// [EXPECTED] before executing - block time: 2000, community pool: 61643833920
// [EXPECTED] after executing - block time: 123, community pool: 308219168695
// [EXPECTED] proposal executed: true
