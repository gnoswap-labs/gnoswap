// PKGPATH: gno.land/r/gnoswap/v1/main

// Scenario: Governance recovers from COMPLETE halt without admin
//
// COMPLETE halts every operation including governance. A parameter-change
// proposal whose executions all target the halt realm is exempt from the
// governance halt guard, so governance can propose, vote on, and execute it
// to unhalt the system by itself.
//
// Test cases:
//   1. Governance sets COMPLETE, all operations halted
//   2. Text proposal is blocked (halted: governance)
//   3. Non-halt parameter change is blocked (halted: governance)
//   4. Mixed halt + non-halt parameter change is blocked
//   5. Halt-only recovery proposal can be created
//   6. Vote on the recovery proposal works
//   7. Execute the recovery proposal, system goes back to NONE
//   8. Withdrawals (DecreaseLiquidity) work again
//   9. Ordinary proposals work again after recovery

package main

import (
	"chain"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath/v1"
	"gno.land/r/gnoswap/scenarioutils"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac/v1"
	_ "gno.land/r/gnoswap/rbac/v1"

	_ "gno.land/r/gnoswap/common/v1"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt/v1"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

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
	govRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance")

	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	poolAddr      = access.MustGetAddress(prbac.ROLE_POOL.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	bobAddr  = testutils.TestAddress("bob")
	bobRealm = testing.NewUserRealm(bobAddr)

	proposalCreationDelegateeAddr = testutils.TestAddress("prop-delegatee")

	barPath = "gno.land/r/onbloc/bar.BAR"
	fooPath = "gno.land/r/onbloc/foo.FOO"
	fee     = uint32(3000)

	positionId         uint64
	recoveryProposalId int64

	currentBlockTime = int64(2)

	haltRecoveryExecution = "gno.land/r/gnoswap/halt/v1*EXE*SetHaltLevel*EXE*NONE"
	nonHaltExecution      = "gno.land/r/gnoswap/gov/governance*EXE*Reconfigure*EXE*86400,604800,86400,50,1000000000,86400,2592000"
)

func main(cur realm) {
	ufmt.Println("[SCENARIO] Governance recovers from COMPLETE halt without admin")
	println()

	ufmt.Println("[STEP 1] Initialize governance, pool and position")
	initGovernancePoolAndPosition(cur)
	println()

	ufmt.Println("[STEP 2] Governance sets COMPLETE")
	setCompleteMode(cur)
	println()

	ufmt.Println("[STEP 3] Text proposal is BLOCKED in COMPLETE")
	testTextProposalBlocked(cur)
	println()

	ufmt.Println("[STEP 4] Non-halt parameter change is BLOCKED in COMPLETE")
	testNonHaltParameterChangeBlocked(cur)
	println()

	ufmt.Println("[STEP 5] Mixed halt + non-halt parameter change is BLOCKED in COMPLETE")
	testMixedParameterChangeBlocked(cur)
	println()

	ufmt.Println("[STEP 6] Halt-only recovery proposal can be created in COMPLETE")
	testRecoveryProposalCreated(cur)
	println()

	ufmt.Println("[STEP 7] Vote on recovery proposal works in COMPLETE")
	testRecoveryProposalVote(cur)
	println()

	ufmt.Println("[STEP 8] Execute recovery proposal in COMPLETE")
	testRecoveryProposalExecute(cur)
	println()

	ufmt.Println("[STEP 9] Withdrawals work again after recovery")
	testWithdrawWorksAfterRecovery(cur)
	println()

	ufmt.Println("[STEP 10] Ordinary proposals work again after recovery")
	testOrdinaryProposalWorksAfterRecovery(cur)
	println()
}

func initGovernancePoolAndPosition(cur realm) {
	testing.SetRealm(adminRealm)

	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	testing.SkipHeights(1)

	defaultTokenAmount := int64(100000000)
	bar.Transfer(cross(cur), aliceAddr, defaultTokenAmount)
	foo.Transfer(cross(cur), aliceAddr, defaultTokenAmount)

	gnsAmount := int64(2000000000)
	gns.Transfer(cross(cur), aliceAddr, gnsAmount)
	gns.Transfer(cross(cur), bobAddr, gnsAmount)

	delegatedAmount := gnsAmount / 4

	testing.SetRealm(aliceRealm)
	gns.Approve(cross(cur), govStakerAddr, INT64_MAX)
	gs.Delegate(cross(cur), aliceAddr, delegatedAmount, "")

	testing.SetRealm(bobRealm)
	gns.Approve(cross(cur), govStakerAddr, INT64_MAX)
	gs.Delegate(cross(cur), bobAddr, delegatedAmount, "")
	setupProposalCreationXGns(cur)

	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)
	pool.CreatePool(
		cross(cur),
		barPath,
		fooPath,
		fee,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross(cur), poolAddr, INT64_MAX)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)

	testing.SetOriginSend(chain.Coins{})
	id, liquidity, _, _ := position.Mint(
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
	positionId = id

	config, err := governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)

	ufmt.Printf("[INFO] Position minted with ID: %d, Liquidity: %s\n", positionId, liquidity)
	ufmt.Println("[INFO] Governance, pool and position initialized")
}

func setupProposalCreationXGns(cur realm) {
	config, err := governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}
	threshold := config.ProposalCreationThreshold
	missingAmount := threshold - xgns.BalanceOf(aliceAddr)
	if missingAmount <= 0 {
		return
	}

	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), aliceAddr, missingAmount)

	testing.SetRealm(aliceRealm)
	gs.Delegate(cross(cur), proposalCreationDelegateeAddr, missingAmount, "")
}

func setCompleteMode(cur realm) {
	testing.SetRealm(govRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelComplete)

	ufmt.Println("[INFO] COMPLETE activated by governance")
	ufmt.Printf("  - Governance: %t (should be true/blocked)\n", halt.IsHaltedGovernance())
	ufmt.Printf("  - Withdraw: %t (should be true/blocked)\n", halt.IsHaltedWithdraw())
	ufmt.Printf("  - Pool: %t (should be true/blocked)\n", halt.IsHaltedPool())
	ufmt.Printf("  - Emission: %t (should be true/blocked)\n", halt.IsHaltedEmission())
}

func testTextProposalBlocked(cur realm) {
	testing.SetRealm(aliceRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})

	uassert.AbortsContains(t, cur, "halted: governance", func() {
		governance.ProposeText(cross(cur), "Text", "Text proposal during COMPLETE")
	})

	ufmt.Println("[SUCCESS] Text proposal correctly blocked with 'halted: governance'")
}

func testNonHaltParameterChangeBlocked(cur realm) {
	testing.SetRealm(aliceRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})

	uassert.AbortsContains(t, cur, "halted: governance", func() {
		governance.ProposeParameterChange(
			cross(cur),
			"Reconfigure",
			"Non-halt parameter change during COMPLETE",
			1,
			nonHaltExecution,
		)
	})

	ufmt.Println("[SUCCESS] Non-halt parameter change correctly blocked with 'halted: governance'")
}

func testMixedParameterChangeBlocked(cur realm) {
	testing.SetRealm(aliceRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})

	uassert.AbortsContains(t, cur, "halted: governance", func() {
		governance.ProposeParameterChange(
			cross(cur),
			"Mixed",
			"Halt + non-halt parameter change during COMPLETE",
			2,
			haltRecoveryExecution+"*GOV*"+nonHaltExecution,
		)
	})

	ufmt.Println("[SUCCESS] Mixed parameter change correctly blocked with 'halted: governance'")
}

func testRecoveryProposalCreated(cur realm) {
	testing.SetRealm(aliceRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})

	recoveryProposalId = governance.ProposeParameterChange(
		cross(cur),
		"Halt Recovery",
		"Set halt level back to NONE",
		1,
		haltRecoveryExecution,
	)

	ufmt.Printf("[SUCCESS] Recovery proposal created in COMPLETE! ID: %d\n", recoveryProposalId)
}

func testRecoveryProposalVote(cur realm) {
	testing.SetRealm(adminRealm)
	config, err := governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)

	testing.SetRealm(aliceRealm)
	governance.Vote(cross(cur), recoveryProposalId, true)
	ufmt.Println("[SUCCESS] Alice voted YES on recovery proposal in COMPLETE")

	testing.SetRealm(bobRealm)
	governance.Vote(cross(cur), recoveryProposalId, true)
	ufmt.Println("[SUCCESS] Bob voted YES on recovery proposal in COMPLETE")

	yeaVotes, _ := governance.GetYeaByProposalId(recoveryProposalId)
	nayVotes, _ := governance.GetNayByProposalId(recoveryProposalId)
	ufmt.Printf("[INFO] Recovery proposal vote count - Yea: %d, Nay: %d\n", yeaVotes, nayVotes)
	ufmt.Printf("[INFO] Governance still halted: %t (should be true)\n", halt.IsHaltedGovernance())
}

func testRecoveryProposalExecute(cur realm) {
	testing.SetRealm(adminRealm)
	config, err := governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)

	statusBefore, _ := governance.GetProposalStatusByProposalId(recoveryProposalId)
	ufmt.Printf("[INFO] Proposal status BEFORE: %s\n", statusBefore)

	testing.SetRealm(aliceRealm)
	result := governance.Execute(cross(cur), recoveryProposalId)
	ufmt.Printf("[SUCCESS] Recovery proposal executed in COMPLETE! Result: %d\n", result)

	statusAfter, _ := governance.GetProposalStatusByProposalId(recoveryProposalId)
	ufmt.Printf("[INFO] Proposal status AFTER: %s\n", statusAfter)

	ufmt.Println("[INFO] Halt status after recovery:")
	ufmt.Printf("  - Governance: %t (should be false)\n", halt.IsHaltedGovernance())
	ufmt.Printf("  - Withdraw: %t (should be false)\n", halt.IsHaltedWithdraw())
	ufmt.Printf("  - Pool: %t (should be false)\n", halt.IsHaltedPool())
	ufmt.Printf("  - Position: %t (should be false)\n", halt.IsHaltedPosition())
	ufmt.Printf("  - Router: %t (should be false)\n", halt.IsHaltedRouter())
	ufmt.Printf("  - Emission: %t (should be false)\n", halt.IsHaltedEmission())
}

func testWithdrawWorksAfterRecovery(cur realm) {
	testing.SetRealm(aliceRealm)

	_, liquidity, _, _, _, _, _ := position.DecreaseLiquidity(
		cross(cur),
		positionId,
		"1000000",
		"0",
		"0",
		time.Now().Unix()+3600,
	)

	ufmt.Printf("[SUCCESS] DecreaseLiquidity works after recovery! Liquidity removed: %s\n", liquidity)
}

func testOrdinaryProposalWorksAfterRecovery(cur realm) {
	// executed proposal is no longer active, so alice can propose again
	testing.SetRealm(aliceRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})

	id := governance.ProposeText(cross(cur), "Text", "Text proposal after recovery")

	ufmt.Printf("[SUCCESS] Text proposal created after recovery! ID: %d\n", id)
}

// Output:
// [SCENARIO] Governance recovers from COMPLETE halt without admin
//
// [STEP 1] Initialize governance, pool and position
// [INFO] Position minted with ID: 1, Liquidity: 213383746
// [INFO] Governance, pool and position initialized
//
// [STEP 2] Governance sets COMPLETE
// [INFO] COMPLETE activated by governance
//   - Governance: true (should be true/blocked)
//   - Withdraw: true (should be true/blocked)
//   - Pool: true (should be true/blocked)
//   - Emission: true (should be true/blocked)
//
// [STEP 3] Text proposal is BLOCKED in COMPLETE
// [SUCCESS] Text proposal correctly blocked with 'halted: governance'
//
// [STEP 4] Non-halt parameter change is BLOCKED in COMPLETE
// [SUCCESS] Non-halt parameter change correctly blocked with 'halted: governance'
//
// [STEP 5] Mixed halt + non-halt parameter change is BLOCKED in COMPLETE
// [SUCCESS] Mixed parameter change correctly blocked with 'halted: governance'
//
// [STEP 6] Halt-only recovery proposal can be created in COMPLETE
// [SUCCESS] Recovery proposal created in COMPLETE! ID: 1
//
// [STEP 7] Vote on recovery proposal works in COMPLETE
// [SUCCESS] Alice voted YES on recovery proposal in COMPLETE
// [SUCCESS] Bob voted YES on recovery proposal in COMPLETE
// [INFO] Recovery proposal vote count - Yea: 1000000000, Nay: 0
// [INFO] Governance still halted: true (should be true)
//
// [STEP 8] Execute recovery proposal in COMPLETE
// [INFO] Proposal status BEFORE: executable
// [SUCCESS] Recovery proposal executed in COMPLETE! Result: 1
// [INFO] Proposal status AFTER: executed
// [INFO] Halt status after recovery:
//   - Governance: false (should be false)
//   - Withdraw: false (should be false)
//   - Pool: false (should be false)
//   - Position: false (should be false)
//   - Router: false (should be false)
//   - Emission: false (should be false)
//
// [STEP 9] Withdrawals work again after recovery
// [SUCCESS] DecreaseLiquidity works after recovery! Liquidity removed: 1000000
//
// [STEP 10] Ordinary proposals work again after recovery
// [SUCCESS] Text proposal created after recovery! ID: 2
