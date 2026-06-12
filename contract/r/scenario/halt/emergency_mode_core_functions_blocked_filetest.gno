// PKGPATH: gno.land/r/gnoswap/v1/main

// Scenario: Emergency Mode blocks core growth functions across contracts

package main

import (
	"gno.land/p/gnoswap/gnsmath"
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

func main(cur realm) {
	println("[SCENARIO] 1. Initialize pool, position, launchpad, and governance state")
	setupScenario(cur)
	println()

	println("[SCENARIO] 2. Set emergency mode")
	setEmergencyMode(cur)
	println()

	testBlockedEntriesOneByOne(cur)
}

func setupScenario(cur realm) {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	testing.SkipHeights(1)
	pool.SetPoolCreationFee(cross(cur), 0)
	bar.Transfer(cross(cur), aliceAddr, 100000000)
	foo.Transfer(cross(cur), aliceAddr, 100000000)
	gns.Transfer(cross(cur), bobAddr, 2000000)
	pool.CreatePool(cross(cur), barPath, fooPath, fee, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	staker.SetPoolTier(cross(cur), barPath+":"+fooPath+":3000", 1)
	obl.Approve(cross(cur), launchpadAddr, 10000)
	existingLaunchpadProjectID = launchpad.CreateProject(cross(cur), "Existing Project", "gno.land/r/onbloc/obl", bobAddr, 10000, "", "", 30, 30, 40, time.Now().Unix()+604800)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross(cur), poolAddr, int64Max)
	foo.Approve(cross(cur), poolAddr, int64Max)
	testing.SetOriginSend(chain.Coins{})
	positionId, _, _, _ := position.Mint(cross(cur), barPath, fooPath, fee, -960, 960, "10000000", "10000000", "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, positionId))
	ufmt.Printf("[INFO] setup position id: %d\n", positionId)

	testing.SetRealm(bobRealm)
	gns.Approve(cross(cur), govStakerAddr, 1000000)
	gns.Approve(cross(cur), launchpadAddr, 1000000)
	ufmt.Println("[INFO] bob prepared gov staker and launchpad approvals")
}

func setEmergencyMode(cur realm) {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)
	ufmt.Printf("[INFO] Pool halted: %t\n", halt.IsHaltedPool())
	ufmt.Printf("[INFO] Staker halted: %t\n", halt.IsHaltedStaker())
	ufmt.Printf("[INFO] GovStaker halted: %t\n", halt.IsHaltedGovStaker())
	ufmt.Printf("[INFO] Launchpad halted: %t\n", halt.IsHaltedLaunchpad())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

var blockedScenarioNo = 3

func printBlockedScenario(cur realm, domain, function string) {
	ufmt.Printf("[SCENARIO] %d. %s.%s is blocked\n", blockedScenarioNo, domain, function)
	blockedScenarioNo++
}

func printBlockedExpected(cur realm, domain, function, haltDomain string) {
	ufmt.Printf("[EXPECTED] %s.%s blocked by %s halt\n", domain, function, haltDomain)
	println()
}

func testBlockedEntriesOneByOne(cur realm) {
	testing.SetRealm(adminRealm)
	printBlockedScenario(cur, "pool", "CreatePool")
	uassert.AbortsContains(t, cur, "halted: pool", func() {
		pool.CreatePool(cross(cur), barPath, fooPath, 500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	})
	printBlockedExpected(cur, "pool", "CreatePool", "pool")

	testing.SetRealm(aliceRealm)
	printBlockedScenario(cur, "pool", "IncreaseObservationCardinalityNext")
	uassert.AbortsContains(t, cur, "halted: pool", func() {
		pool.IncreaseObservationCardinalityNext(cross(cur), barPath, fooPath, fee, 2)
	})
	printBlockedExpected(cur, "pool", "IncreaseObservationCardinalityNext", "pool")

	printBlockedScenario(cur, "pool", "Mint")
	uassert.AbortsContains(t, cur, "halted: pool", func() {
		pool.Mint(cross(cur), barPath, fooPath, fee, -960, 960, "1000", aliceAddr)
	})
	printBlockedExpected(cur, "pool", "Mint", "pool")

	printBlockedScenario(cur, "pool", "Swap")
	uassert.AbortsContains(t, cur, "halted: pool", func() {
		pool.Swap(cross(cur), barPath, fooPath, fee, aliceAddr, true, "1000", "0", aliceAddr, nil)
	})
	printBlockedExpected(cur, "pool", "Swap", "pool")

	printBlockedScenario(cur, "pool", "SetSwapEndHook")
	uassert.AbortsContains(t, cur, "halted: pool", func() {
		pool.SetSwapEndHook(cross(cur), nil)
	})
	printBlockedExpected(cur, "pool", "SetSwapEndHook", "pool")

	printBlockedScenario(cur, "pool", "SetSwapStartHook")
	uassert.AbortsContains(t, cur, "halted: pool", func() {
		pool.SetSwapStartHook(cross(cur), nil)
	})
	printBlockedExpected(cur, "pool", "SetSwapStartHook", "pool")

	printBlockedScenario(cur, "pool", "SetTickCrossHook")
	uassert.AbortsContains(t, cur, "halted: pool", func() {
		pool.SetTickCrossHook(cross(cur), nil)
	})
	printBlockedExpected(cur, "pool", "SetTickCrossHook", "pool")

	testing.SetRealm(aliceRealm)
	printBlockedScenario(cur, "position", "Mint")
	uassert.AbortsContains(t, cur, "halted: position", func() {
		testing.SetOriginSend(chain.Coins{})
		position.Mint(cross(cur), barPath, fooPath, fee, -1920, 1920, "1000000", "1000000", "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	})
	printBlockedExpected(cur, "position", "Mint", "position")

	testing.SetRealm(aliceRealm)
	bar.Approve(cross(cur), routerAddr, int64Max)
	foo.Approve(cross(cur), routerAddr, int64Max)
	printBlockedScenario(cur, "router", "ExactInSwapRoute")
	uassert.AbortsContains(t, cur, "halted: router", func() {
		testing.SetOriginSend(chain.Coins{})
		router.ExactInSwapRoute(cross(cur), barPath, fooPath, "100000", barPath+":"+fooPath+":3000", "100", "0", time.Now().Unix()+3600, "")
	})
	printBlockedExpected(cur, "router", "ExactInSwapRoute", "router")

	printBlockedScenario(cur, "router", "ExactInSingleSwapRoute")
	uassert.AbortsContains(t, cur, "halted: router", func() {
		router.ExactInSingleSwapRoute(cross(cur), barPath, fooPath, "100000", barPath+":"+fooPath+":3000", "0", "0", time.Now().Unix()+3600, "")
	})
	printBlockedExpected(cur, "router", "ExactInSingleSwapRoute", "router")

	printBlockedScenario(cur, "router", "ExactOutSwapRoute")
	uassert.AbortsContains(t, cur, "halted: router", func() {
		router.ExactOutSwapRoute(cross(cur), barPath, fooPath, "100000", barPath+":"+fooPath+":3000", "100", "1000000", time.Now().Unix()+3600, "")
	})
	printBlockedExpected(cur, "router", "ExactOutSwapRoute", "router")

	printBlockedScenario(cur, "router", "ExactOutSingleSwapRoute")
	uassert.AbortsContains(t, cur, "halted: router", func() {
		router.ExactOutSingleSwapRoute(cross(cur), barPath, fooPath, "100000", barPath+":"+fooPath+":3000", "1000000", "0", time.Now().Unix()+3600, "")
	})
	printBlockedExpected(cur, "router", "ExactOutSingleSwapRoute", "router")

	printBlockedScenario(cur, "router", "SwapCallback")
	uassert.AbortsContains(t, cur, "halted: router", func() {
		router.SwapCallback(cross(cur), barPath, fooPath, 1, 0, aliceAddr)
	})
	printBlockedExpected(cur, "router", "SwapCallback", "router")

	testing.SetRealm(aliceRealm)
	printBlockedScenario(cur, "staker", "StakeToken")
	uassert.AbortsContains(t, cur, "halted: staker", func() {
		staker.StakeToken(cross(cur), 1, "")
	})
	printBlockedExpected(cur, "staker", "StakeToken", "staker")

	printBlockedScenario(cur, "staker", "SetPoolTier")
	uassert.AbortsContains(t, cur, "halted: staker", func() {
		staker.SetPoolTier(cross(cur), barPath+":"+fooPath+":3000", 2)
	})
	printBlockedExpected(cur, "staker", "SetPoolTier", "staker")

	testing.SetRealm(bobRealm)
	printBlockedScenario(cur, "gov_staker", "Delegate")
	uassert.AbortsContains(t, cur, "halted: gov_staker", func() {
		govstaker.Delegate(cross(cur), bobAddr, 1000000, "")
	})
	printBlockedExpected(cur, "gov_staker", "Delegate", "gov_staker")

	printBlockedScenario(cur, "gov_staker", "Redelegate")
	uassert.AbortsContains(t, cur, "halted: gov_staker", func() {
		govstaker.Redelegate(cross(cur), bobAddr, aliceAddr, 1000000)
	})
	printBlockedExpected(cur, "gov_staker", "Redelegate", "gov_staker")

	testing.SetRealm(adminRealm)
	printBlockedScenario(cur, "launchpad", "CreateProject")
	uassert.AbortsContains(t, cur, "halted: launchpad", func() {
		obl.Approve(cross(cur), launchpadAddr, 10000)
		launchpad.CreateProject(cross(cur), "Blocked Project", "gno.land/r/onbloc/obl", aliceAddr, 10000, "", "", 30, 30, 40, time.Now().Unix()+604800)
	})
	printBlockedExpected(cur, "launchpad", "CreateProject", "launchpad")

	testing.SetRealm(bobRealm)
	printBlockedScenario(cur, "launchpad", "DepositGns")
	uassert.AbortsContains(t, cur, "halted: launchpad", func() {
		launchpad.DepositGns(cross(cur), "gno.land/r/onbloc/obl:123:30", 1000000, "")
	})
	printBlockedExpected(cur, "launchpad", "DepositGns", "launchpad")

	testing.SetRealm(adminRealm)
	printBlockedScenario(cur, "launchpad", "TransferLeftFromProjectByAdmin")
	uassert.AbortsContains(t, cur, "halted: launchpad", func() {
		launchpad.TransferLeftFromProjectByAdmin(cross(cur), existingLaunchpadProjectID, bobAddr)
	})
	printBlockedExpected(cur, "launchpad", "TransferLeftFromProjectByAdmin", "launchpad")

	testing.SetRealm(adminRealm)
	printBlockedScenario(cur, "pool", "SetPoolCreationFee")
	uassert.AbortsContains(t, cur, "halted: pool", func() {
		pool.SetPoolCreationFee(cross(cur), 1)
	})
	printBlockedExpected(cur, "pool", "SetPoolCreationFee", "pool")

	printBlockedScenario(cur, "pool", "SetWithdrawalFee")
	uassert.AbortsContains(t, cur, "halted: pool", func() {
		pool.SetWithdrawalFee(cross(cur), 1)
	})
	printBlockedExpected(cur, "pool", "SetWithdrawalFee", "pool")

	printBlockedScenario(cur, "pool", "SetFeeProtocol")
	uassert.AbortsContains(t, cur, "halted: pool", func() {
		pool.SetFeeProtocol(cross(cur), 1, 1)
	})
	printBlockedExpected(cur, "pool", "SetFeeProtocol", "pool")

	printBlockedScenario(cur, "router", "SetSwapFee")
	uassert.AbortsContains(t, cur, "halted: router", func() {
		router.SetSwapFee(cross(cur), 1)
	})
	printBlockedExpected(cur, "router", "SetSwapFee", "router")

	printBlockedScenario(cur, "staker", "SetPoolTier")
	uassert.AbortsContains(t, cur, "halted: staker", func() {
		staker.SetPoolTier(cross(cur), barPath+":"+fooPath+":3000", 1)
	})
	printBlockedExpected(cur, "staker", "SetPoolTier", "staker")

	printBlockedScenario(cur, "staker", "ChangePoolTier")
	uassert.AbortsContains(t, cur, "halted: staker", func() {
		staker.ChangePoolTier(cross(cur), barPath+":"+fooPath+":3000", 1)
	})
	printBlockedExpected(cur, "staker", "ChangePoolTier", "staker")

	printBlockedScenario(cur, "staker", "RemovePoolTier")
	uassert.AbortsContains(t, cur, "halted: staker", func() {
		staker.RemovePoolTier(cross(cur), barPath+":"+fooPath+":3000")
	})
	printBlockedExpected(cur, "staker", "RemovePoolTier", "staker")

	printBlockedScenario(cur, "staker", "SetWarmUp")
	uassert.AbortsContains(t, cur, "halted: staker", func() {
		staker.SetWarmUp(cross(cur), 0, 0)
	})
	printBlockedExpected(cur, "staker", "SetWarmUp", "staker")

	printBlockedScenario(cur, "staker", "SetDepositGnsAmount")
	uassert.AbortsContains(t, cur, "halted: staker", func() {
		staker.SetDepositGnsAmount(cross(cur), 1)
	})
	printBlockedExpected(cur, "staker", "SetDepositGnsAmount", "staker")

	printBlockedScenario(cur, "staker", "SetMinimumRewardAmount")
	uassert.AbortsContains(t, cur, "halted: staker", func() {
		staker.SetMinimumRewardAmount(cross(cur), 1)
	})
	printBlockedExpected(cur, "staker", "SetMinimumRewardAmount", "staker")

	printBlockedScenario(cur, "staker", "SetTokenMinimumRewardAmount")
	uassert.AbortsContains(t, cur, "halted: staker", func() {
		staker.SetTokenMinimumRewardAmount(cross(cur), barPath+":1")
	})
	printBlockedExpected(cur, "staker", "SetTokenMinimumRewardAmount", "staker")

	printBlockedScenario(cur, "staker", "SetUnStakingFee")
	uassert.AbortsContains(t, cur, "halted: staker", func() {
		staker.SetUnStakingFee(cross(cur), 1)
	})
	printBlockedExpected(cur, "staker", "SetUnStakingFee", "staker")

	printBlockedScenario(cur, "protocol_fee", "SetDevOpsPct")
	uassert.AbortsContains(t, cur, "halted: protocol_fee", func() {
		protocolfee.SetDevOpsPct(cross(cur), 10)
	})
	printBlockedExpected(cur, "protocol_fee", "SetDevOpsPct", "protocol_fee")

	printBlockedScenario(cur, "protocol_fee", "SetGovStakerPct")
	uassert.AbortsContains(t, cur, "halted: protocol_fee", func() {
		protocolfee.SetGovStakerPct(cross(cur), 10)
	})
	printBlockedExpected(cur, "protocol_fee", "SetGovStakerPct", "protocol_fee")

	printBlockedScenario(cur, "protocol_fee", "AddToProtocolFee")
	if err := protocolfee.AddToProtocolFee(cross(cur), barPath, 1); err == nil || err.Error() != "[GNOSWAP-PROTOCOL_FEE-003] protocol fee halted" {
		panic("expected protocol fee add to fail while protocol fee is halted")
	}
	printBlockedExpected(cur, "protocol_fee", "AddToProtocolFee", "protocol_fee")

	printBlockedScenario(cur, "gov_staker", "SetAmountByProjectWallet")
	uassert.AbortsContains(t, cur, "halted: gov_staker", func() {
		govstaker.SetAmountByProjectWallet(cross(cur), bobAddr, 1, true)
	})
	printBlockedExpected(cur, "gov_staker", "SetAmountByProjectWallet", "gov_staker")

	printBlockedScenario(cur, "gov_staker", "CleanStakerDelegationSnapshotByAdmin")
	uassert.AbortsContains(t, cur, "halted: gov_staker", func() {
		govstaker.CleanStakerDelegationSnapshotByAdmin(cross(cur), time.Now().Unix(), bobAddr)
	})
	printBlockedExpected(cur, "gov_staker", "CleanStakerDelegationSnapshotByAdmin", "gov_staker")

	printBlockedScenario(cur, "gov_staker", "SetUnDelegationLockupPeriodByAdmin")
	uassert.AbortsContains(t, cur, "halted: gov_staker", func() {
		govstaker.SetUnDelegationLockupPeriodByAdmin(cross(cur), 1)
	})
	printBlockedExpected(cur, "gov_staker", "SetUnDelegationLockupPeriodByAdmin", "gov_staker")

	printBlockedScenario(cur, "emission", "SetDistributionStartTime")
	uassert.AbortsContains(t, cur, "halted: emission", func() {
		emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1000)
	})
	printBlockedExpected(cur, "emission", "SetDistributionStartTime", "emission")

	printBlockedScenario(cur, "emission", "ChangeDistributionPct")
	uassert.AbortsContains(t, cur, "halted: emission", func() {
		emission.ChangeDistributionPct(cross(cur), 7000, 2000, 1000, 0)
	})
	printBlockedExpected(cur, "emission", "ChangeDistributionPct", "emission")

	testing.SetRealm(aliceRealm)
	printBlockedScenario(cur, "position", "IncreaseLiquidity")
	uassert.AbortsContains(t, cur, "halted: position", func() {
		position.IncreaseLiquidity(cross(cur), 1, "1000", "1000", "0", "0", time.Now().Unix()+3600)
	})
	printBlockedExpected(cur, "position", "IncreaseLiquidity", "position")

	printBlockedScenario(cur, "position", "Reposition")
	uassert.AbortsContains(t, cur, "halted: position", func() {
		position.Reposition(cross(cur), 1, -120, 120, "1000", "1000", "0", "0", time.Now().Unix()+3600)
	})
	printBlockedExpected(cur, "position", "Reposition", "position")

	printBlockedScenario(cur, "staker", "CreateExternalIncentive")
	uassert.AbortsContains(t, cur, "halted: staker", func() {
		staker.CreateExternalIncentive(cross(cur), barPath+":"+fooPath+":3000", barPath, 1000, time.Now().Unix()+1000, time.Now().Unix()+2000)
	})
	printBlockedExpected(cur, "staker", "CreateExternalIncentive", "staker")

	printBlockedScenario(cur, "staker", "AddToken")
	uassert.AbortsContains(t, cur, "halted: staker", func() {
		staker.AddToken(cross(cur), barPath)
	})
	printBlockedExpected(cur, "staker", "AddToken", "staker")

	printBlockedScenario(cur, "staker", "RemoveToken")
	uassert.AbortsContains(t, cur, "halted: staker", func() {
		staker.RemoveToken(cross(cur), barPath)
	})
	printBlockedExpected(cur, "staker", "RemoveToken", "staker")

	testing.SetRealm(testing.NewUserRealm(govStakerAddr))
	printBlockedScenario(cur, "xgns", "Mint")
	uassert.AbortsContains(t, cur, "halted: xgns", func() {
		xgns.Mint(cross(cur), bobAddr, 1)
	})
	printBlockedExpected(cur, "xgns", "Mint", "xgns")
}

func positionIdFrom(cur realm, positionId any) grc721.TokenID {
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
// [SCENARIO] 17. staker.SetPoolTier is blocked
// [EXPECTED] staker.SetPoolTier blocked by staker halt
//
// [SCENARIO] 18. gov_staker.Delegate is blocked
// [EXPECTED] gov_staker.Delegate blocked by gov_staker halt
//
// [SCENARIO] 19. gov_staker.Redelegate is blocked
// [EXPECTED] gov_staker.Redelegate blocked by gov_staker halt
//
// [SCENARIO] 20. launchpad.CreateProject is blocked
// [EXPECTED] launchpad.CreateProject blocked by launchpad halt
//
// [SCENARIO] 21. launchpad.DepositGns is blocked
// [EXPECTED] launchpad.DepositGns blocked by launchpad halt
//
// [SCENARIO] 22. launchpad.TransferLeftFromProjectByAdmin is blocked
// [EXPECTED] launchpad.TransferLeftFromProjectByAdmin blocked by launchpad halt
//
// [SCENARIO] 23. pool.SetPoolCreationFee is blocked
// [EXPECTED] pool.SetPoolCreationFee blocked by pool halt
//
// [SCENARIO] 24. pool.SetWithdrawalFee is blocked
// [EXPECTED] pool.SetWithdrawalFee blocked by pool halt
//
// [SCENARIO] 25. pool.SetFeeProtocol is blocked
// [EXPECTED] pool.SetFeeProtocol blocked by pool halt
//
// [SCENARIO] 26. router.SetSwapFee is blocked
// [EXPECTED] router.SetSwapFee blocked by router halt
//
// [SCENARIO] 27. staker.SetPoolTier is blocked
// [EXPECTED] staker.SetPoolTier blocked by staker halt
//
// [SCENARIO] 28. staker.ChangePoolTier is blocked
// [EXPECTED] staker.ChangePoolTier blocked by staker halt
//
// [SCENARIO] 29. staker.RemovePoolTier is blocked
// [EXPECTED] staker.RemovePoolTier blocked by staker halt
//
// [SCENARIO] 30. staker.SetWarmUp is blocked
// [EXPECTED] staker.SetWarmUp blocked by staker halt
//
// [SCENARIO] 31. staker.SetDepositGnsAmount is blocked
// [EXPECTED] staker.SetDepositGnsAmount blocked by staker halt
//
// [SCENARIO] 32. staker.SetMinimumRewardAmount is blocked
// [EXPECTED] staker.SetMinimumRewardAmount blocked by staker halt
//
// [SCENARIO] 33. staker.SetTokenMinimumRewardAmount is blocked
// [EXPECTED] staker.SetTokenMinimumRewardAmount blocked by staker halt
//
// [SCENARIO] 34. staker.SetUnStakingFee is blocked
// [EXPECTED] staker.SetUnStakingFee blocked by staker halt
//
// [SCENARIO] 35. protocol_fee.SetDevOpsPct is blocked
// [EXPECTED] protocol_fee.SetDevOpsPct blocked by protocol_fee halt
//
// [SCENARIO] 36. protocol_fee.SetGovStakerPct is blocked
// [EXPECTED] protocol_fee.SetGovStakerPct blocked by protocol_fee halt
//
// [SCENARIO] 37. protocol_fee.AddToProtocolFee is blocked
// [EXPECTED] protocol_fee.AddToProtocolFee blocked by protocol_fee halt
//
// [SCENARIO] 38. gov_staker.SetAmountByProjectWallet is blocked
// [EXPECTED] gov_staker.SetAmountByProjectWallet blocked by gov_staker halt
//
// [SCENARIO] 39. gov_staker.CleanStakerDelegationSnapshotByAdmin is blocked
// [EXPECTED] gov_staker.CleanStakerDelegationSnapshotByAdmin blocked by gov_staker halt
//
// [SCENARIO] 40. gov_staker.SetUnDelegationLockupPeriodByAdmin is blocked
// [EXPECTED] gov_staker.SetUnDelegationLockupPeriodByAdmin blocked by gov_staker halt
//
// [SCENARIO] 41. emission.SetDistributionStartTime is blocked
// [EXPECTED] emission.SetDistributionStartTime blocked by emission halt
//
// [SCENARIO] 42. emission.ChangeDistributionPct is blocked
// [EXPECTED] emission.ChangeDistributionPct blocked by emission halt
//
// [SCENARIO] 43. position.IncreaseLiquidity is blocked
// [EXPECTED] position.IncreaseLiquidity blocked by position halt
//
// [SCENARIO] 44. position.Reposition is blocked
// [EXPECTED] position.Reposition blocked by position halt
//
// [SCENARIO] 45. staker.CreateExternalIncentive is blocked
// [EXPECTED] staker.CreateExternalIncentive blocked by staker halt
//
// [SCENARIO] 46. staker.AddToken is blocked
// [EXPECTED] staker.AddToken blocked by staker halt
//
// [SCENARIO] 47. staker.RemoveToken is blocked
// [EXPECTED] staker.RemoveToken blocked by staker halt
//
// [SCENARIO] 48. xgns.Mint is blocked
// [EXPECTED] xgns.Mint blocked by xgns halt
