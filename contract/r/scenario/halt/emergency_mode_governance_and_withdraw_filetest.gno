// PKGPATH: gno.land/r/gnoswap/v1/main

// Scenario: Emergency Mode allows only governance and withdraw operations
//
// This test verifies that when Emergency Mode is activated:
//   - Governance operations continue to work (for emergency recovery)
//   - Withdraw operations are allowed (OpTypeWithdraw: false)
//   - Most other operations are blocked
//
// Emergency Mode configuration (from config.gno):
//   - OpTypeGovernance: false (ALLOWED)
//   - OpTypeWithdraw: false (ALLOWED)
//   - All other operations: true (BLOCKED)
//
// Important note:
//   Functions like position.DecreaseLiquidity check BOTH:
//     - halt.AssertIsNotHaltedPosition() AND
//     - halt.AssertIsNotHaltedWithdraw()
//   So even though Withdraw is allowed, Position is blocked, causing panic.
//
// Test cases:
//   1. Pool creation is blocked (pool halted)
//   2. Position mint is blocked (position halted)
//   3. Router swap is blocked (router halted)
//   4. Governance propose works (governance not halted)
//   5. Governance vote works (governance not halted)
//   6. TextProposal execute fails (text proposals cannot be executed)
//   7. ParameterChange proposal works and can be executed
//   8. Proposal status is correctly updated after execution

package main

import (
	"gno.land/p/gnoswap/gnsmath"
	"chain"
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"
	gs "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	"gno.land/r/gnoswap/gov/xgns"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const INT64_MAX int64 = 9223372036854775807

var t *testing.T

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	poolAddr      = access.MustGetAddress(prbac.ROLE_POOL.String())
	routerAddr    = access.MustGetAddress(prbac.ROLE_ROUTER.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	bobAddr  = testutils.TestAddress("bob")
	bobRealm = testing.NewUserRealm(bobAddr)

	proposalCreationDelegateeAddr = testutils.TestAddress("prop-delegatee")

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee     = uint32(3000)

	textProposalId            int64
	parameterChangeProposalId int64

	currentBlockTime = int64(2)
)

func main(cur realm) {
	ufmt.Println("[SCENARIO] Emergency Mode allows only governance and withdraw operations")
	println()

	ufmt.Println("[STEP 1] Initialize governance, pool and tokens")
	initGovernancePoolAndTokens(cur)
	println()

	ufmt.Println("[STEP 2] Create pool and position before Emergency Mode")
	createPoolAndPosition(cur)
	println()

	ufmt.Println("[STEP 3] Set halt level to Emergency Mode")
	setEmergencyMode(cur)
	println()

	ufmt.Println("[STEP 4] Test: Pool creation is BLOCKED in Emergency Mode")
	testPoolCreationBlocked(cur)
	println()

	ufmt.Println("[STEP 5] Test: Position mint is BLOCKED in Emergency Mode")
	testPositionMintBlocked(cur)
	println()

	ufmt.Println("[STEP 6] Test: Router swap is BLOCKED in Emergency Mode")
	testRouterSwapBlocked(cur)
	println()

	ufmt.Println("[STEP 7] Test: Governance propose works in Emergency Mode (TextProposal)")
	testGovernanceProposeTextWorks(cur)
	println()

	ufmt.Println("[STEP 8] Test: Governance vote works in Emergency Mode (TextProposal)")
	testGovernanceVoteTextWorks(cur)
	println()

	ufmt.Println("[STEP 9] Test: TextProposal execute FAILS (text proposals cannot be executed)")
	testTextProposalExecuteFails(cur)
	println()

	ufmt.Println("[STEP 10] Test: Governance propose works in Emergency Mode (ParameterChange)")
	testGovernanceProposeParameterChangeWorks(cur)
	println()

	ufmt.Println("[STEP 11] Test: Governance vote works in Emergency Mode (ParameterChange)")
	testGovernanceVoteParameterChangeWorks(cur)
	println()

	ufmt.Println("[STEP 12] Test: ParameterChange proposal execute SUCCEEDS in Emergency Mode")
	testParameterChangeProposalExecuteWorks(cur)
	println()

	ufmt.Println("[STEP 13] Verify proposal status after execution")
	verifyProposalStatusAfterExecution(cur)
	println()

	ufmt.Println("[STEP 14] Verify halt status summary")
	verifyHaltStatusSummary(cur)
	println()
}

func initGovernancePoolAndTokens(cur realm) {
	testing.SetRealm(adminRealm)

	// Initialize emission
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	testing.SkipHeights(1)

	// Distribute tokens to alice and bob
	defaultTokenAmount := int64(100000000)
	bar.Transfer(cross(cur), aliceAddr, defaultTokenAmount)
	foo.Transfer(cross(cur), aliceAddr, defaultTokenAmount)
	bar.Transfer(cross(cur), bobAddr, defaultTokenAmount)
	foo.Transfer(cross(cur), bobAddr, defaultTokenAmount)

	// Distribute GNS tokens for governance
	gnsAmount := int64(2000000000)
	gns.Transfer(cross(cur), aliceAddr, gnsAmount)
	gns.Transfer(cross(cur), bobAddr, gnsAmount)

	// Delegate GNS tokens for voting power
	delegatedAmount := gnsAmount / 4

	testing.SetRealm(aliceRealm)
	gns.Approve(cross(cur), govStakerAddr, INT64_MAX)
	gs.Delegate(cross(cur), aliceAddr, delegatedAmount, "")

	testing.SetRealm(bobRealm)
	gns.Approve(cross(cur), govStakerAddr, INT64_MAX)
	gs.Delegate(cross(cur), bobAddr, delegatedAmount, "")
	setupProposalCreationXGns(cur)

	ufmt.Printf("[INFO] Alice GNS balance: %d\n", gns.BalanceOf(aliceAddr))
	ufmt.Printf("[INFO] Bob GNS balance: %d\n", gns.BalanceOf(bobAddr))
	ufmt.Println("[INFO] Governance and tokens initialized")
}

func setupProposalCreationXGns(cur realm) {
	threshold := governance.GetLatestConfig().ProposalCreationThreshold
	missingAmount := threshold - xgns.BalanceOf(aliceAddr)
	if missingAmount <= 0 {
		return
	}

	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), aliceAddr, missingAmount)

	testing.SetRealm(aliceRealm)
	gs.Delegate(cross(cur), proposalCreationDelegateeAddr, missingAmount, "")
}

func createPoolAndPosition(cur realm) {
	testing.SetRealm(adminRealm)

	// Create pool
	pool.SetPoolCreationFee(cross(cur), 0)
	pool.CreatePool(
		cross(cur),
		barPath,
		fooPath,
		fee,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
	ufmt.Println("[INFO] Pool created: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000")

	// Mint position
	testing.SetRealm(aliceRealm)
	bar.Approve(cross(cur), poolAddr, INT64_MAX)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)

	testing.SetOriginSend(chain.Coins{})
	positionId, liquidity, _, _ := position.Mint(
		cross(cur),
		barPath,
		fooPath,
		fee,
		-960,
		960,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		"",
	)

	ufmt.Printf("[INFO] Position minted with ID: %d, Liquidity: %s\n", positionId, liquidity)

	// Skip voting weight smoothing duration
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
}

func setEmergencyMode(cur realm) {
	testing.SetRealm(adminRealm)

	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)

	ufmt.Println("[INFO] Emergency Mode activated")
	ufmt.Println("[INFO] Halt status for each operation:")
	ufmt.Printf("  - Pool: %t (should be true/blocked)\n", halt.IsHaltedPool())
	ufmt.Printf("  - Position: %t (should be true/blocked)\n", halt.IsHaltedPosition())
	ufmt.Printf("  - Router: %t (should be true/blocked)\n", halt.IsHaltedRouter())
	ufmt.Printf("  - Staker: %t (should be true/blocked)\n", halt.IsHaltedStaker())
	ufmt.Printf("  - Governance: %t (should be false/allowed)\n", halt.IsHaltedGovernance())
	ufmt.Printf("  - Withdraw: %t (should be false/allowed)\n", halt.IsHaltedWithdraw())
}

func testPoolCreationBlocked(cur realm) {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Attempting to create pool in Emergency Mode (should abort)...")

	uassert.AbortsContains(t, cur, "halted: pool", func() {
		pool.CreatePool(
			cross(cur),
			barPath,
			fooPath,
			uint32(500), // different fee tier
			gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
		)
	})

	ufmt.Println("[SUCCESS] Pool creation correctly blocked with 'halted: pool'")
}

func testPositionMintBlocked(cur realm) {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Attempting to mint position in Emergency Mode (should abort)...")

	uassert.AbortsContains(t, cur, "halted: position", func() {
		testing.SetOriginSend(chain.Coins{})
		position.Mint(
			cross(cur),
			barPath,
			fooPath,
			fee,
			-1920,
			1920,
			"1000000",
			"1000000",
			"0",
			"0",
			time.Now().Unix()+3600,
			aliceAddr,
			"",
		)
	})

	ufmt.Println("[SUCCESS] Position mint correctly blocked with 'halted: position'")
}

func testRouterSwapBlocked(cur realm) {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross(cur), routerAddr, INT64_MAX)
	foo.Approve(cross(cur), routerAddr, INT64_MAX)

	ufmt.Println("[INFO] Attempting router swap in Emergency Mode (should abort)...")

	uassert.AbortsContains(t, cur, "halted: router", func() {
		testing.SetOriginSend(chain.Coins{})
		router.ExactInSwapRoute(
			cross(cur),
			barPath,
			fooPath,
			"100000",
			"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
			"100",
			"0",
			time.Now().Unix()+3600,
			"",
		)
	})

	ufmt.Println("[SUCCESS] Router swap correctly blocked with 'halted: router'")
}

func testGovernanceProposeTextWorks(cur realm) {
	testing.SetRealm(aliceRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})

	ufmt.Println("[INFO] Attempting to create TextProposal in Emergency Mode...")

	textProposalId = governance.ProposeText(
		cross(cur),
		"Emergency Recovery Proposal",
		"This proposal is created during Emergency Mode to test governance functionality",
	)

	ufmt.Printf("[SUCCESS] TextProposal created in Emergency Mode! ID: %d\n", textProposalId)
	ufmt.Println("[SUCCESS] Governance propose (TextProposal) correctly works in Emergency Mode")
}

func testGovernanceVoteTextWorks(cur realm) {
	// Skip to voting start
	testing.SetRealm(adminRealm)
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)

	ufmt.Println("[INFO] Attempting to vote on TextProposal in Emergency Mode...")

	// Alice votes YES
	testing.SetRealm(aliceRealm)
	governance.Vote(cross(cur), textProposalId, true)
	ufmt.Println("[SUCCESS] Alice voted YES on TextProposal in Emergency Mode")

	// Bob votes YES
	testing.SetRealm(bobRealm)
	governance.Vote(cross(cur), textProposalId, true)
	ufmt.Println("[SUCCESS] Bob voted YES on TextProposal in Emergency Mode")

	// Check voting info using non-JSON getters
	yeaVotes, _ := governance.GetYeaByProposalId(textProposalId)
	nayVotes, _ := governance.GetNayByProposalId(textProposalId)
	ufmt.Printf("[INFO] TextProposal vote count - Yea: %d, Nay: %d\n", yeaVotes, nayVotes)
	ufmt.Println("[SUCCESS] Governance voting (TextProposal) correctly works in Emergency Mode")
}

func testTextProposalExecuteFails(cur realm) {
	// Skip voting period for ready to execute
	testing.SetRealm(adminRealm)
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)

	ufmt.Println("[INFO] Attempting to execute TextProposal in Emergency Mode (should fail)...")
	ufmt.Printf("[INFO] TextProposal ID: %d\n", textProposalId)

	// TextProposal execution should fail because text proposals cannot be executed
	uassert.AbortsContains(t, cur, "cannot execute text proposal", func() {
		governance.Execute(cross(cur), textProposalId)
	})

	ufmt.Println("[SUCCESS] TextProposal execution correctly failed with 'cannot execute text proposal'")
}

func testGovernanceProposeParameterChangeWorks(cur realm) {
	testing.SetRealm(aliceRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})

	ufmt.Println("[INFO] Attempting to create ParameterChange proposal in Emergency Mode...")

	parameterChangeProposalId = governance.ProposeParameterChange(
		cross(cur),
		"Emergency Parameter Change",
		"This ParameterChange proposal is created during Emergency Mode to test execute functionality",
		1,
		"gno.land/r/gnoswap/gov/governance*EXE*Reconfigure*EXE*86400,604800,86400,50,1000000000,86400,2592000",
	)

	ufmt.Printf("[SUCCESS] ParameterChange proposal created in Emergency Mode! ID: %d\n", parameterChangeProposalId)
	ufmt.Println("[SUCCESS] Governance propose (ParameterChange) correctly works in Emergency Mode")
}

func testGovernanceVoteParameterChangeWorks(cur realm) {
	// Skip to voting start
	testing.SetRealm(adminRealm)
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)

	ufmt.Println("[INFO] Attempting to vote on ParameterChange proposal in Emergency Mode...")

	// Alice votes YES
	testing.SetRealm(aliceRealm)
	governance.Vote(cross(cur), parameterChangeProposalId, true)
	ufmt.Println("[SUCCESS] Alice voted YES on ParameterChange proposal in Emergency Mode")

	// Bob votes YES
	testing.SetRealm(bobRealm)
	governance.Vote(cross(cur), parameterChangeProposalId, true)
	ufmt.Println("[SUCCESS] Bob voted YES on ParameterChange proposal in Emergency Mode")

	// Check voting info using non-JSON getters
	yeaVotes, _ := governance.GetYeaByProposalId(parameterChangeProposalId)
	nayVotes, _ := governance.GetNayByProposalId(parameterChangeProposalId)
	ufmt.Printf("[INFO] ParameterChange proposal vote count - Yea: %d, Nay: %d\n", yeaVotes, nayVotes)
	ufmt.Println("[SUCCESS] Governance voting (ParameterChange) correctly works in Emergency Mode")
}

func testParameterChangeProposalExecuteWorks(cur realm) {
	// Skip voting period for ready to execute
	testing.SetRealm(adminRealm)
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)

	ufmt.Println("[INFO] Attempting to execute ParameterChange proposal in Emergency Mode...")
	ufmt.Printf("[INFO] ParameterChange proposal ID: %d\n", parameterChangeProposalId)

	// Get state before execution
	executionStateBefore, _ := governance.GetProposalStatusByProposalId(parameterChangeProposalId)
	ufmt.Printf("[INFO] Execution state BEFORE: %s\n", executionStateBefore)

	// Execute the ParameterChange proposal
	testing.SetRealm(aliceRealm)
	result := governance.Execute(cross(cur), parameterChangeProposalId)

	ufmt.Printf("[SUCCESS] ParameterChange proposal executed in Emergency Mode! Result: %d\n", result)
	ufmt.Println("[SUCCESS] Governance execute (ParameterChange) correctly works in Emergency Mode")
}

func verifyProposalStatusAfterExecution(cur realm) {
	testing.SetRealm(adminRealm)
	ufmt.Println("[INFO] Verifying proposal execution state after execution...")

	// Check TextProposal execution state (should still be executable/passed, not executed)
	textExecutionState, _ := governance.GetProposalStatusByProposalId(textProposalId)
	ufmt.Printf("[INFO] TextProposal (ID: %d) - Execution State: %s\n", textProposalId, textExecutionState)

	// Check ParameterChange proposal execution state (should be executed)
	paramChangeExecutionState, _ := governance.GetProposalStatusByProposalId(parameterChangeProposalId)
	ufmt.Printf("[INFO] ParameterChange Proposal (ID: %d) - Execution State: %s\n", parameterChangeProposalId, paramChangeExecutionState)

	ufmt.Println("[SUCCESS] Proposal execution state verification completed")
}

func verifyHaltStatusSummary(cur realm) {
	ufmt.Println("[INFO] Final halt status summary:")
	ufmt.Println("  Operations BLOCKED (halted: true):")
	ufmt.Printf("    - Pool: %t\n", halt.IsHaltedPool())
	ufmt.Printf("    - Position: %t\n", halt.IsHaltedPosition())
	ufmt.Printf("    - ProtocolFee: %t\n", halt.IsHaltedProtocolFee())
	ufmt.Printf("    - Router: %t\n", halt.IsHaltedRouter())
	ufmt.Printf("    - Staker: %t\n", halt.IsHaltedStaker())
	ufmt.Printf("    - Launchpad: %t\n", halt.IsHaltedLaunchpad())
	ufmt.Printf("    - GovStaker: %t\n", halt.IsHaltedGovStaker())
	ufmt.Printf("    - XGns: %t\n", halt.IsHaltedXGns())
	ufmt.Printf("    - CommunityPool: %t\n", halt.IsHaltedCommunityPool())
	ufmt.Printf("    - Emission: %t\n", halt.IsHaltedEmission())
	ufmt.Println("  Operations ALLOWED (halted: false):")
	ufmt.Printf("    - Governance: %t\n", halt.IsHaltedGovernance())
	ufmt.Printf("    - Withdraw: %t\n", halt.IsHaltedWithdraw())
}

// Output:
// [SCENARIO] Emergency Mode allows only governance and withdraw operations
//
// [STEP 1] Initialize governance, pool and tokens
// [INFO] Alice GNS balance: 1500000000
// [INFO] Bob GNS balance: 1500000000
// [INFO] Governance and tokens initialized
//
// [STEP 2] Create pool and position before Emergency Mode
// [INFO] Pool created: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000
// [INFO] Position minted with ID: 1, Liquidity: 213383746
//
// [STEP 3] Set halt level to Emergency Mode
// [INFO] Emergency Mode activated
// [INFO] Halt status for each operation:
//   - Pool: true (should be true/blocked)
//   - Position: true (should be true/blocked)
//   - Router: true (should be true/blocked)
//   - Staker: true (should be true/blocked)
//   - Governance: false (should be false/allowed)
//   - Withdraw: false (should be false/allowed)
//
// [STEP 4] Test: Pool creation is BLOCKED in Emergency Mode
// [INFO] Attempting to create pool in Emergency Mode (should abort)...
// [SUCCESS] Pool creation correctly blocked with 'halted: pool'
//
// [STEP 5] Test: Position mint is BLOCKED in Emergency Mode
// [INFO] Attempting to mint position in Emergency Mode (should abort)...
// [SUCCESS] Position mint correctly blocked with 'halted: position'
//
// [STEP 6] Test: Router swap is BLOCKED in Emergency Mode
// [INFO] Attempting router swap in Emergency Mode (should abort)...
// [SUCCESS] Router swap correctly blocked with 'halted: router'
//
// [STEP 7] Test: Governance propose works in Emergency Mode (TextProposal)
// [INFO] Attempting to create TextProposal in Emergency Mode...
// [SUCCESS] TextProposal created in Emergency Mode! ID: 1
// [SUCCESS] Governance propose (TextProposal) correctly works in Emergency Mode
//
// [STEP 8] Test: Governance vote works in Emergency Mode (TextProposal)
// [INFO] Attempting to vote on TextProposal in Emergency Mode...
// [SUCCESS] Alice voted YES on TextProposal in Emergency Mode
// [SUCCESS] Bob voted YES on TextProposal in Emergency Mode
// [INFO] TextProposal vote count - Yea: 1000000000, Nay: 0
// [SUCCESS] Governance voting (TextProposal) correctly works in Emergency Mode
//
// [STEP 9] Test: TextProposal execute FAILS (text proposals cannot be executed)
// [INFO] Attempting to execute TextProposal in Emergency Mode (should fail)...
// [INFO] TextProposal ID: 1
// [SUCCESS] TextProposal execution correctly failed with 'cannot execute text proposal'
//
// [STEP 10] Test: Governance propose works in Emergency Mode (ParameterChange)
// [INFO] Attempting to create ParameterChange proposal in Emergency Mode...
// [SUCCESS] ParameterChange proposal created in Emergency Mode! ID: 2
// [SUCCESS] Governance propose (ParameterChange) correctly works in Emergency Mode
//
// [STEP 11] Test: Governance vote works in Emergency Mode (ParameterChange)
// [INFO] Attempting to vote on ParameterChange proposal in Emergency Mode...
// [SUCCESS] Alice voted YES on ParameterChange proposal in Emergency Mode
// [SUCCESS] Bob voted YES on ParameterChange proposal in Emergency Mode
// [INFO] ParameterChange proposal vote count - Yea: 1000000000, Nay: 0
// [SUCCESS] Governance voting (ParameterChange) correctly works in Emergency Mode
//
// [STEP 12] Test: ParameterChange proposal execute SUCCEEDS in Emergency Mode
// [INFO] Attempting to execute ParameterChange proposal in Emergency Mode...
// [INFO] ParameterChange proposal ID: 2
// [INFO] Execution state BEFORE: executable
// [SUCCESS] ParameterChange proposal executed in Emergency Mode! Result: 2
// [SUCCESS] Governance execute (ParameterChange) correctly works in Emergency Mode
//
// [STEP 13] Verify proposal status after execution
// [INFO] Verifying proposal execution state after execution...
// [INFO] TextProposal (ID: 1) - Execution State: passed
// [INFO] ParameterChange Proposal (ID: 2) - Execution State: executed
// [SUCCESS] Proposal execution state verification completed
//
// [STEP 14] Verify halt status summary
// [INFO] Final halt status summary:
//   Operations BLOCKED (halted: true):
//     - Pool: true
//     - Position: true
//     - ProtocolFee: true
//     - Router: true
//     - Staker: true
//     - Launchpad: true
//     - GovStaker: true
//     - XGns: true
//     - CommunityPool: true
//     - Emission: true
//   Operations ALLOWED (halted: false):
//     - Governance: false
//     - Withdraw: false
