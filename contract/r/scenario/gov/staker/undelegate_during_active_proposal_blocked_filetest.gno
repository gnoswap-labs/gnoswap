// undelegate during active proposal is blocked

package main

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/governance"
	"gno.land/r/gnoswap/gov/staker"

	_ "gno.land/r/gnoswap/gov/governance/v1"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	govStakerAddr, _ = access.GetAddress(prbac.ROLE_GOV_STAKER.String())

	userAddr     = testutils.TestAddress("alice")
	userRealm    = testing.NewUserRealm(userAddr)
	validatorAddr = testutils.TestAddress("validator1")

	minAmount = int64(1_000_000)
)

func main() {
	println("[SCENARIO] 1. Configure governance for immediate active proposals")
	configureGovernance()
	println()

	println("[SCENARIO] 2. Delegate and create active proposal")
	delegateAndPropose()
	println()

	println("[SCENARIO] 3. Undelegate during active proposal")
	undelegateDuringActiveProposal()
	println()
}

func configureGovernance() {
	testing.SetRealm(adminRealm)
	config := governance.GetLatestConfig()
	governance.Reconfigure(
		cross,
		0, // voting start immediately
		config.VotingPeriod,
		0, // no smoothing
		config.Quorum,
		minAmount, // lower creation threshold for test
		config.ExecutionDelay,
		config.ExecutionWindow,
	)
	ufmt.Printf("[INFO] governance reconfigured: startDelay=0, smoothing=0, threshold=%d\n", minAmount)
}

func delegateAndPropose() {
	testing.SetRealm(adminRealm)
	// Transfer enough GNS for both delegation and proposal creation threshold
	gns.Transfer(cross, userAddr, minAmount*2)

	testing.SetRealm(userRealm)
	gns.Approve(cross, govStakerAddr, minAmount)
	staker.Delegate(cross, validatorAddr, minAmount, "")

	// User still has minAmount GNS remaining for proposal threshold check
	governance.ProposeText(cross, "Active proposal", "Should block undelegate")

	_, hasActive := governance.GetOldestActiveProposalSnapshotTime()
	ufmt.Printf("[INFO] active proposal exists: %v\n", hasActive)
	println("[EXPECTED] active proposal exists: true")
}

func undelegateDuringActiveProposal() {
	testing.SetRealm(userRealm)

	expectedAbortMsg := "[GNOSWAP-GOV_STAKER-014] cannot undelegate during active proposal"
	ufmt.Printf("[INFO] attempting undelegate during active proposal\n")
	uassert.AbortsContains(t, expectedAbortMsg, func() {
		staker.Undelegate(cross, validatorAddr, minAmount)
	})
	ufmt.Printf("[INFO] undelegate blocked with expected error\n")

}

// Output:
// [SCENARIO] 1. Configure governance for immediate active proposals
// [INFO] governance reconfigured: startDelay=0, smoothing=0, threshold=1000000
//
// [SCENARIO] 2. Delegate and create active proposal
// [INFO] active proposal exists: true
// [EXPECTED] active proposal exists: true
//
// [SCENARIO] 3. Undelegate during active proposal
// [INFO] attempting undelegate during active proposal
// [INFO] undelegate blocked with expected error
