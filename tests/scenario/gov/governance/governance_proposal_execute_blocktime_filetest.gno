// governance proposal execute - block time change

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/governance"

	govStaker "gno.land/r/gnoswap/v1/gov/staker"
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

	println("[SCENARIO] 2. Skip voting smoothing duration for create proposal")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 3. Propose Change Average Block Time")
	proposalID := proposeChangeAvgBlockTime()
	println()

	println("[SCENARIO] 4. Skip voting start delay for ready to vote")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 5. Vote for the proposal")
	vote(proposalID, true)
	println()

	println("[SCENARIO] 6. Skip voting period for ready to execute")
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 7. Execute the change average block time proposal")
	executeChangeAvgBlockTime(proposalID)
	println()
}

func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(std.NewUserRealm(adminAddr))

	gns.Approve(cross, consts.GOV_STAKER_ADDR, delegatedAmount)
	govStaker.Delegate(cross, adminAddr, uint64(delegatedAmount), "")

	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

func proposeChangeAvgBlockTime() uint64 {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	proposalID := governance.ProposeParameterChange(cross, "blocktime", "set", 1, "gno.land/r/gnoswap/v1/gns*EXE*SetAvgBlockTimeInMs*EXE*5000")

	ufmt.Printf("[INFO] Change Average Block Time Proposal ID: %d\n", proposalID)
	return proposalID
}

func vote(proposalID uint64, yea bool) {
	testing.SetRealm(std.NewUserRealm(adminAddr))

	prevYeaNum := governance.GetYeaByProposalId(proposalID)
	prevNayNum := governance.GetNayByProposalId(proposalID)

	governance.Vote(cross, proposalID, yea)

	afterYeaNum := governance.GetYeaByProposalId(proposalID)
	afterNayNum := governance.GetNayByProposalId(proposalID)
	ufmt.Printf("[EXPECTED] before proposal %d voting - yea: %s, nay: %s\n", proposalID, prevYeaNum, prevNayNum)
	ufmt.Printf("[EXPECTED] after proposal %d voting - yea: %s, nay: %s\n", proposalID, afterYeaNum, afterNayNum)
}

func executeChangeAvgBlockTime(proposalID uint64) {
	testing.SetRealm(std.NewUserRealm(adminAddr))

	prevAvgBlockTime := gns.GetAvgBlockTimeInMs()

	governance.Execute(cross, proposalID)

	afterAvgBlockTime := gns.GetAvgBlockTimeInMs()

	ufmt.Printf("[EXPECTED] before proposal %d executing - avg block time: %dms\n", proposalID, prevAvgBlockTime)
	ufmt.Printf("[EXPECTED] after proposal %d executing - avg block time: %dms\n", proposalID, afterAvgBlockTime)
}

// Output:
// [SCENARIO] 1. Delegate gns to admin
// [INFO] gns delegated to g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d (amount: 1000000000)
//
// [SCENARIO] 2. Skip voting smoothing duration for create proposal
// [INFO] current height: 43323
//
// [SCENARIO] 3. Propose Change Average Block Time
// [INFO] Change Average Block Time Proposal ID: 1
//
// [SCENARIO] 4. Skip voting start delay for ready to vote
// [INFO] current height: 86523
//
// [SCENARIO] 5. Vote for the proposal
// [EXPECTED] before proposal 1 voting - yea: 0, nay: 0
// [EXPECTED] after proposal 1 voting - yea: 1000000000, nay: 0
//
// [SCENARIO] 6. Skip voting period for ready to execute
// [INFO] current height: 388923
//
// [SCENARIO] 7. Execute the change average block time proposal
// [EXPECTED] before proposal 1 executing - avg block time: 2000ms
// [EXPECTED] after proposal 1 executing - avg block time: 5000ms
