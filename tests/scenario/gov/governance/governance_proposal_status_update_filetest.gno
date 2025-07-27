// governance proposal status update

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	gns "gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/governance"
	gs "gno.land/r/gnoswap/v1/gov/staker"
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

	println("[SCENARIO] 2. Skip vote weight smoothing duration for create proposal")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println("[INFO] current height:", std.ChainHeight())
	println()

	println("[SCENARIO] 3. Propose Text and Check Initial State")
	proposalId := proposeCommunityPoolSpend()
	println()

	println("[SCENARIO] 4. Cancel Proposal and Check State")
	testing.SkipHeights((config.VotingStartDelay + config.VotingPeriod + config.ExecutionDelay) / currentBlockTime)
	cancelProposalAndCheckState(proposalId)
	println()
}

func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRiealm(std.NewUserRealm(adminAddr))
	govStakerAddr := std.Address("g17e3ykyqk9jmqe2y9wxe9zhep3p7cw56davjqwa")
	gns.Approve(cross, govStakerAddr, delegatedAmount)
	gs.Delegate(cross, adminAddr, int64(delegatedAmount), "")
	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

func proposeCommunityPoolSpend() int64 {
	testing.SetRealm(std.NewUserRealm(adminAddr))
	proposalId := governance.ProposeCommunityPoolSpend(cross, "test_title_1", "test_description_1", adminAddr, "gno.land/r/gnoswap/v1/gns", 100)
	ufmt.Printf("[INFO] created proposal ID: %d\n", proposalId)
	state := governance.GetExecutionStateByProposalId(proposalId)
	ufmt.Printf("[EXPECTED] proposal created: %v\n", state)
	return proposalId
}

func cancelProposalAndCheckState(proposalId int64) {
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
// [EXPECTED] proposal created: upcoming
//
// [SCENARIO] 4. Cancel Proposal and Check State
// [EXPECTED] proposal canceled and archived
