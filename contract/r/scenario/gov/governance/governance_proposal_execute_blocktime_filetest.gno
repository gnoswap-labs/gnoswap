// governance proposal execute - block time change

package main

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"

	govStaker "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"

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
	println("[INFO] current height:", runtime.ChainHeight())
	println()

	println("[SCENARIO] 3. Propose Change Average Block Time")
	proposalID := proposeChangeAvgBlockTime()
	println()

	println("[SCENARIO] 4. Skip voting start delay for ready to vote")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	println("[INFO] current height:", runtime.ChainHeight())
	println()

	println("[SCENARIO] 5. Vote for the proposal")
	vote(proposalID, true)
	println()

	println("[SCENARIO] 6. Skip voting period for ready to execute")
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)
	println("[INFO] current height:", runtime.ChainHeight())
	println()

	println("[SCENARIO] 7. Execute the change average block time proposal")
	println("[INFO] Set pool creation fee to 0")
	executeSetPoolCreationFee(proposalID)
	println()
}

func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	gns.Approve(cross, govStakerAddr, delegatedAmount)
	govStaker.Delegate(cross, adminAddr, int64(delegatedAmount), "")

	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

func proposeChangeAvgBlockTime() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalID := governance.ProposeParameterChange(cross, "poolcreationfee", "set", 1, "gno.land/r/gnoswap/pool*EXE*SetPoolCreationFee*EXE*0")

	ufmt.Printf("[INFO] Change Pool Creation Fee Proposal ID: %d\n", proposalID)
	return proposalID
}

func vote(proposalID int64, yea bool) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	prevYeaNum := governance.GetYeaByProposalId(proposalID)
	prevNayNum := governance.GetNayByProposalId(proposalID)

	governance.Vote(cross, proposalID, yea)

	afterYeaNum := governance.GetYeaByProposalId(proposalID)
	afterNayNum := governance.GetNayByProposalId(proposalID)
	ufmt.Printf("[EXPECTED] before proposal %d voting - yea: %d, nay: %d\n", proposalID, prevYeaNum, prevNayNum)
	ufmt.Printf("[EXPECTED] after proposal %d voting - yea: %d, nay: %d\n", proposalID, afterYeaNum, afterNayNum)
}

func executeSetPoolCreationFee(proposalID int64) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	prevPoolCreationFee := pool.GetPoolCreationFee()

	governance.Execute(cross, proposalID)

	afterPoolCreationFee := pool.GetPoolCreationFee()

	ufmt.Printf("[EXPECTED] before proposal %d executing - pool creation fee: %d\n", proposalID, prevPoolCreationFee)
	ufmt.Printf("[EXPECTED] after proposal %d executing - pool creation fee: %d\n", proposalID, afterPoolCreationFee)
}

// Output:
// [SCENARIO] 1. Delegate gns to admin
// [INFO] gns delegated to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 (amount: 1000000000)
//
// [SCENARIO] 2. Skip voting smoothing duration for create proposal
// [INFO] current height: 43323
//
// [SCENARIO] 3. Propose Change Average Block Time
// [INFO] Change Pool Creation Fee Proposal ID: 1
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
// [INFO] Set pool creation fee to 0
// [EXPECTED] before proposal 1 executing - pool creation fee: 100000000
// [EXPECTED] after proposal 1 executing - pool creation fee: 0
