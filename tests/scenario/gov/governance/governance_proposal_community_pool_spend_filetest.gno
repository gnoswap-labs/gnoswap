// governance proposal community pool spend

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gov/governance"

	gns "gno.land/r/gnoswap/v1/gns"
	gs "gno.land/r/gnoswap/v1/gov/staker"
)

var t *testing.T

var (
	to               = testutils.TestAddress("to")
	tokenPath        = consts.GNS_PATH
	adminAddr, _     = access.GetAddress(access.ROLE_ADMIN)
	proposalID       = uint64(1)
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

	println("[SCENARIO] 3. Propose Community Pool Spend")
	proposeCommunityPoolSpend()
	println()

	println("[SCENARIO] 4. Skip voting start delay for ready to vote")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	// Vote for the proposal
	println("[SCENARIO] 4. Vote for the proposal")
	vote(proposalID, true)
	println()

	println("[SCENARIO] 5. Skip voting period and execution delay for ready to execute")
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)
	testing.SkipHeights(int64(config.ExecutionDelay) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 6. Execute Proposal")
	execute(proposalID)
	println()
}

func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(std.NewUserRealm(adminAddr))

	gns.Approve(cross, consts.GOV_STAKER_ADDR, delegatedAmount)
	gs.Delegate(cross, adminAddr, uint64(delegatedAmount), "")

	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

func proposeCommunityPoolSpend() {
	testing.SetRealm(std.NewUserRealm(adminAddr))

	proposalID := governance.ProposeCommunityPoolSpend(cross, "test_title", "test_description", to, tokenPath, 100)
	println("[INFO] created proposal ID:", proposalID)
}

func vote(proposalID uint64, yea bool) {
	testing.SetRealm(std.NewUserRealm(adminAddr))

	prevYeaNum := governance.GetYeaByProposalId(proposalID)
	prevNayNum := governance.GetNayByProposalId(proposalID)

	governance.Vote(cross, proposalID, yea)

	afterYeaNum := governance.GetYeaByProposalId(proposalID)
	afterNayNum := governance.GetNayByProposalId(proposalID)
	ufmt.Printf("[INFO] before voting - yea: %s, nay: %s\n", prevYeaNum, prevNayNum)
	ufmt.Printf("[INFO] after voting - yea: %s, nay: %s\n", afterYeaNum, afterNayNum)
}

func execute(proposalID uint64) {
	testing.SetRealm(std.NewUserRealm(adminAddr))

	// get receiver's balance before executing
	prevReceiverBalance := gns.BalanceOf(to)
	ufmt.Printf("[INFO] receiver's balance before executing: %d\n", prevReceiverBalance)

	// execute proposal
	err := governance.Execute(cross, proposalID)
	if err != nil {
		panic(err)
	}

	// get receiver's balance after executing
	afterReceiverBalance := gns.BalanceOf(to)
	ufmt.Printf("[INFO] receiver's balance after executing: %d\n", afterReceiverBalance)

	proposalState := governance.GetExecutionStateByProposalId(proposalID)

	ufmt.Printf("[EXPECTED] receiver's balance increased by %d\n", afterReceiverBalance-prevReceiverBalance)
	ufmt.Printf("[EXPECTED] proposal's executed state is %v\n", proposalState.Executed)
}

// Output:
// [SCENARIO] 1. Delegate gns to admin
// [INFO] gns delegated to g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d (amount: 1000000000)
//
// [SCENARIO] 2. Skip vote weight smoothing duration for create proposal
// [INFO] current height: 43323
//
// [SCENARIO] 3. Propose Community Pool Spend
// [INFO] created proposal ID: 1
//
// [SCENARIO] 4. Skip voting start delay for ready to vote
// [INFO] current height: 86523
//
// [SCENARIO] 4. Vote for the proposal
// [INFO] before voting - yea: 0, nay: 0
// [INFO] after voting - yea: 1000000000, nay: 0
//
// [SCENARIO] 5. Skip voting period and execution delay for ready to execute
// [INFO] current height: 432123
//
// [SCENARIO] 6. Execute Proposal
// [INFO] receiver's balance before executing: 0
// [INFO] receiver's balance after executing: 100
// [EXPECTED] receiver's balance increased by 100
// [EXPECTED] proposal's executed state is true
