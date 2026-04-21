// Scenario: Safe Mode keeps governance proposal and execution paths available

package main

import (
	"testing"
	"time"

	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"
	gs "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	"gno.land/r/gnoswap/halt"
)

var t *testing.T

var (
	adminAddr, _   = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm     = testing.NewUserRealm(adminAddr)
	govStakerAddr  = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	currentBlockTime = int64(2)
)

func main() {
	println("[SCENARIO] 1. Delegate GNS to admin")
	delegateGnsToAdmin()
	println()

	println("[SCENARIO] 2. Skip smoothing duration")
	skipSmoothing()
	println()

	println("[SCENARIO] 3. Set safe mode")
	setSafeMode()
	println()

	println("[SCENARIO] 4. Propose parameter change in safe mode")
	proposalId := proposeGovernanceReconfigure()
	println()

	println("[SCENARIO] 5. Vote proposal in safe mode")
	voteProposal(proposalId)
	println()

	println("[SCENARIO] 6. Execute proposal in safe mode")
	executeProposal(proposalId)
	println()
}

func delegateGnsToAdmin() {
	testing.SetRealm(adminRealm)
	gns.Approve(cross, govStakerAddr, 1_000_000_000)
	gs.Delegate(cross, adminAddr, 1_000_000_000, "")
	ufmt.Println("[INFO] delegated voting power to admin")
}

func skipSmoothing() {
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	ufmt.Printf("[INFO] current height: %d\n", time.Now().Unix())
}

func setSafeMode() {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelSafeMode)
	ufmt.Printf("[INFO] Governance halted: %t\n", halt.IsHaltedGovernance())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func proposeGovernanceReconfigure() int64 {
	testing.SetRealm(adminRealm)
	proposalId := governance.ProposeParameterChange(cross, "gov", "reconfigure", 1, "gno.land/r/gnoswap/gov/governance*EXE*Reconfigure*EXE*123,456,789,60,5678,12345,67890")
	ufmt.Printf("[EXPECTED] proposal id: %d\n", proposalId)
	return proposalId
}

func voteProposal(proposalId int64) {
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	testing.SetRealm(adminRealm)
	governance.Vote(cross, proposalId, true)
	status, _ := governance.GetProposalStatusByProposalId(proposalId)
	ufmt.Printf("[EXPECTED] proposal status after vote: %s\n", status)
}

func executeProposal(proposalId int64) {
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingPeriod+config.ExecutionDelay)/currentBlockTime + 1)
	testing.SetRealm(adminRealm)
	before := governance.GetLatestConfig()
	result := governance.Execute(cross, proposalId)
	uassert.Equal(t, proposalId, result)
	ufmt.Printf("[EXPECTED] executed proposal id: %d\n", result)
	after := governance.GetLatestConfig()
	ufmt.Printf("[EXPECTED] voting start delay before/after: %d -> %d\n", before.VotingStartDelay, after.VotingStartDelay)
}

// Output:
// [SCENARIO] 1. Delegate GNS to admin
// [INFO] delegated voting power to admin
//
// [SCENARIO] 2. Skip smoothing duration
// [INFO] current height: 1234783890
//
// [SCENARIO] 3. Set safe mode
// [INFO] Governance halted: false
// [INFO] Withdraw halted: true
//
// [SCENARIO] 4. Propose parameter change in safe mode
// [EXPECTED] proposal id: 1
//
// [SCENARIO] 5. Vote proposal in safe mode
// [EXPECTED] proposal status after vote: active
//
// [SCENARIO] 6. Execute proposal in safe mode
// [EXPECTED] executed proposal id: 1
// [EXPECTED] voting start delay before/after: 86400 -> 123
