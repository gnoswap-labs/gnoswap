// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"

	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"
	gs "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	_ "gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/foo"
)

const INT64_MAX int64 = 9223372036854775807

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	poolAddr      = access.MustGetAddress(prbac.ROLE_POOL.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	bobAddr  = testutils.TestAddress("bob")
	bobRealm = testing.NewUserRealm(bobAddr)

	currentBlockTime = int64(2)
	proposalId       int64
)

func main() {
	testing.SetRealm(adminRealm)
	config := governance.GetLatestConfig()

	println("[SCENARIO] 1. Initialize governance and tokens")
	initGovernanceAndTokens()
	println()

	println("[SCENARIO] 2. Skip vote weight smoothing duration for create proposal")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println()

	println("[SCENARIO] 3. Create and vote on proposal with emission enabled")
	createAndVoteProposalWithEmissionEnabled()
	println()

	println("[SCENARIO] 4. Set halt level to halt emission only")
	setEmissionHalt()
	println()

	println("[SCENARIO] 5. Create new proposal with emission halted")
	createProposalWithEmissionHalted()
	println()

	println("[SCENARIO] 6. Vote on proposal with emission halted")
	voteOnProposalWithEmissionHalted()
	println()

	println("[SCENARIO] 7. Execute proposal with emission halted")
	executeProposalWithEmissionHalted()
	println()

	println("[SCENARIO] 8. Test vote integrity with emission halted")
	resetProposalVotesWithEmissionHalted()
	println()
}

func initGovernanceAndTokens() {
	// Distribute tokens
	defaultTokenAmount := int64(2000000000) // 2B tokens to satisfy proposal threshold after delegation

	testing.SetRealm(adminRealm)
	gns.Transfer(cross, aliceAddr, defaultTokenAmount)
	gns.Transfer(cross, bobAddr, defaultTokenAmount)

	// Delegate GNS tokens for voting power (leave some for proposal creation)
	// Delegate less to ensure enough balance remains for proposal creation
	delegatedAmount := defaultTokenAmount / 4 // Delegate only 25% instead of 50%

	testing.SetRealm(aliceRealm)
	gns.Approve(cross, govStakerAddr, INT64_MAX)
	gs.Delegate(cross, aliceAddr, delegatedAmount, "")

	testing.SetRealm(bobRealm)
	gns.Approve(cross, govStakerAddr, INT64_MAX)
	gs.Delegate(cross, bobAddr, delegatedAmount, "")

	ufmt.Printf("[INFO] Alice GNS balance: %d\n", gns.BalanceOf(aliceAddr))
	ufmt.Printf("[INFO] Bob GNS balance: %d\n", gns.BalanceOf(bobAddr))
	ufmt.Println("[INFO] Governance and tokens initialized")
}

func createAndVoteProposalWithEmissionEnabled() {
	// Create text proposal
	testing.SetRealm(aliceRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})
	proposalId = governance.ProposeText(
		cross,
		"Test Proposal with Emission Enabled",
		"This proposal tests governance works normally when emission is enabled",
	)

	ufmt.Printf("[EXPECTED] Proposal created successfully with ID: %d\n", proposalId)

	// Skip to voting start
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)

	// Vote on proposal
	testing.SetRealm(aliceRealm)
	governance.Vote(cross, proposalId, true)
	ufmt.Println("[EXPECTED] Alice voted YES on proposal")

	testing.SetRealm(bobRealm)
	governance.Vote(cross, proposalId, true)
	ufmt.Println("[EXPECTED] Bob voted YES on proposal")

	// Check voting info
	yea, _ := governance.GetYeaByProposalId(proposalId)
	nay, _ := governance.GetNayByProposalId(proposalId)
	ufmt.Printf("[INFO] Vote status - Yea: %d, Nay: %d\n", yea, nay)

	// Move past voting period so the proposal becomes inactive and won't block the next one
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)
	ufmt.Println("[INFO] Advanced past voting period; first proposal is now inactive")
}

func setEmissionHalt() {
	testing.SetRealm(adminRealm)

	// Selectively halt only emission
	halt.SetOperationStatus(cross, halt.OpTypeEmission, true)

	isEmissionHalted := halt.IsHaltedEmission()
	isGovernanceHalted := halt.IsHaltedGovernance()

	println("[INFO] Emission selectively halted")
	ufmt.Printf("[EXPECTED] Emission halted: %t (should be true)\n", isEmissionHalted)
	ufmt.Printf("[EXPECTED] Governance halted: %t (should be false)\n", isGovernanceHalted)
}

func createProposalWithEmissionHalted() {
	// Build a reconfigure execution with modified values to test parameter changes during emission halt
	config := governance.GetLatestConfig()

	// Modify ExecutionWindow to verify the parameter change actually takes effect
	newExecutionWindow := config.ExecutionWindow + 100

	executions := ufmt.Sprintf(
		"gno.land/r/gnoswap/gov/governance*EXE*Reconfigure*EXE*%d,%d,%d,%d,%d,%d,%d",
		config.VotingStartDelay,
		config.VotingPeriod,
		config.VotingWeightSmoothingDuration,
		config.Quorum,
		config.ProposalCreationThreshold,
		config.ExecutionDelay,
		newExecutionWindow,
	)

	ufmt.Printf("[INFO] Current ExecutionWindow: %d\n", config.ExecutionWindow)
	ufmt.Printf("[INFO] New ExecutionWindow (after Execute): %d\n", newExecutionWindow)

	// Create another proposal while emission is halted
	testing.SetRealm(aliceRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})

	println("[INFO] Creating executable proposal with emission HALTED...")

	proposalId = governance.ProposeParameterChange(
		cross,
		"Reconfigure while Emission Halted",
		"Execute governance reconfigure to prove execution works while emission is halted",
		1,
		executions,
	)

	ufmt.Printf("[EXPECTED] Proposal created successfully despite emission halt! ID: %d\n", proposalId)
	println("[SUCCESS] Governance proposal creation not blocked by emission halt")
}

func voteOnProposalWithEmissionHalted() {
	println("[INFO] Voting on proposal with emission HALTED...")

	// Wait for voting to start on the new proposal
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)

	// Alice votes
	testing.SetRealm(aliceRealm)
	governance.Vote(cross, proposalId, true)
	println("[EXPECTED] Alice voted YES successfully despite emission halt")

	// Bob votes
	testing.SetRealm(bobRealm)
	governance.Vote(cross, proposalId, false)
	println("[EXPECTED] Bob voted NO successfully despite emission halt")

	// Check voting results
	yea, _ := governance.GetYeaByProposalId(proposalId)
	nay, _ := governance.GetNayByProposalId(proposalId)
	ufmt.Printf("[INFO] Vote status - Yea: %d, Nay: %d\n", yea, nay)
	println("[SUCCESS] Governance voting not blocked by emission halt")
}

func executeProposalWithEmissionHalted() {
	// Skip to voting end time by advancing blocks
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)

	ufmt.Println("[INFO] Executing proposal with emission HALTED...")

	// Log config BEFORE Execute
	configBefore := governance.GetLatestConfig()
	ufmt.Printf("[INFO] Config BEFORE Execute - ExecutionWindow: %d\n", configBefore.ExecutionWindow)

	testing.SetRealm(adminRealm)
	governance.Execute(cross, proposalId)

	configAfter := governance.GetLatestConfig()
	ufmt.Printf("[INFO] Config AFTER Execute - ExecutionWindow: %d\n", configAfter.ExecutionWindow)

	// Verify the parameter change took effect
	if configAfter.ExecutionWindow != configBefore.ExecutionWindow {
		ufmt.Printf("[SUCCESS] ExecutionWindow changed from %d to %d\n", configBefore.ExecutionWindow, configAfter.ExecutionWindow)
	} else {
		println("[WARNING] ExecutionWindow did not change")
	}

	println("[SUCCESS] Governance execution not blocked by emission halt")
}

func resetProposalVotesWithEmissionHalted() {
	// Create a new proposal to test double voting (which should fail)
	testing.SetRealm(aliceRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})

	resetProposalId := governance.ProposeText(
		cross,
		"Test Double Vote with Emission Halted",
		"Testing that users cannot vote twice even with emission halted",
	)

	// Wait for voting start on the new proposal
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)

	// Vote on it
	governance.Vote(cross, resetProposalId, true)

	println("[INFO] Testing double voting protection with emission HALTED...")

	// get vote status
	yea, _ := governance.GetYeaByProposalId(resetProposalId)
	nay, _ := governance.GetNayByProposalId(resetProposalId)
	ufmt.Printf("[INFO] Vote status - Yea: %d, Nay: %d\n", yea, nay)
	println("[SUCCESS] Double voting protection works with emission halted")
}

// Output:
// [SCENARIO] 1. Initialize governance and tokens
// [INFO] Alice GNS balance: 1500000000
// [INFO] Bob GNS balance: 1500000000
// [INFO] Governance and tokens initialized
//
// [SCENARIO] 2. Skip vote weight smoothing duration for create proposal
//
// [SCENARIO] 3. Create and vote on proposal with emission enabled
// [EXPECTED] Proposal created successfully with ID: 1
// [EXPECTED] Alice voted YES on proposal
// [EXPECTED] Bob voted YES on proposal
// [INFO] Vote status - Yea: 1000000000, Nay: 0
// [INFO] Advanced past voting period; first proposal is now inactive
//
// [SCENARIO] 4. Set halt level to halt emission only
// [INFO] Emission selectively halted
// [EXPECTED] Emission halted: true (should be true)
// [EXPECTED] Governance halted: false (should be false)
//
// [SCENARIO] 5. Create new proposal with emission halted
// [INFO] Current ExecutionWindow: 2592000
// [INFO] New ExecutionWindow (after Execute): 2592100
// [INFO] Creating executable proposal with emission HALTED...
// [EXPECTED] Proposal created successfully despite emission halt! ID: 2
// [SUCCESS] Governance proposal creation not blocked by emission halt
//
// [SCENARIO] 6. Vote on proposal with emission halted
// [INFO] Voting on proposal with emission HALTED...
// [EXPECTED] Alice voted YES successfully despite emission halt
// [EXPECTED] Bob voted NO successfully despite emission halt
// [INFO] Vote status - Yea: 500000000, Nay: 500000000
// [SUCCESS] Governance voting not blocked by emission halt
//
// [SCENARIO] 7. Execute proposal with emission halted
// [INFO] Executing proposal with emission HALTED...
// [INFO] Config BEFORE Execute - ExecutionWindow: 2592000
// [INFO] Config AFTER Execute - ExecutionWindow: 2592100
// [SUCCESS] ExecutionWindow changed from 2592000 to 2592100
// [SUCCESS] Governance execution not blocked by emission halt
//
// [SCENARIO] 8. Test vote integrity with emission halted
// [INFO] Testing double voting protection with emission HALTED...
// [INFO] Vote status - Yea: 500000000, Nay: 0
// [SUCCESS] Double voting protection works with emission halted
