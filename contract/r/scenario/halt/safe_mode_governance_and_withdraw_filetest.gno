// Scenario: Safe Mode allows governance and non-withdraw operations

package main

import (
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
	"gno.land/r/gnoswap/common"
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

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee     = uint32(3000)

	textProposalId            int64
	parameterChangeProposalId int64

	currentBlockTime = int64(2)
)

func main() {
	ufmt.Println("[SCENARIO] Safe Mode allows governance and non-withdraw operations")
	println()

	ufmt.Println("[STEP 1] Initialize governance, pool and tokens")
	initGovernancePoolAndTokens()
	println()

	ufmt.Println("[STEP 2] Create pool and position before Safe Mode")
	createPoolAndPosition()
	println()

	ufmt.Println("[STEP 3] Set halt level to Safe Mode")
	setSafeMode()
	println()

	ufmt.Println("[STEP 4] Test: Pool creation works in Safe Mode")
	testPoolCreationAllowed()
	println()

	ufmt.Println("[STEP 5] Test: Position mint works in Safe Mode")
	testPositionMintAllowed()
	println()

	ufmt.Println("[STEP 6] Test: Router swap works in Safe Mode")
	testRouterSwapAllowed()
	println()

	ufmt.Println("[STEP 7] Test: Governance propose works in Safe Mode (TextProposal)")
	testGovernanceProposeTextWorks()
	println()

	ufmt.Println("[STEP 8] Test: Governance vote works in Safe Mode (TextProposal)")
	testGovernanceVoteTextWorks()
	println()

	ufmt.Println("[STEP 9] Test: TextProposal execute FAILS (text proposals cannot be executed)")
	testTextProposalExecuteFails()
	println()

	ufmt.Println("[STEP 10] Test: Governance propose works in Safe Mode (ParameterChange)")
	testGovernanceProposeParameterChangeWorks()
	println()

	ufmt.Println("[STEP 11] Test: Governance vote works in Safe Mode (ParameterChange)")
	testGovernanceVoteParameterChangeWorks()
	println()

	ufmt.Println("[STEP 12] Test: ParameterChange proposal execute SUCCEEDS in Safe Mode")
	testParameterChangeProposalExecuteWorks()
	println()

	ufmt.Println("[STEP 13] Verify proposal status after execution")
	verifyProposalStatusAfterExecution()
	println()

	ufmt.Println("[STEP 14] Verify halt status summary")
	verifyHaltStatusSummary()
	println()
}

func initGovernancePoolAndTokens() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	testing.SkipHeights(1)

	defaultTokenAmount := int64(100000000)
	bar.Transfer(cross, aliceAddr, defaultTokenAmount)
	foo.Transfer(cross, aliceAddr, defaultTokenAmount)
	bar.Transfer(cross, bobAddr, defaultTokenAmount)
	foo.Transfer(cross, bobAddr, defaultTokenAmount)

	gnsAmount := int64(2000000000)
	gns.Transfer(cross, aliceAddr, gnsAmount)
	gns.Transfer(cross, bobAddr, gnsAmount)

	delegatedAmount := gnsAmount / 4

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

func createPoolAndPosition() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)
	pool.CreatePool(cross, barPath, fooPath, fee, common.TickMathGetSqrtRatioAtTick(0).ToString())
	ufmt.Println("[INFO] Pool created: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000")

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)
	testing.SetOriginSend(chain.Coins{})
	positionId, liquidity, _, _ := position.Mint(
		cross,
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
		aliceAddr,
		"",
	)
	ufmt.Printf("[INFO] Position minted with ID: %d, Liquidity: %s\n", positionId, liquidity)

	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
}

func setSafeMode() {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelSafeMode)

	ufmt.Println("[INFO] Safe Mode activated")
	ufmt.Println("[INFO] Halt status for each operation:")
	ufmt.Printf("  - Pool: %t (should be false/allowed)\n", halt.IsHaltedPool())
	ufmt.Printf("  - Position: %t (should be false/allowed)\n", halt.IsHaltedPosition())
	ufmt.Printf("  - Router: %t (should be false/allowed)\n", halt.IsHaltedRouter())
	ufmt.Printf("  - Staker: %t (should be false/allowed)\n", halt.IsHaltedStaker())
	ufmt.Printf("  - Governance: %t (should be false/allowed)\n", halt.IsHaltedGovernance())
	ufmt.Printf("  - Withdraw: %t (should be true/blocked)\n", halt.IsHaltedWithdraw())
}

func testPoolCreationAllowed() {
	testing.SetRealm(adminRealm)
	ufmt.Println("[INFO] Attempting to create pool in Safe Mode...")
	pool.CreatePool(cross, barPath, fooPath, uint32(500), common.TickMathGetSqrtRatioAtTick(0).ToString())
	ufmt.Println("[SUCCESS] Pool creation correctly works in Safe Mode")
}

func testPositionMintAllowed() {
	testing.SetRealm(aliceRealm)
	ufmt.Println("[INFO] Attempting to mint position in Safe Mode...")
	testing.SetOriginSend(chain.Coins{})
	positionId, liquidity, _, _ := position.Mint(
		cross,
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
		aliceAddr,
		"",
	)
	ufmt.Printf("[SUCCESS] Position minted in Safe Mode! ID: %d, Liquidity: %s\n", positionId, liquidity)
}

func testRouterSwapAllowed() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, routerAddr, INT64_MAX)
	foo.Approve(cross, routerAddr, INT64_MAX)
	ufmt.Println("[INFO] Attempting router swap in Safe Mode...")
	testing.SetOriginSend(chain.Coins{})
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		barPath,
		fooPath,
		"100000",
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
		"100",
		"0",
		time.Now().Unix()+3600,
		"",
	)
	ufmt.Printf("[SUCCESS] Router swap works in Safe Mode! AmountIn: %s, AmountOut: %s\n", amountIn, amountOut)
}

func testGovernanceProposeTextWorks() {
	testing.SetRealm(aliceRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})
	ufmt.Println("[INFO] Attempting to create TextProposal in Safe Mode...")
	textProposalId = governance.ProposeText(cross, "Safe Mode Proposal", "This proposal is created during Safe Mode to test governance functionality")
	ufmt.Printf("[SUCCESS] TextProposal created in Safe Mode! ID: %d\n", textProposalId)
	ufmt.Println("[SUCCESS] Governance propose (TextProposal) correctly works in Safe Mode")
}

func testGovernanceVoteTextWorks() {
	testing.SetRealm(adminRealm)
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	ufmt.Println("[INFO] Attempting to vote on TextProposal in Safe Mode...")
	testing.SetRealm(aliceRealm)
	governance.Vote(cross, textProposalId, true)
	ufmt.Println("[SUCCESS] Alice voted YES on TextProposal in Safe Mode")
	testing.SetRealm(bobRealm)
	governance.Vote(cross, textProposalId, true)
	ufmt.Println("[SUCCESS] Bob voted YES on TextProposal in Safe Mode")
	yeaVotes, _ := governance.GetYeaByProposalId(textProposalId)
	nayVotes, _ := governance.GetNayByProposalId(textProposalId)
	ufmt.Printf("[INFO] TextProposal vote count - Yea: %d, Nay: %d\n", yeaVotes, nayVotes)
	ufmt.Println("[SUCCESS] Governance voting (TextProposal) correctly works in Safe Mode")
}

func testTextProposalExecuteFails() {
	testing.SetRealm(adminRealm)
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)
	ufmt.Println("[INFO] Attempting to execute TextProposal in Safe Mode (should fail)...")
	ufmt.Printf("[INFO] TextProposal ID: %d\n", textProposalId)
	uassert.AbortsContains(t, "cannot execute text proposal", func() {
		governance.Execute(cross, textProposalId)
	})
	ufmt.Println("[SUCCESS] TextProposal execution correctly failed with 'cannot execute text proposal'")
}

func testGovernanceProposeParameterChangeWorks() {
	testing.SetRealm(aliceRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})
	ufmt.Println("[INFO] Attempting to create ParameterChange proposal in Safe Mode...")
	parameterChangeProposalId = governance.ProposeParameterChange(
		cross,
		"Safe Parameter Change",
		"This ParameterChange proposal is created during Safe Mode to test execute functionality",
		1,
		"gno.land/r/gnoswap/gov/governance*EXE*Reconfigure*EXE*86400,604800,86400,50,1000000000,86400,2592000",
	)
	ufmt.Printf("[SUCCESS] ParameterChange proposal created in Safe Mode! ID: %d\n", parameterChangeProposalId)
	ufmt.Println("[SUCCESS] Governance propose (ParameterChange) correctly works in Safe Mode")
}

func testGovernanceVoteParameterChangeWorks() {
	testing.SetRealm(adminRealm)
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	ufmt.Println("[INFO] Attempting to vote on ParameterChange proposal in Safe Mode...")
	testing.SetRealm(aliceRealm)
	governance.Vote(cross, parameterChangeProposalId, true)
	ufmt.Println("[SUCCESS] Alice voted YES on ParameterChange proposal in Safe Mode")
	testing.SetRealm(bobRealm)
	governance.Vote(cross, parameterChangeProposalId, true)
	ufmt.Println("[SUCCESS] Bob voted YES on ParameterChange proposal in Safe Mode")
	yeaVotes, _ := governance.GetYeaByProposalId(parameterChangeProposalId)
	nayVotes, _ := governance.GetNayByProposalId(parameterChangeProposalId)
	ufmt.Printf("[INFO] ParameterChange proposal vote count - Yea: %d, Nay: %d\n", yeaVotes, nayVotes)
	ufmt.Println("[SUCCESS] Governance voting (ParameterChange) correctly works in Safe Mode")
}

func testParameterChangeProposalExecuteWorks() {
	testing.SetRealm(adminRealm)
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)
	ufmt.Println("[INFO] Attempting to execute ParameterChange proposal in Safe Mode...")
	ufmt.Printf("[INFO] ParameterChange proposal ID: %d\n", parameterChangeProposalId)
	executionStateBefore, _ := governance.GetProposalStatusByProposalId(parameterChangeProposalId)
	ufmt.Printf("[INFO] Execution state BEFORE: %s\n", executionStateBefore)
	testing.SetRealm(aliceRealm)
	result := governance.Execute(cross, parameterChangeProposalId)
	ufmt.Printf("[SUCCESS] ParameterChange proposal executed in Safe Mode! Result: %d\n", result)
	ufmt.Println("[SUCCESS] Governance execute (ParameterChange) correctly works in Safe Mode")
}

func verifyProposalStatusAfterExecution() {
	testing.SetRealm(adminRealm)
	ufmt.Println("[INFO] Verifying proposal execution state after execution...")
	textExecutionState, _ := governance.GetProposalStatusByProposalId(textProposalId)
	ufmt.Printf("[INFO] TextProposal (ID: %d) - Execution State: %s\n", textProposalId, textExecutionState)
	paramChangeExecutionState, _ := governance.GetProposalStatusByProposalId(parameterChangeProposalId)
	ufmt.Printf("[INFO] ParameterChange Proposal (ID: %d) - Execution State: %s\n", parameterChangeProposalId, paramChangeExecutionState)
	ufmt.Println("[SUCCESS] Proposal execution state verification completed")
}

func verifyHaltStatusSummary() {
	ufmt.Println("[INFO] Final halt status summary:")
	ufmt.Println("  Operations BLOCKED (halted: true):")
	ufmt.Printf("    - Withdraw: %t\n", halt.IsHaltedWithdraw())
	ufmt.Println("  Operations ALLOWED (halted: false):")
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
	ufmt.Printf("    - Governance: %t\n", halt.IsHaltedGovernance())
	ufmt.Printf("    - Withdraw: %t\n", halt.IsHaltedWithdraw())
	}

// Output:
// [SCENARIO] Safe Mode allows governance and non-withdraw operations
//
// [STEP 1] Initialize governance, pool and tokens
// [INFO] Alice GNS balance: 1500000000
// [INFO] Bob GNS balance: 1500000000
// [INFO] Governance and tokens initialized
//
// [STEP 2] Create pool and position before Safe Mode
// [INFO] Pool created: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000
// [INFO] Position minted with ID: 1, Liquidity: 213383746
//
// [STEP 3] Set halt level to Safe Mode
// [INFO] Safe Mode activated
// [INFO] Halt status for each operation:
//   - Pool: false (should be false/allowed)
//   - Position: false (should be false/allowed)
//   - Router: false (should be false/allowed)
//   - Staker: false (should be false/allowed)
//   - Governance: false (should be false/allowed)
//   - Withdraw: true (should be true/blocked)
//
// [STEP 4] Test: Pool creation works in Safe Mode
// [INFO] Attempting to create pool in Safe Mode...
// [SUCCESS] Pool creation correctly works in Safe Mode
//
// [STEP 5] Test: Position mint works in Safe Mode
// [INFO] Attempting to mint position in Safe Mode...
// [SUCCESS] Position minted in Safe Mode! ID: 2, Liquidity: 10925185
//
// [STEP 6] Test: Router swap works in Safe Mode
// [INFO] Attempting router swap in Safe Mode...
// [SUCCESS] Router swap works in Safe Mode! AmountIn: 100000, AmountOut: -99506
//
// [STEP 7] Test: Governance propose works in Safe Mode (TextProposal)
// [INFO] Attempting to create TextProposal in Safe Mode...
// [SUCCESS] TextProposal created in Safe Mode! ID: 1
// [SUCCESS] Governance propose (TextProposal) correctly works in Safe Mode
//
// [STEP 8] Test: Governance vote works in Safe Mode (TextProposal)
// [INFO] Attempting to vote on TextProposal in Safe Mode...
// [SUCCESS] Alice voted YES on TextProposal in Safe Mode
// [SUCCESS] Bob voted YES on TextProposal in Safe Mode
// [INFO] TextProposal vote count - Yea: 1000000000, Nay: 0
// [SUCCESS] Governance voting (TextProposal) correctly works in Safe Mode
//
// [STEP 9] Test: TextProposal execute FAILS (text proposals cannot be executed)
// [INFO] Attempting to execute TextProposal in Safe Mode (should fail)...
// [INFO] TextProposal ID: 1
// [SUCCESS] TextProposal execution correctly failed with 'cannot execute text proposal'
//
// [STEP 10] Test: Governance propose works in Safe Mode (ParameterChange)
// [INFO] Attempting to create ParameterChange proposal in Safe Mode...
// [SUCCESS] ParameterChange proposal created in Safe Mode! ID: 2
// [SUCCESS] Governance propose (ParameterChange) correctly works in Safe Mode
//
// [STEP 11] Test: Governance vote works in Safe Mode (ParameterChange)
// [INFO] Attempting to vote on ParameterChange proposal in Safe Mode...
// [SUCCESS] Alice voted YES on ParameterChange proposal in Safe Mode
// [SUCCESS] Bob voted YES on ParameterChange proposal in Safe Mode
// [INFO] ParameterChange proposal vote count - Yea: 1000000000, Nay: 0
// [SUCCESS] Governance voting (ParameterChange) correctly works in Safe Mode
//
// [STEP 12] Test: ParameterChange proposal execute SUCCEEDS in Safe Mode
// [INFO] Attempting to execute ParameterChange proposal in Safe Mode...
// [INFO] ParameterChange proposal ID: 2
// [INFO] Execution state BEFORE: executable
// [SUCCESS] ParameterChange proposal executed in Safe Mode! Result: 2
// [SUCCESS] Governance execute (ParameterChange) correctly works in Safe Mode
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
//     - Withdraw: true
//   Operations ALLOWED (halted: false):
//     - Pool: false
//     - Position: false
//     - ProtocolFee: false
//     - Router: false
//     - Staker: false
//     - Launchpad: false
//     - GovStaker: false
//     - XGns: false
//     - CommunityPool: false
//     - Emission: false
//     - Governance: false
//     - Withdraw: true
