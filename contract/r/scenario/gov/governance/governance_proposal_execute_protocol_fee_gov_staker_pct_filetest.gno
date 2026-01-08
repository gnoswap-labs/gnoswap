// governance proposal execute - SetGovStakerPct via governance

package main

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	pf "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"

	govStaker "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr        = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr    = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	currentBlockTime = int64(2)
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

	println("[SCENARIO] 3. Check current GovStakerPct before proposal")
	checkGovStakerPct()
	println()

	println("[SCENARIO] 4. Propose SetGovStakerPct")
	proposalID := proposeSetGovStakerPct()
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

	println("[SCENARIO] 8. Execute the SetGovStakerPct proposal")
	executeSetGovStakerPct(proposalID)
	println()

	println("[SCENARIO] 9. Check GovStakerPct after execution")
	checkGovStakerPct()
	println()
}

func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	gns.Approve(cross, govStakerAddr, delegatedAmount)
	govStaker.Delegate(cross, adminAddr, int64(delegatedAmount), "")

	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

func checkGovStakerPct() {
	devOpsPct := pf.GetDevOpsPct()
	govStakerPct := pf.GetGovStakerPct()
	ufmt.Printf("[INFO] Current DevOpsPct: %d, GovStakerPct: %d\n", devOpsPct, govStakerPct)
	ufmt.Printf("[EXPECTED] DevOpsPct + GovStakerPct = %d (should be 10000)\n", devOpsPct+govStakerPct)
}

func proposeSetGovStakerPct() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	// Set GovStakerPct to 6000 (60%)
	proposalID := governance.ProposeParameterChange(
		cross,
		"protocol_fee",
		"Set GovStakerPct to 60%",
		1,
		"gno.land/r/gnoswap/protocol_fee*EXE*SetGovStakerPct*EXE*6000",
	)

	ufmt.Printf("[INFO] SetGovStakerPct Proposal ID: %d\n", proposalID)
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

func executeSetGovStakerPct(proposalID int64) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

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
// [SCENARIO] 3. Check current GovStakerPct before proposal
// [INFO] Current DevOpsPct: 0, GovStakerPct: 10000
// [EXPECTED] DevOpsPct + GovStakerPct = 10000 (should be 10000)
//
// [SCENARIO] 4. Propose SetGovStakerPct
// [INFO] SetGovStakerPct Proposal ID: 1
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
// [SCENARIO] 8. Execute the SetGovStakerPct proposal
// [INFO] Proposal 1 executed successfully
//
// [SCENARIO] 9. Check GovStakerPct after execution
// [INFO] Current DevOpsPct: 4000, GovStakerPct: 6000
// [EXPECTED] DevOpsPct + GovStakerPct = 10000 (should be 10000)
