// Scenario: Emergency Mode blocks core growth functions across contracts

package main

import (
	"chain"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	govstaker "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	xgns "gno.land/r/gnoswap/gov/xgns"
	"gno.land/r/gnoswap/halt"
	launchpad "gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"
	"gno.land/r/gnoswap/pool"
	_ "gno.land/r/gnoswap/pool/v1"
	"gno.land/r/gnoswap/position"
	_ "gno.land/r/gnoswap/position/v1"
	protocolfee "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	"gno.land/r/gnoswap/router"
	_ "gno.land/r/gnoswap/router/v1"
	staker "gno.land/r/gnoswap/staker"
	_ "gno.land/r/gnoswap/staker/v1"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
)

const int64Max int64 = 9223372036854775807

var t *testing.T

var (
	adminAddr, _     = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm       = testing.NewUserRealm(adminAddr)
	poolAddr, _      = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _    = access.GetAddress(prbac.ROLE_ROUTER.String())
	stakerAddr, _    = access.GetAddress(prbac.ROLE_STAKER.String())
	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	govStakerAddr, _ = access.GetAddress(prbac.ROLE_GOV_STAKER.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)
	bobAddr    = testutils.TestAddress("bob")
	bobRealm   = testing.NewUserRealm(bobAddr)

	barPath                    = "gno.land/r/onbloc/bar"
	fooPath                    = "gno.land/r/onbloc/foo"
	fee                        = uint32(3000)
	existingLaunchpadProjectID string
)

func main() {
	println("[SCENARIO] 1. Initialize pool, position, launchpad, and governance state")
	setupScenario()
	println()

	println("[SCENARIO] 2. Set emergency mode")
	setEmergencyMode()
	println()

	testBlockedEntriesOneByOne()
}

func setupScenario() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	testing.SkipHeights(1)
	pool.SetPoolCreationFee(cross, 0)
	bar.Transfer(cross, aliceAddr, 100000000)
	foo.Transfer(cross, aliceAddr, 100000000)
	gns.Transfer(cross, bobAddr, 2000000)
	pool.CreatePool(cross, barPath, fooPath, fee, common.TickMathGetSqrtRatioAtTick(0).ToString())
	staker.SetPoolTier(cross, barPath+":"+fooPath+":3000", 1)
	obl.Approve(cross, launchpadAddr, 10000)
	existingLaunchpadProjectID = launchpad.CreateProject(cross, "Existing Project", "gno.land/r/onbloc/obl", bobAddr, 10000, "", "", 30, 30, 40, time.Now().Unix()+604800)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, int64Max)
	foo.Approve(cross, poolAddr, int64Max)
	testing.SetOriginSend(chain.Coins{})
	positionId, _, _, _ := position.Mint(cross, barPath, fooPath, fee, -960, 960, "10000000", "10000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))
	ufmt.Printf("[INFO] setup position id: %d\n", positionId)

	testing.SetRealm(bobRealm)
	gns.Approve(cross, govStakerAddr, 1000000)
	gns.Approve(cross, launchpadAddr, 1000000)
	ufmt.Println("[INFO] bob prepared gov staker and launchpad approvals")
}

func setEmergencyMode() {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelEmergency)
	ufmt.Printf("[INFO] Pool halted: %t\n", halt.IsHaltedPool())
	ufmt.Printf("[INFO] Staker halted: %t\n", halt.IsHaltedStaker())
	ufmt.Printf("[INFO] GovStaker halted: %t\n", halt.IsHaltedGovStaker())
	ufmt.Printf("[INFO] Launchpad halted: %t\n", halt.IsHaltedLaunchpad())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

var blockedScenarioNo = 3

func printBlockedScenario(domain, function string) {
	ufmt.Printf("[SCENARIO] %d. %s.%s is blocked\n", blockedScenarioNo, domain, function)
	blockedScenarioNo++
}

func printBlockedExpected(domain, function, haltDomain string) {
	ufmt.Printf("[EXPECTED] %s.%s blocked by %s halt\n", domain, function, haltDomain)
	println()
}

func testBlockedEntriesOneByOne() {
	testing.SetRealm(adminRealm)
	printBlockedScenario("pool", "CreatePool")
	uassert.AbortsContains(t, "halted: pool", func() {
		pool.CreatePool(cross, barPath, fooPath, 500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	})
	printBlockedExpected("pool", "CreatePool", "pool")

	testing.SetRealm(aliceRealm)
	printBlockedScenario("pool", "IncreaseObservationCardinalityNext")
	uassert.AbortsContains(t, "halted: pool", func() {
		pool.IncreaseObservationCardinalityNext(cross, barPath, fooPath, fee, 2)
	})
	printBlockedExpected("pool", "IncreaseObservationCardinalityNext", "pool")

	printBlockedScenario("pool", "Mint")
	uassert.AbortsContains(t, "halted: pool", func() {
		pool.Mint(cross, barPath, fooPath, fee, -960, 960, "1000", aliceAddr)
	})
	printBlockedExpected("pool", "Mint", "pool")

	printBlockedScenario("pool", "Swap")
	uassert.AbortsContains(t, "halted: pool", func() {
		pool.Swap(cross, barPath, fooPath, fee, aliceAddr, true, "1000", "0", aliceAddr, nil)
	})
	printBlockedExpected("pool", "Swap", "pool")

	printBlockedScenario("pool", "SetSwapEndHook")
	uassert.AbortsContains(t, "halted: pool", func() {
		pool.SetSwapEndHook(cross, nil)
	})
	printBlockedExpected("pool", "SetSwapEndHook", "pool")

	printBlockedScenario("pool", "SetSwapStartHook")
	uassert.AbortsContains(t, "halted: pool", func() {
		pool.SetSwapStartHook(cross, nil)
	})
	printBlockedExpected("pool", "SetSwapStartHook", "pool")

	printBlockedScenario("pool", "SetTickCrossHook")
	uassert.AbortsContains(t, "halted: pool", func() {
		pool.SetTickCrossHook(cross, nil)
	})
	printBlockedExpected("pool", "SetTickCrossHook", "pool")

	testing.SetRealm(aliceRealm)
	printBlockedScenario("position", "Mint")
	uassert.AbortsContains(t, "halted: position", func() {
		testing.SetOriginSend(chain.Coins{})
		position.Mint(cross, barPath, fooPath, fee, -1920, 1920, "1000000", "1000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")
	})
	printBlockedExpected("position", "Mint", "position")

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, routerAddr, int64Max)
	foo.Approve(cross, routerAddr, int64Max)
	printBlockedScenario("router", "ExactInSwapRoute")
	uassert.AbortsContains(t, "halted: router", func() {
		testing.SetOriginSend(chain.Coins{})
		router.ExactInSwapRoute(cross, barPath, fooPath, "100000", barPath+":"+fooPath+":3000", "100", "0", time.Now().Unix()+3600, "")
	})
	printBlockedExpected("router", "ExactInSwapRoute", "router")

	printBlockedScenario("router", "ExactInSingleSwapRoute")
	uassert.AbortsContains(t, "halted: router", func() {
		router.ExactInSingleSwapRoute(cross, barPath, fooPath, "100000", barPath+":"+fooPath+":3000", "0", "0", time.Now().Unix()+3600, "")
	})
	printBlockedExpected("router", "ExactInSingleSwapRoute", "router")

	printBlockedScenario("router", "ExactOutSwapRoute")
	uassert.AbortsContains(t, "halted: router", func() {
		router.ExactOutSwapRoute(cross, barPath, fooPath, "100000", barPath+":"+fooPath+":3000", "100", "1000000", time.Now().Unix()+3600, "")
	})
	printBlockedExpected("router", "ExactOutSwapRoute", "router")

	printBlockedScenario("router", "ExactOutSingleSwapRoute")
	uassert.AbortsContains(t, "halted: router", func() {
		router.ExactOutSingleSwapRoute(cross, barPath, fooPath, "100000", barPath+":"+fooPath+":3000", "1000000", "0", time.Now().Unix()+3600, "")
	})
	printBlockedExpected("router", "ExactOutSingleSwapRoute", "router")

	printBlockedScenario("router", "SwapCallback")
	uassert.AbortsContains(t, "halted: router", func() {
		router.SwapCallback(barPath, fooPath, 1, 0, aliceAddr)
	})
	printBlockedExpected("router", "SwapCallback", "router")

	testing.SetRealm(aliceRealm)
	printBlockedScenario("staker", "StakeToken")
	uassert.AbortsContains(t, "halted: staker", func() {
		staker.StakeToken(cross, 1, "")
	})
	printBlockedExpected("staker", "StakeToken", "staker")

	printBlockedScenario("staker", "MintAndStake")
	uassert.AbortsContains(t, "halted: staker", func() {
		staker.MintAndStake(cross, barPath, fooPath, fee, -60, 60, "1000", "1000", "0", "0", time.Now().Unix()+3600, "")
	})
	printBlockedExpected("staker", "MintAndStake", "staker")

	testing.SetRealm(bobRealm)
	printBlockedScenario("gov_staker", "Delegate")
	uassert.AbortsContains(t, "halted: gov_staker", func() {
		govstaker.Delegate(cross, bobAddr, 1000000, "")
	})
	printBlockedExpected("gov_staker", "Delegate", "gov_staker")

	printBlockedScenario("gov_staker", "Undelegate")
	uassert.AbortsContains(t, "halted: gov_staker", func() {
		govstaker.Undelegate(cross, bobAddr, 1000000)
	})
	printBlockedExpected("gov_staker", "Undelegate", "gov_staker")

	printBlockedScenario("gov_staker", "Redelegate")
	uassert.AbortsContains(t, "halted: gov_staker", func() {
		govstaker.Redelegate(cross, bobAddr, aliceAddr, 1000000)
	})
	printBlockedExpected("gov_staker", "Redelegate", "gov_staker")

	testing.SetRealm(adminRealm)
	printBlockedScenario("launchpad", "CreateProject")
	uassert.AbortsContains(t, "halted: launchpad", func() {
		obl.Approve(cross, launchpadAddr, 10000)
		launchpad.CreateProject(cross, "Blocked Project", "gno.land/r/onbloc/obl", aliceAddr, 10000, "", "", 30, 30, 40, time.Now().Unix()+604800)
	})
	printBlockedExpected("launchpad", "CreateProject", "launchpad")

	testing.SetRealm(bobRealm)
	printBlockedScenario("launchpad", "DepositGns")
	uassert.AbortsContains(t, "halted: launchpad", func() {
		launchpad.DepositGns(cross, "gno.land/r/onbloc/obl:123:30", 1000000, "")
	})
	printBlockedExpected("launchpad", "DepositGns", "launchpad")

	testing.SetRealm(adminRealm)
	printBlockedScenario("launchpad", "TransferLeftFromProjectByAdmin")
	uassert.AbortsContains(t, "halted: launchpad", func() {
		launchpad.TransferLeftFromProjectByAdmin(cross, existingLaunchpadProjectID, bobAddr)
	})
	printBlockedExpected("launchpad", "TransferLeftFromProjectByAdmin", "launchpad")

	testing.SetRealm(adminRealm)
	printBlockedScenario("pool", "SetPoolCreationFee")
	uassert.AbortsContains(t, "halted: pool", func() {
		pool.SetPoolCreationFee(cross, 1)
	})
	printBlockedExpected("pool", "SetPoolCreationFee", "pool")

	printBlockedScenario("pool", "SetWithdrawalFee")
	uassert.AbortsContains(t, "halted: pool", func() {
		pool.SetWithdrawalFee(cross, 1)
	})
	printBlockedExpected("pool", "SetWithdrawalFee", "pool")

	printBlockedScenario("pool", "SetFeeProtocol")
	uassert.AbortsContains(t, "halted: pool", func() {
		pool.SetFeeProtocol(cross, 1, 1)
	})
	printBlockedExpected("pool", "SetFeeProtocol", "pool")

	printBlockedScenario("router", "SetSwapFee")
	uassert.AbortsContains(t, "halted: router", func() {
		router.SetSwapFee(cross, 1)
	})
	printBlockedExpected("router", "SetSwapFee", "router")

	printBlockedScenario("staker", "SetPoolTier")
	uassert.AbortsContains(t, "halted: staker", func() {
		staker.SetPoolTier(cross, barPath+":"+fooPath+":3000", 1)
	})
	printBlockedExpected("staker", "SetPoolTier", "staker")

	printBlockedScenario("staker", "ChangePoolTier")
	uassert.AbortsContains(t, "halted: staker", func() {
		staker.ChangePoolTier(cross, barPath+":"+fooPath+":3000", 1)
	})
	printBlockedExpected("staker", "ChangePoolTier", "staker")

	printBlockedScenario("staker", "RemovePoolTier")
	uassert.AbortsContains(t, "halted: staker", func() {
		staker.RemovePoolTier(cross, barPath+":"+fooPath+":3000")
	})
	printBlockedExpected("staker", "RemovePoolTier", "staker")

	printBlockedScenario("staker", "SetWarmUp")
	uassert.AbortsContains(t, "halted: staker", func() {
		staker.SetWarmUp(cross, 0, 0)
	})
	printBlockedExpected("staker", "SetWarmUp", "staker")

	printBlockedScenario("staker", "SetDepositGnsAmount")
	uassert.AbortsContains(t, "halted: staker", func() {
		staker.SetDepositGnsAmount(cross, 1)
	})
	printBlockedExpected("staker", "SetDepositGnsAmount", "staker")

	printBlockedScenario("staker", "SetMinimumRewardAmount")
	uassert.AbortsContains(t, "halted: staker", func() {
		staker.SetMinimumRewardAmount(cross, 1)
	})
	printBlockedExpected("staker", "SetMinimumRewardAmount", "staker")

	printBlockedScenario("staker", "SetTokenMinimumRewardAmount")
	uassert.AbortsContains(t, "halted: staker", func() {
		staker.SetTokenMinimumRewardAmount(cross, barPath+":1")
	})
	printBlockedExpected("staker", "SetTokenMinimumRewardAmount", "staker")

	printBlockedScenario("staker", "SetUnStakingFee")
	uassert.AbortsContains(t, "halted: staker", func() {
		staker.SetUnStakingFee(cross, 1)
	})
	printBlockedExpected("staker", "SetUnStakingFee", "staker")

	printBlockedScenario("protocol_fee", "SetDevOpsPct")
	uassert.AbortsContains(t, "halted: protocol_fee", func() {
		protocolfee.SetDevOpsPct(cross, 10)
	})
	printBlockedExpected("protocol_fee", "SetDevOpsPct", "protocol_fee")

	printBlockedScenario("protocol_fee", "SetGovStakerPct")
	uassert.AbortsContains(t, "halted: protocol_fee", func() {
		protocolfee.SetGovStakerPct(cross, 10)
	})
	printBlockedExpected("protocol_fee", "SetGovStakerPct", "protocol_fee")

	printBlockedScenario("protocol_fee", "AddToProtocolFee")
	if err := protocolfee.AddToProtocolFee(cross, barPath, 1); err == nil || err.Error() != "[GNOSWAP-PROTOCOL_FEE-003] protocol fee halted" {
		panic("expected protocol fee add to fail while protocol fee is halted")
	}
	printBlockedExpected("protocol_fee", "AddToProtocolFee", "protocol_fee")

	printBlockedScenario("gov_staker", "SetAmountByProjectWallet")
	uassert.AbortsContains(t, "halted: gov_staker", func() {
		govstaker.SetAmountByProjectWallet(cross, bobAddr, 1, true)
	})
	printBlockedExpected("gov_staker", "SetAmountByProjectWallet", "gov_staker")

	printBlockedScenario("gov_staker", "CleanStakerDelegationSnapshotByAdmin")
	uassert.AbortsContains(t, "halted: gov_staker", func() {
		govstaker.CleanStakerDelegationSnapshotByAdmin(cross, time.Now().Unix(), bobAddr)
	})
	printBlockedExpected("gov_staker", "CleanStakerDelegationSnapshotByAdmin", "gov_staker")

	printBlockedScenario("gov_staker", "SetUnDelegationLockupPeriodByAdmin")
	uassert.AbortsContains(t, "halted: gov_staker", func() {
		govstaker.SetUnDelegationLockupPeriodByAdmin(cross, 1)
	})
	printBlockedExpected("gov_staker", "SetUnDelegationLockupPeriodByAdmin", "gov_staker")

	printBlockedScenario("emission", "SetDistributionStartTime")
	uassert.AbortsContains(t, "halted: emission", func() {
		emission.SetDistributionStartTime(cross, time.Now().Unix()+1000)
	})
	printBlockedExpected("emission", "SetDistributionStartTime", "emission")

	printBlockedScenario("emission", "ChangeDistributionPct")
	uassert.AbortsContains(t, "halted: emission", func() {
		emission.ChangeDistributionPct(cross, 7000, 2000, 1000, 0)
	})
	printBlockedExpected("emission", "ChangeDistributionPct", "emission")

	testing.SetRealm(aliceRealm)
	printBlockedScenario("position", "IncreaseLiquidity")
	uassert.AbortsContains(t, "halted: position", func() {
		position.IncreaseLiquidity(cross, 1, "1000", "1000", "0", "0", time.Now().Unix()+3600)
	})
	printBlockedExpected("position", "IncreaseLiquidity", "position")

	printBlockedScenario("position", "Reposition")
	uassert.AbortsContains(t, "halted: position", func() {
		position.Reposition(cross, 1, -120, 120, "1000", "1000", "0", "0", time.Now().Unix()+3600)
	})
	printBlockedExpected("position", "Reposition", "position")

	printBlockedScenario("staker", "CreateExternalIncentive")
	uassert.AbortsContains(t, "halted: staker", func() {
		staker.CreateExternalIncentive(cross, barPath+":"+fooPath+":3000", barPath, 1000, time.Now().Unix()+1000, time.Now().Unix()+2000)
	})
	printBlockedExpected("staker", "CreateExternalIncentive", "staker")

	printBlockedScenario("staker", "AddToken")
	uassert.AbortsContains(t, "halted: staker", func() {
		staker.AddToken(cross, barPath)
	})
	printBlockedExpected("staker", "AddToken", "staker")

	printBlockedScenario("staker", "RemoveToken")
	uassert.AbortsContains(t, "halted: staker", func() {
		staker.RemoveToken(cross, barPath)
	})
	printBlockedExpected("staker", "RemoveToken", "staker")

	testing.SetRealm(testing.NewUserRealm(govStakerAddr))
	printBlockedScenario("xgns", "Mint")
	uassert.AbortsContains(t, "halted: xgns", func() {
		xgns.Mint(cross, bobAddr, 1)
	})
	printBlockedExpected("xgns", "Mint", "xgns")
}

func positionIdFrom(positionId any) grc721.TokenID {
	switch positionId.(type) {
	case int:
		return grc721.TokenID(ufmt.Sprintf("%d", positionId.(int)))
	case uint64:
		return grc721.TokenID(ufmt.Sprintf("%d", positionId.(uint64)))
	case grc721.TokenID:
		return positionId.(grc721.TokenID)
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize pool, position, launchpad, and governance state
// [INFO] setup position id: 1
// [INFO] bob prepared gov staker and launchpad approvals
//
// [SCENARIO] 2. Set emergency mode
// [INFO] Pool halted: true
// [INFO] Staker halted: true
// [INFO] GovStaker halted: true
// [INFO] Launchpad halted: true
// [INFO] Withdraw halted: false
//
// [SCENARIO] 3. pool.CreatePool is blocked
// [EXPECTED] pool.CreatePool blocked by pool halt
//
// [SCENARIO] 4. pool.IncreaseObservationCardinalityNext is blocked
// [EXPECTED] pool.IncreaseObservationCardinalityNext blocked by pool halt
//
// [SCENARIO] 5. pool.Mint is blocked
// [EXPECTED] pool.Mint blocked by pool halt
//
// [SCENARIO] 6. pool.Swap is blocked
// [EXPECTED] pool.Swap blocked by pool halt
//
// [SCENARIO] 7. pool.SetSwapEndHook is blocked
// [EXPECTED] pool.SetSwapEndHook blocked by pool halt
//
// [SCENARIO] 8. pool.SetSwapStartHook is blocked
// [EXPECTED] pool.SetSwapStartHook blocked by pool halt
//
// [SCENARIO] 9. pool.SetTickCrossHook is blocked
// [EXPECTED] pool.SetTickCrossHook blocked by pool halt
//
// [SCENARIO] 10. position.Mint is blocked
// [EXPECTED] position.Mint blocked by position halt
//
// [SCENARIO] 11. router.ExactInSwapRoute is blocked
// [EXPECTED] router.ExactInSwapRoute blocked by router halt
//
// [SCENARIO] 12. router.ExactInSingleSwapRoute is blocked
// [EXPECTED] router.ExactInSingleSwapRoute blocked by router halt
//
// [SCENARIO] 13. router.ExactOutSwapRoute is blocked
// [EXPECTED] router.ExactOutSwapRoute blocked by router halt
//
// [SCENARIO] 14. router.ExactOutSingleSwapRoute is blocked
// [EXPECTED] router.ExactOutSingleSwapRoute blocked by router halt
//
// [SCENARIO] 15. router.SwapCallback is blocked
// [EXPECTED] router.SwapCallback blocked by router halt
//
// [SCENARIO] 16. staker.StakeToken is blocked
// [EXPECTED] staker.StakeToken blocked by staker halt
//
// [SCENARIO] 17. staker.MintAndStake is blocked
// [EXPECTED] staker.MintAndStake blocked by staker halt
//
// [SCENARIO] 18. gov_staker.Delegate is blocked
// [EXPECTED] gov_staker.Delegate blocked by gov_staker halt
//
// [SCENARIO] 19. gov_staker.Undelegate is blocked
// [EXPECTED] gov_staker.Undelegate blocked by gov_staker halt
//
// [SCENARIO] 20. gov_staker.Redelegate is blocked
// [EXPECTED] gov_staker.Redelegate blocked by gov_staker halt
//
// [SCENARIO] 21. launchpad.CreateProject is blocked
// [EXPECTED] launchpad.CreateProject blocked by launchpad halt
//
// [SCENARIO] 22. launchpad.DepositGns is blocked
// [EXPECTED] launchpad.DepositGns blocked by launchpad halt
//
// [SCENARIO] 23. launchpad.TransferLeftFromProjectByAdmin is blocked
// [EXPECTED] launchpad.TransferLeftFromProjectByAdmin blocked by launchpad halt
//
// [SCENARIO] 24. pool.SetPoolCreationFee is blocked
// [EXPECTED] pool.SetPoolCreationFee blocked by pool halt
//
// [SCENARIO] 25. pool.SetWithdrawalFee is blocked
// [EXPECTED] pool.SetWithdrawalFee blocked by pool halt
//
// [SCENARIO] 26. pool.SetFeeProtocol is blocked
// [EXPECTED] pool.SetFeeProtocol blocked by pool halt
//
// [SCENARIO] 27. router.SetSwapFee is blocked
// [EXPECTED] router.SetSwapFee blocked by router halt
//
// [SCENARIO] 28. staker.SetPoolTier is blocked
// [EXPECTED] staker.SetPoolTier blocked by staker halt
//
// [SCENARIO] 29. staker.ChangePoolTier is blocked
// [EXPECTED] staker.ChangePoolTier blocked by staker halt
//
// [SCENARIO] 30. staker.RemovePoolTier is blocked
// [EXPECTED] staker.RemovePoolTier blocked by staker halt
//
// [SCENARIO] 31. staker.SetWarmUp is blocked
// [EXPECTED] staker.SetWarmUp blocked by staker halt
//
// [SCENARIO] 32. staker.SetDepositGnsAmount is blocked
// [EXPECTED] staker.SetDepositGnsAmount blocked by staker halt
//
// [SCENARIO] 33. staker.SetMinimumRewardAmount is blocked
// [EXPECTED] staker.SetMinimumRewardAmount blocked by staker halt
//
// [SCENARIO] 34. staker.SetTokenMinimumRewardAmount is blocked
// [EXPECTED] staker.SetTokenMinimumRewardAmount blocked by staker halt
//
// [SCENARIO] 35. staker.SetUnStakingFee is blocked
// [EXPECTED] staker.SetUnStakingFee blocked by staker halt
//
// [SCENARIO] 36. protocol_fee.SetDevOpsPct is blocked
// [EXPECTED] protocol_fee.SetDevOpsPct blocked by protocol_fee halt
//
// [SCENARIO] 37. protocol_fee.SetGovStakerPct is blocked
// [EXPECTED] protocol_fee.SetGovStakerPct blocked by protocol_fee halt
//
// [SCENARIO] 38. protocol_fee.AddToProtocolFee is blocked
// [EXPECTED] protocol_fee.AddToProtocolFee blocked by protocol_fee halt
//
// [SCENARIO] 39. gov_staker.SetAmountByProjectWallet is blocked
// [EXPECTED] gov_staker.SetAmountByProjectWallet blocked by gov_staker halt
//
// [SCENARIO] 40. gov_staker.CleanStakerDelegationSnapshotByAdmin is blocked
// [EXPECTED] gov_staker.CleanStakerDelegationSnapshotByAdmin blocked by gov_staker halt
//
// [SCENARIO] 41. gov_staker.SetUnDelegationLockupPeriodByAdmin is blocked
// [EXPECTED] gov_staker.SetUnDelegationLockupPeriodByAdmin blocked by gov_staker halt
//
// [SCENARIO] 42. emission.SetDistributionStartTime is blocked
// [EXPECTED] emission.SetDistributionStartTime blocked by emission halt
//
// [SCENARIO] 43. emission.ChangeDistributionPct is blocked
// [EXPECTED] emission.ChangeDistributionPct blocked by emission halt
//
// [SCENARIO] 44. position.IncreaseLiquidity is blocked
// [EXPECTED] position.IncreaseLiquidity blocked by position halt
//
// [SCENARIO] 45. position.Reposition is blocked
// [EXPECTED] position.Reposition blocked by position halt
//
// [SCENARIO] 46. staker.CreateExternalIncentive is blocked
// [EXPECTED] staker.CreateExternalIncentive blocked by staker halt
//
// [SCENARIO] 47. staker.AddToken is blocked
// [EXPECTED] staker.AddToken blocked by staker halt
//
// [SCENARIO] 48. staker.RemoveToken is blocked
// [EXPECTED] staker.RemoveToken blocked by staker halt
//
// [SCENARIO] 49. xgns.Mint is blocked
// [EXPECTED] xgns.Mint blocked by xgns halt
