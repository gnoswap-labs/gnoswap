// governance proposal execute - reconfigure governance

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/governance"

	govStaker "gno.land/r/gnoswap/v1/gov/staker"
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

	println("[SCENARIO] 2. Skip voting smoothing duration for create proposal")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 3. Propose Reconfigure Governance Parameters")
	proposalID := proposeReconfigureGovernance()
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

	println("[SCENARIO] 7. Execute the reconfigure governance parameters proposal")
	executeReconfigureGovernance(proposalID)
	println()
}

func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(std.NewUserRealm(adminAddr))

	gns.Approve(cross, consts.GOV_STAKER_ADDR, delegatedAmount)
	govStaker.Delegate(cross, adminAddr, int64(delegatedAmount), "")

	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

func proposeReconfigureGovernance() int64 {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	proposalID := governance.ProposeParameterChange(cross, "gov", "reconfigure", 1, "gno.land/r/gnoswap/v1/gov/governance*EXE*Reconfigure*EXE*123,456,789,1234,5678,12345,67890")

	ufmt.Printf("[INFO] Reconfigure Governance Parameters Proposal ID: %d\n", proposalID)
	return proposalID
}

func vote(proposalID int64, yea bool) {
	testing.SetRealm(std.NewUserRealm(adminAddr))

	prevYeaNum := governance.GetYeaByProposalId(proposalID)
	prevNayNum := governance.GetNayByProposalId(proposalID)

	governance.Vote(cross, proposalID, yea)

	afterYeaNum := governance.GetYeaByProposalId(proposalID)
	afterNayNum := governance.GetNayByProposalId(proposalID)
	ufmt.Printf("[EXPECTED] before proposal %d voting - yea: %d, nay: %d\n", proposalID, prevYeaNum, prevNayNum)
	ufmt.Printf("[EXPECTED] after proposal %d voting - yea: %d, nay: %d\n", proposalID, afterYeaNum, afterNayNum)
}

func executeReconfigureGovernance(proposalID int64) {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	prevGovConfig := governance.GetLatestConfig()

	governance.Execute(cross, proposalID)

	afterGovConfig := governance.GetLatestConfig()

	ufmt.Printf("[EXPECTED] before proposal %d executing - voting start delay: %d, voting period: %d, quorum: %d\n", proposalID, prevGovConfig.VotingStartDelay, prevGovConfig.VotingPeriod, prevGovConfig.Quorum)
	ufmt.Printf("[EXPECTED] after proposal %d executing - voting start delay: %d, voting period: %d, quorum: %d\n", proposalID, afterGovConfig.VotingStartDelay, afterGovConfig.VotingPeriod, afterGovConfig.Quorum)
}

// Output:
// [SCENARIO] 1. Delegate gns to admin
// [INFO] gns delegated to g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d (amount: 1000000000)
//
// [SCENARIO] 2. Skip voting smoothing duration for create proposal
// [INFO] current height: 43323
//
// [SCENARIO] 3. Propose Reconfigure Governance Parameters
// [INFO] Reconfigure Governance Parameters Proposal ID: 1
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
// [SCENARIO] 7. Execute the reconfigure governance parameters proposal
// [EXPECTED] before proposal 1 executing - voting start delay: 86400, voting period: 604800, quorum: 50
// [EXPECTED] after proposal 1 executing - voting start delay: 123, voting period: 456, quorum: 1234
