// governance proposal execute - launchpad UpgradeImpl via governance

package main

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"

	govStaker "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"
	_ "gno.land/r/gnoswap/launchpad/v3_valid"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr        = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr    = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	currentBlockTime = int64(2)
)

const (
	launchpadV1Path = "gno.land/r/gnoswap/launchpad/v1"
	launchpadV3Path = "gno.land/r/gnoswap/launchpad/v3_valid"
)

func main() {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	config := governance.GetLatestConfig()

	println("[SCENARIO] 1. Delegate gns to admin")
	delegateGnsToAdmin()
	println()

	println("[SCENARIO] 2. Skip voting smoothing duration for create proposal")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 3. Check current launchpad implementation version")
	checkLaunchpadVersion()
	println()

	println("[SCENARIO] 4. Propose launchpad UpgradeImpl to v3_valid")
	proposalID := proposeLaunchpadUpgrade()
	println()

	println("[SCENARIO] 5. Skip voting start delay for ready to vote")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 6. Vote for the proposal")
	vote(proposalID, true)
	println()

	println("[SCENARIO] 7. Skip voting period for ready to execute")
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 8. Execute the launchpad UpgradeImpl proposal")
	executeProposal(proposalID)
	println()

	println("[SCENARIO] 9. Check launchpad implementation version after execution")
	checkLaunchpadVersion()
	println()

	println("[SCENARIO] 10. Propose launchpad rollback to v1")
	rollbackProposalID := proposeLaunchpadRollback()
	println()

	println("[SCENARIO] 11. Vote and execute rollback")
	voteAndExecute(rollbackProposalID, config)
	println()

	println("[SCENARIO] 12. Check launchpad implementation version after rollback")
	checkLaunchpadVersion()
	println()
}

func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	gns.Approve(cross, govStakerAddr, delegatedAmount)
	govStaker.Delegate(cross, adminAddr, int64(delegatedAmount), "")

	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

func checkLaunchpadVersion() {
	version := launchpad.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Current launchpad implementation: %s\n", version)
}

func proposeLaunchpadUpgrade() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalID := governance.ProposeParameterChange(
		cross,
		"launchpad",
		"Upgrade launchpad implementation to v3_valid",
		1,
		"gno.land/r/gnoswap/launchpad*EXE*UpgradeImpl*EXE*"+launchpadV3Path,
	)

	ufmt.Printf("[INFO] Launchpad UpgradeImpl Proposal ID: %d\n", proposalID)
	return proposalID
}

func proposeLaunchpadRollback() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalID := governance.ProposeParameterChange(
		cross,
		"launchpad",
		"Rollback launchpad implementation to v1",
		1,
		"gno.land/r/gnoswap/launchpad*EXE*UpgradeImpl*EXE*"+launchpadV1Path,
	)

	ufmt.Printf("[INFO] Launchpad Rollback Proposal ID: %d\n", proposalID)
	return proposalID
}

func vote(proposalID int64, yea bool) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	prevYeaNum := governance.GetYeaByProposalId(proposalID)
	prevNayNum := governance.GetNayByProposalId(proposalID)

	governance.Vote(cross, proposalID, yea)

	afterYeaNum := governance.GetYeaByProposalId(proposalID)
	afterNayNum := governance.GetNayByProposalId(proposalID)
	ufmt.Printf("[INFO] before proposal %d voting - yea: %d, nay: %d\n", proposalID, prevYeaNum, prevNayNum)
	ufmt.Printf("[INFO] after proposal %d voting - yea: %d, nay: %d\n", proposalID, afterYeaNum, afterNayNum)
}

func executeProposal(proposalID int64) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	governance.Execute(cross, proposalID)

	ufmt.Printf("[INFO] Proposal %d executed successfully\n", proposalID)
}

func voteAndExecute(proposalID int64, config governance.Config) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	// Skip to voting start
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	ufmt.Printf("[INFO] current height after voting start delay: %d\n", runtime.ChainHeight())

	// Vote
	governance.Vote(cross, proposalID, true)
	ufmt.Printf("[INFO] Voted YES for proposal %d\n", proposalID)

	// Skip to execution
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)
	ufmt.Printf("[INFO] current height after voting period: %d\n", runtime.ChainHeight())

	// Execute
	governance.Execute(cross, proposalID)
	ufmt.Printf("[INFO] Proposal %d executed successfully\n", proposalID)
}

// Output:
// [SCENARIO] 1. Delegate gns to admin
// [INFO] gns delegated to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 (amount: 1000000000)
//
// [SCENARIO] 2. Skip voting smoothing duration for create proposal
// [INFO] current height: 43323
//
// [SCENARIO] 3. Check current launchpad implementation version
// [EXPECTED] Current launchpad implementation: gno.land/r/gnoswap/launchpad/v1
//
// [SCENARIO] 4. Propose launchpad UpgradeImpl to v3_valid
// [INFO] Launchpad UpgradeImpl Proposal ID: 1
//
// [SCENARIO] 5. Skip voting start delay for ready to vote
// [INFO] current height: 86523
//
// [SCENARIO] 6. Vote for the proposal
// [INFO] before proposal 1 voting - yea: 0, nay: 0
// [INFO] after proposal 1 voting - yea: 1000000000, nay: 0
//
// [SCENARIO] 7. Skip voting period for ready to execute
// [INFO] current height: 388923
//
// [SCENARIO] 8. Execute the launchpad UpgradeImpl proposal
// [INFO] Proposal 1 executed successfully
//
// [SCENARIO] 9. Check launchpad implementation version after execution
// [EXPECTED] Current launchpad implementation: gno.land/r/gnoswap/launchpad/v3_valid
//
// [SCENARIO] 10. Propose launchpad rollback to v1
// [INFO] Launchpad Rollback Proposal ID: 2
//
// [SCENARIO] 11. Vote and execute rollback
// [INFO] current height after voting start delay: 432123
// [INFO] Voted YES for proposal 2
// [INFO] current height after voting period: 734523
// [INFO] Proposal 2 executed successfully
//
// [SCENARIO] 12. Check launchpad implementation version after rollback
// [EXPECTED] Current launchpad implementation: gno.land/r/gnoswap/launchpad/v1
