// governance proposal text

// PKGPATH: gno.land/r/gnoswap/v1/main

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

	"gno.land/r/gnoswap/v1/gov/governance"
	gs "gno.land/r/gnoswap/v1/gov/staker"

	gns "gno.land/r/gnoswap/gns"
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
	println("[INFO] current height:", runtime.ChainHeight())
	println()

	println("[SCENARIO] 3. Propose community pool spend")
	proposalId := proposeCommunityPoolSpend()
	println()

	println("[SCENARIO] 4. Cancel Proposal")
	cancelProposal(proposalId)
	println()
}

func delegateGnsToAdmin() {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	govStakerAddr := address("g17e3ykyqk9jmqe2y9wxe9zhep3p7cw56davjqwa")
	gns.Approve(cross, govStakerAddr, delegatedAmount)
	gs.Delegate(cross, adminAddr, int64(delegatedAmount), "")
	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

func proposeCommunityPoolSpend() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalId := governance.ProposeCommunityPoolSpend(cross, "test_title", "test_description", adminAddr, "gno.land/r/gnoswap/gns", 100)
	ufmt.Printf("[INFO] created proposal ID: %d\n", proposalId)
	return proposalId
}

func voteProposal(proposalId int64) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	governance.Vote(cross, proposalId, true)
	state := governance.GetExecutionStateByProposalId(proposalId)
	ufmt.Printf("[EXPECTED] after voting - %s\n", state)
}

func cancelProposal(proposalId int64) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
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
// [SCENARIO] 3. Propose community pool spend
// [INFO] created proposal ID: 1
//
// [SCENARIO] 4. Cancel Proposal
// [EXPECTED] proposal canceled and archived
