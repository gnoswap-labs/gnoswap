// governance vote gov delegated undelegated before propose

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	gns "gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/governance"
	gs "gno.land/r/gnoswap/v1/gov/staker"
)

var (
	adminAddr, _     = access.GetAddress(access.ROLE_ADMIN)
	dummyAddr        = testutils.TestAddress("dummyAddr")
	currentBlockTime = int64(2)
)

func main() {
	config := governance.GetLatestConfig()

	println("[SCENARIO] 1. Delegate gns to admin and dummy")
	delegateGnsToAdminAndDummy()
	println()

	println("[SCENARIO] 2. Undelegate from dummy before propose")
	undelegateFromDummy()
	println()

	println("[SCENARIO] 3. Skip vote weight smoothing duration for create proposal")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 4. Propose Text")
	proposalId := proposeText()
	println()

	println("[SCENARIO] 5. Skip voting start delay for ready to vote")
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 6. Vote for the proposal with dummy")
	voteProposalWithDummy(proposalId)
	println()
}

func delegateGnsToAdminAndDummy() {
	delegatedAmount := int64(1_000_000_000)
	// admin
	testing.SetRealm(std.NewUserRealm(adminAddr))
	gns.Approve(cross, consts.GOV_STAKER_ADDR, delegatedAmount)
	gs.Delegate(cross, adminAddr, uint64(delegatedAmount), "")
	ufmt.Printf("[INFO] gns delegated to admin %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
	// dummy
	gns.Approve(cross, consts.GOV_STAKER_ADDR, delegatedAmount)
	gs.Delegate(cross, dummyAddr, uint64(delegatedAmount), "")
	ufmt.Printf("[INFO] gns delegated to dummy %s (amount: %d)\n", dummyAddr.String(), delegatedAmount)
}

func undelegateFromDummy() {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	gs.Undelegate(cross, dummyAddr, uint64(1_000_000))
	ufmt.Printf("[INFO] undelegated from dummy %s (amount: %d)\n", dummyAddr.String(), uint64(1_000_000))
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
// [SCENARIO] 1. Delegate gns to admin and dummy
// [INFO] gns delegated to admin g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d (amount: 1000000000)
// [INFO] gns delegated to dummy g1v36k6mteg9jxgujlta047h6lta047h6lydhz9l (amount: 1000000000)
//
// [SCENARIO] 2. Undelegate from dummy before propose
// [INFO] undelegated from dummy g1v36k6mteg9jxgujlta047h6lta047h6lydhz9l (amount: 1000000)
//
// [SCENARIO] 3. Skip vote weight smoothing duration for create proposal
// [INFO] current height: 43323
//
// [SCENARIO] 4. Propose Text
// [INFO] created proposal ID: 1
//
// [SCENARIO] 5. Skip voting start delay for ready to vote
// [INFO] current height: 86523
//
// [SCENARIO] 6. Vote for the proposal with dummy
// [EXPECTED] after voting - active: true, passed: false
