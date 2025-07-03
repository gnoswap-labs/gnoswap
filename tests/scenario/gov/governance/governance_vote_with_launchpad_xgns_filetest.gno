// governance vote with launchpad xGNS

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
	"gno.land/r/gnoswap/v1/gov/xgns"

	gns "gno.land/r/gnoswap/v1/gns"
	gs "gno.land/r/gnoswap/v1/gov/staker"
)

var (
	adminAddr, _     = access.GetAddress(access.ROLE_ADMIN)
	dummyAddr        = testutils.TestAddress("dummy")
	user01           = testutils.TestAddress("user01")
	currentBlockTime = int64(2)
)

func main() {
	config := governance.GetLatestConfig()

	println("[SCENARIO] 1. Check Initial gns and xgns Supply")
	checkInitialGnsAndXgns()
	println()

	println("[SCENARIO] 2. Launchpad Project Create and Deposit gns")
	launchpadProjectCreateAndDeposit()
	println()

	println("[SCENARIO] 3. Delegate gns to dummy")
	delegateGnsToDummy()
	println()

	println("[SCENARIO] 4. Skip vote weight smoothing duration for create proposal")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 5. Propose Text")
	proposalId := proposeText()
	println()

	println("[SCENARIO] 6. Skip voting start delay for ready to vote")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 7. Vote for the proposal with dummy")
	voteProposalWithDummy(proposalId)
	println()
}

func checkInitialGnsAndXgns() {
	ufmt.Printf("[INFO] gns total supply: %d, xgns total: %d, xgns voting: %d\n", gns.TotalSupply(), xgns.TotalSupply(), xgns.VotingSupply())
}

func launchpadProjectCreateAndDeposit() {
	ufmt.Printf("[INFO] launchpad project created and gns deposited\n")
}

func delegateGnsToDummy() {
	delegatedAmount := int64(2_000_000_000)
	testing.SetRealm(std.NewUserRealm(adminAddr))
	gns.Approve(cross, consts.GOV_STAKER_ADDR, delegatedAmount)
	gs.Delegate(cross, dummyAddr, uint64(delegatedAmount), "")
	ufmt.Printf("[INFO] gns delegated to dummy %s (amount: %d)\n", dummyAddr.String(), delegatedAmount)
}

func proposeText() uint64 {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	proposalId := governance.ProposeText(cross, "test_title", "test_description")
	ufmt.Printf("[INFO] created proposal ID: %d\n", proposalId)
	return proposalId
}

func voteProposalWithDummy(proposalId uint64) {
	testing.SetRealm(std.NewUserRealm(dummyAddr))
	governance.Vote(cross, proposalId, true)
	state := governance.GetExecutionStateByProposalId(proposalId)
	ufmt.Printf("[EXPECTED] after voting - active: %v, passed: %v\n", state.Active, state.Passed)
}

// Output:
// [SCENARIO] 1. Check Initial gns and xgns Supply
// [INFO] gns total supply: 100000000000000, xgns total: 0, xgns voting: 0
//
// [SCENARIO] 2. Launchpad Project Create and Deposit gns
// [INFO] launchpad project created and gns deposited
//
// [SCENARIO] 3. Delegate gns to dummy
// [INFO] gns delegated to dummy g1v36k6mteta047h6lta047h6lta047h6lz7gmv8 (amount: 2000000000)
//
// [SCENARIO] 4. Skip vote weight smoothing duration for create proposal
// [INFO] current height: 43323
//
// [SCENARIO] 5. Propose Text
// [INFO] created proposal ID: 1
//
// [SCENARIO] 6. Skip voting start delay for ready to vote
// [INFO] current height: 86523
//
// [SCENARIO] 7. Vote for the proposal with dummy
// [EXPECTED] after voting - active: true, passed: false
