// governance proposal execute - staker AddToken/RemoveToken via governance

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

	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr        = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr    = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	currentBlockTime = int64(2)
)

const testTokenPath = "gno.land/r/onbloc/obl"

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

	println("[SCENARIO] 3. Propose AddToken")
	addTokenProposalID := proposeAddToken()
	println()

	println("[SCENARIO] 4. Vote and execute AddToken proposal")
	voteAndExecute(addTokenProposalID, config)
	println()

	println("[SCENARIO] 5. Propose RemoveToken")
	removeTokenProposalID := proposeRemoveToken()
	println()

	println("[SCENARIO] 6. Vote and execute RemoveToken proposal")
	voteAndExecute(removeTokenProposalID, config)
	println()
}

func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	gns.Approve(cross, govStakerAddr, delegatedAmount)
	govStaker.Delegate(cross, adminAddr, int64(delegatedAmount), "")

	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

func proposeAddToken() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalID := governance.ProposeParameterChange(
		cross,
		"staker",
		"Add OBL token to allowed list",
		1,
		"gno.land/r/gnoswap/staker*EXE*AddToken*EXE*"+testTokenPath,
	)

	ufmt.Printf("[INFO] AddToken Proposal ID: %d\n", proposalID)
	return proposalID
}

func proposeRemoveToken() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalID := governance.ProposeParameterChange(
		cross,
		"staker",
		"Remove OBL token from allowed list",
		1,
		"gno.land/r/gnoswap/staker*EXE*RemoveToken*EXE*"+testTokenPath,
	)

	ufmt.Printf("[INFO] RemoveToken Proposal ID: %d\n", proposalID)
	return proposalID
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
	ufmt.Printf("[EXPECTED] Proposal %d executed successfully\n", proposalID)
}

// Output:
// [SCENARIO] 1. Delegate gns to admin
// [INFO] gns delegated to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 (amount: 1000000000)
//
// [SCENARIO] 2. Skip voting smoothing duration for create proposal
// [INFO] current height: 43323
//
// [SCENARIO] 3. Propose AddToken
// [INFO] AddToken Proposal ID: 1
//
// [SCENARIO] 4. Vote and execute AddToken proposal
// [INFO] current height after voting start delay: 86523
// [INFO] Voted YES for proposal 1
// [INFO] current height after voting period: 388923
// [EXPECTED] Proposal 1 executed successfully
//
// [SCENARIO] 5. Propose RemoveToken
// [INFO] RemoveToken Proposal ID: 2
//
// [SCENARIO] 6. Vote and execute RemoveToken proposal
// [INFO] current height after voting start delay: 432123
// [INFO] Voted YES for proposal 2
// [INFO] current height after voting period: 734523
// [EXPECTED] Proposal 2 executed successfully
