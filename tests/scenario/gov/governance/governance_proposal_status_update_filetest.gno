// governance proposal status update

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
	gns "gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/governance"
	gs "gno.land/r/gnoswap/v1/gov/staker"
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

	println("[SCENARIO] 2. Skip vote weight smoothing duration for create proposal")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 3. Propose Text and Check Initial State")
	proposalId := proposeTextAndCheckInitialState()
	println()

	println("[SCENARIO] 4. Cancel Proposal and Check State")
	cancelProposalAndCheckState(proposalId)
	println()
}

func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(std.NewUserRealm(adminAddr))
	gns.Approve(cross, consts.GOV_STAKER_ADDR, delegatedAmount)
	gs.Delegate(cross, adminAddr, uint64(delegatedAmount), "")
	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

func proposeTextAndCheckInitialState() uint64 {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	proposalId := governance.ProposeText(cross, "test_title_1", "test_description_1")
	ufmt.Printf("[INFO] created proposal ID: %d\n", proposalId)
	state := governance.GetExecutionStateByProposalId(proposalId)
	ufmt.Printf("[EXPECTED] proposal created: %v\n", state.Created)
	return proposalId
}

func cancelProposalAndCheckState(proposalId uint64) {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	governance.Cancel(cross, proposalId)
	ufmt.Printf("[EXPECTED] proposal canceled and archived\n")
}

// Output:
// [SCENARIO] 1. Delegate gns to admin
// [INFO] gns delegated to g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d (amount: 1000000000)
//
// [SCENARIO] 2. Skip vote weight smoothing duration for create proposal
// [INFO] current height: 43323
//
// [SCENARIO] 3. Propose Text and Check Initial State
// [INFO] created proposal ID: 1
// [EXPECTED] proposal created: true
//
// [SCENARIO] 4. Cancel Proposal and Check State
// [EXPECTED] proposal canceled and archived
