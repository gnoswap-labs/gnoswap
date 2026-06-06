// Scenario: Emergency Mode keeps collect paths available

// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"strconv"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	communitypool "gno.land/r/gnoswap/community_pool"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"
	govstaker "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	xgns "gno.land/r/gnoswap/gov/xgns"
	"gno.land/r/gnoswap/halt"
	launchpad "gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"
	pool "gno.land/r/gnoswap/pool"
	_ "gno.land/r/gnoswap/pool/v1"
	position "gno.land/r/gnoswap/position"
	_ "gno.land/r/gnoswap/position/v1"
	pf "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	staker "gno.land/r/gnoswap/staker"
	_ "gno.land/r/gnoswap/staker/v1"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
)

const collectInt64Max int64 = 9223372036854775807

const collectCurrentBlockTime int64 = 2

const (
	collectMinPrice string = "4295128740"
	collectMaxPrice string = "1461446703485210103287273052203988822378723970341"
)

var t *testing.T

var (
	adminAddr2, _         = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm2           = testing.NewUserRealm(adminAddr2)
	poolAddr2, _          = access.GetAddress(prbac.ROLE_POOL.String())
	positionAddr2, _      = access.GetAddress(prbac.ROLE_POSITION.String())
	positionRealm2        = testing.NewUserRealm(positionAddr2)
	stakerAddr2, _        = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm2          = testing.NewUserRealm(stakerAddr2)
	govStakerAddr2, _     = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm2       = testing.NewUserRealm(govStakerAddr2)
	protocolFeeAddr2, _   = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	launchpadAddr2, _     = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	communityPoolAddr2, _ = access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())

	aliceAddr2         = testutils.TestAddress("alice")
	aliceRealm2        = testing.NewUserRealm(aliceAddr2)
	bobAddr2           = testutils.TestAddress("bob")
	bobRealm2          = testing.NewUserRealm(bobAddr2)
	projectAddr2       = testutils.TestAddress("project-owner")
	projectRealm2      = testing.NewUserRealm(projectAddr2)
	projectRewardAddr2 = testutils.TestAddress("project-reward-owner")
	carolAddr2         = testutils.TestAddress("carol")
	carolRealm2        = testing.NewUserRealm(carolAddr2)

	barPath2 = "gno.land/r/onbloc/bar"
	fooPath2 = "gno.land/r/onbloc/foo"
	fee2     = uint32(3000)

	launchpadProjectID string
	launchpadDepositID string
	positionCollectID  uint64
	stakerPositionID   uint64
	undelegatedAmount  int64 = 1000000

	directPoolTickLower int32 = -120
	directPoolTickUpper int32 = 120
	directPoolLiquidity       = "1000000"
	externalIncentiveID string

	textProposalID            int64
	communityPoolProposalID   int64
	parameterChangeProposalID int64
)

func main(cur realm) {
	println("[SCENARIO] 1. Setup collect paths before emergency mode")
	setupCollectScenario(cur)
	println()

	println("[SCENARIO] 2. Set emergency mode")
	setEmergencyModeForCollect(cur)
	println()

	println("[SCENARIO] 3. position.CollectFee remains allowed")
	testPositionCollectAllowed(cur)
	println()

	println("[SCENARIO] 4. position.DecreaseLiquidity remains allowed")
	testPositionDecreaseAllowed(cur)
	println()

	println("[SCENARIO] 5. staker.CollectReward remains allowed")
	testStakerCollectAllowed(cur)
	println()

	println("[SCENARIO] 6. staker.UnStakeToken remains allowed")
	testStakerUnstakeAllowed(cur)
	println()

	println("[SCENARIO] 7. protocol_fee.DistributeProtocolFee remains allowed")
	testProtocolFeeDistributeAllowed(cur)
	println()

	println("[SCENARIO] 8. gov_staker.Undelegate remains allowed")
	testGovStakerUndDelegateAllowed(cur)
	println()

	println("[SCENARIO] 9. gov_staker.CollectReward remains allowed")
	testGovStakerCollectAllowed(cur)
	println()

	println("[SCENARIO] 10. gov_staker.CollectUndelegatedGns remains allowed")
	testGovStakerCollectUndelegatedAllowed(cur)
	println()

	println("[SCENARIO] 11. launchpad.CollectRewardByDepositId remains allowed")
	testLaunchpadCollectRewardAllowed(cur)
	println()

	println("[SCENARIO] 12. launchpad.CollectDepositGns remains allowed")
	testLaunchpadCollectDepositAllowed(cur)
	println()

	println("[SCENARIO] 13. launchpad.CollectProtocolFee remains allowed")
	testLaunchpadCollectProtocolFeeAllowed(cur)
	println()

	println("[SCENARIO] 14. community_pool.TransferToken remains allowed")
	testCommunityPoolTransferAllowed(cur)
	println()

	println("[SCENARIO] 15. pool.Burn remains allowed")
	testPoolBurnAllowed(cur)
	println()

	println("[SCENARIO] 16. pool.Collect remains allowed")
	testPoolCollectAllowed(cur)
	println()

	println("[SCENARIO] 17. pool.HandleWithdrawalFee remains allowed")
	testPoolHandleWithdrawalFeeAllowed(cur)
	println()

	println("[SCENARIO] 18. pool.CollectProtocol remains allowed")
	testPoolCollectProtocolAllowed(cur)
	println()

	println("[SCENARIO] 19. staker.EndExternalIncentive remains allowed")
	testStakerEndExternalIncentiveAllowed(cur)
	println()

	println("[SCENARIO] 20. staker.CollectExternalIncentivePenalty remains allowed")
	testStakerCollectExternalIncentivePenaltyAllowed(cur)
	println()

	println("[SCENARIO] 21. gov_staker.CollectRewardFromLaunchPad remains allowed")
	testGovStakerCollectRewardFromLaunchPadAllowed(cur)
	println()

	println("[SCENARIO] 22. gov_staker.SetAmountByProjectWallet(add=false) remains allowed")
	testGovStakerSetAmountByProjectWalletRemoveAllowed(cur)
	println()

	println("[SCENARIO] 23. xgns.Burn remains allowed")
	testXGnsBurnAllowed(cur)
	println()

	println("[SCENARIO] 24. governance.ProposeText remains allowed")
	testGovernanceProposeTextAllowed(cur)
	println()

	println("[SCENARIO] 25. governance.Cancel remains allowed")
	testGovernanceCancelAllowed(cur)
	println()

	println("[SCENARIO] 26. governance.ProposeCommunityPoolSpend remains allowed")
	testGovernanceProposeCommunityPoolSpendAllowed(cur)
	println()

	println("[SCENARIO] 27. governance.ProposeParameterChange remains allowed")
	testGovernanceProposeParameterChangeAllowed(cur)
	println()

	println("[SCENARIO] 28. governance.Vote remains allowed")
	testGovernanceVoteAllowed(cur)
	println()

	println("[SCENARIO] 29. governance.Execute remains allowed")
	testGovernanceExecuteAllowed(cur)
	println()

	println("[SCENARIO] 30. governance.Reconfigure remains allowed")
	testGovernanceReconfigureAllowed(cur)
	println()
}

func setupCollectScenario(cur realm) {
	testing.SetRealm(adminRealm2)
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	testing.SkipHeights(1)
	pool.SetPoolCreationFee(cross(cur), 0)
	bar.Transfer(cross(cur), aliceAddr2, 2000000000)
	foo.Transfer(cross(cur), aliceAddr2, 100000000)
	gns.Transfer(cross(cur), aliceAddr2, 5000000000)
	gns.Transfer(cross(cur), bobAddr2, 5000000000)
	gns.Transfer(cross(cur), projectAddr2, 5000000000)
	gns.Transfer(cross(cur), carolAddr2, 5000000000)
	pool.CreatePool(cross(cur), barPath2, fooPath2, fee2, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	pool.SetFeeProtocol(cross(cur), 10, 10)
	staker.SetPoolTier(cross(cur), barPath2+":"+fooPath2+":3000", 1)
	staker.AddToken(cross(cur), barPath2)
	obl.Approve(cross(cur), launchpadAddr2, 1000000000)
	launchpadProjectID = launchpad.CreateProject(cross(cur), "Bar Project", "gno.land/r/onbloc/obl", projectAddr2, 1000000000, "gno.land/r/onbloc/bar", "1000000", 10, 20, 70, time.Now().Unix()+604800)
	testing.SkipHeights(120960)
	gns.Approve(cross(cur), launchpadAddr2, 1000000000)
	launchpadDepositID = launchpad.DepositGns(cross(cur), launchpadProjectID+":30", 1000000000, "")
	testing.SetRealm(testing.NewUserRealm(launchpadAddr2))
	govstaker.SetAmountByProjectWallet(cross(cur), projectAddr2, 1, true)
	govstaker.SetAmountByProjectWallet(cross(cur), projectRewardAddr2, 1000000000, true)
	testing.SetRealm(adminRealm2)
	testing.SkipHeights(51840)
	testing.SkipHeights(466560)
	bar.Transfer(cross(cur), communityPoolAddr2, 10)
	bar.Transfer(cross(cur), stakerAddr2, 1000)

	testing.SetRealm(aliceRealm2)
	bar.Approve(cross(cur), poolAddr2, collectInt64Max)
	foo.Approve(cross(cur), poolAddr2, collectInt64Max)
	bar.Approve(cross(cur), stakerAddr2, collectInt64Max)
	gns.Approve(cross(cur), stakerAddr2, collectInt64Max)
	prepareDirectPoolPosition(cur)
	prepareExternalIncentive(cur)
	positionCollectID, _, _, _ = position.Mint(cross(cur), barPath2, fooPath2, fee2, -960, 960, "50000000", "50000000", "0", "0", 4102444800, aliceAddr2, "")
	stakerPositionID, _, _, _ = position.Mint(cross(cur), barPath2, fooPath2, fee2, -60, 60, "5000000", "5000000", "1", "1", 4102444800, aliceAddr2, "")
	gnft.Approve(cross(cur), stakerAddr2, positionIdFromCollect(cur, stakerPositionID))
	staker.StakeToken(cross(cur), stakerPositionID, "")
	executeEmergencyCollectFeeSwaps(cur)

	testing.SetRealm(bobRealm2)
	gns.Approve(cross(cur), govStakerAddr2, 5000000)
	govstaker.Delegate(cross(cur), bobAddr2, 5000000, "")
	prepareGovernanceVoters(cur)
	testing.SetRealm(adminRealm2)
	govstaker.SetUnDelegationLockupPeriodByAdmin(cross(cur), 0)
	testing.SetRealm(bobRealm2)
	govstaker.Undelegate(cross(cur), bobAddr2, undelegatedAmount)

	testing.SetRealm(stakerRealm2)
	bar.Approve(cross(cur), protocolFeeAddr2, 1000)
	pf.AddToProtocolFee(cross(cur), barPath2, 1000)
	testing.SkipHeights(10)
	testing.SetRealm(govStakerRealm2)
	emission.MintAndDistributeGns(cross(cur))
	pf.DistributeProtocolFee(cross(cur))
	testing.SetRealm(adminRealm2)
	bar.Transfer(cross(cur), stakerAddr2, 1000000)
	testing.SetRealm(stakerRealm2)
	bar.Approve(cross(cur), protocolFeeAddr2, 1000000)
	pf.AddToProtocolFee(cross(cur), barPath2, 1000000)

	ufmt.Printf("[INFO] position collect id: %d\n", positionCollectID)
	ufmt.Printf("[INFO] staker collect position id: %d\n", stakerPositionID)
	ufmt.Println("[INFO] gov staker and launchpad collect paths prepared")
}

func executeEmergencyCollectFeeSwaps(cur realm) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	pool.Swap(cross(cur), barPath2, fooPath2, fee2, adminAddr2, true, "100000", collectMinPrice, adminAddr2, func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
		return emergencyCollectSwapCallback(cur, amount0Delta, amount1Delta)
	})
	pool.Swap(cross(cur), barPath2, fooPath2, fee2, adminAddr2, false, "100000", collectMaxPrice, adminAddr2, func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
		return emergencyCollectSwapCallback(cur, amount0Delta, amount1Delta)
	})
}

func emergencyCollectSwapCallback(cur realm, amount0Delta, amount1Delta int64) error {
	testing.SetRealm(adminRealm2)
	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross(cur), barPath2, poolAddr2, amount0Delta)
	}
	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross(cur), fooPath2, poolAddr2, amount1Delta)
	}
	return nil
}

func prepareDirectPoolPosition(cur realm) {
	testing.SetRealm(positionRealm2)
	pool.Mint(cross(cur), barPath2, fooPath2, fee2, directPoolTickLower, directPoolTickUpper, directPoolLiquidity, aliceAddr2)
}

func prepareExternalIncentive(cur realm) {
	testing.SetRealm(aliceRealm2)
	createdAt := time.Now().Unix()
	startAt := createdAt - createdAt%86400 + 86400*2
	endAt := startAt + 86400*90
	externalIncentiveID = ufmt.Sprintf("%s:%d:1", aliceAddr2.String(), createdAt)
	staker.CreateExternalIncentive(cross(cur), barPath2+":"+fooPath2+":3000", barPath2, 1000000000, startAt, endAt)
	testing.SkipHeights(endAt - createdAt + 1)
}

func prepareGovernanceVoters(cur realm) {
	testing.SetRealm(aliceRealm2)
	gns.Approve(cross(cur), govStakerAddr2, 2000000000)
	govstaker.Delegate(cross(cur), aliceAddr2, 2000000000, "")
	testing.SetRealm(projectRealm2)
	gns.Approve(cross(cur), govStakerAddr2, 2000000000)
	govstaker.Delegate(cross(cur), projectAddr2, 2000000000, "")
	testing.SetRealm(carolRealm2)
	gns.Approve(cross(cur), govStakerAddr2, 2000000000)
	govstaker.Delegate(cross(cur), carolAddr2, 2000000000, "")
}

func setEmergencyModeForCollect(cur realm) {
	testing.SetRealm(adminRealm2)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)
	ufmt.Printf("[INFO] Position halted: %t\n", halt.IsHaltedPosition())
	ufmt.Printf("[INFO] Staker halted: %t\n", halt.IsHaltedStaker())
	ufmt.Printf("[INFO] GovStaker halted: %t\n", halt.IsHaltedGovStaker())
	ufmt.Printf("[INFO] Launchpad halted: %t\n", halt.IsHaltedLaunchpad())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func testPositionCollectAllowed(cur realm) {
	testing.SetRealm(aliceRealm2)
	_, collected0, collected1, _, raw0, raw1 := position.CollectFee(cross(cur), positionCollectID)
	assertPositiveString(cur, collected0, "position.CollectFee collected0")
	assertPositiveString(cur, collected1, "position.CollectFee collected1")
	assertPositiveString(cur, raw0, "position.CollectFee raw0")
	assertPositiveString(cur, raw1, "position.CollectFee raw1")
	ufmt.Printf("[EXPECTED] position.CollectFee collected0: %s, collected1: %s, raw0: %s, raw1: %s\n", collected0, collected1, raw0, raw1)
	ufmt.Println("[EXPECTED] position.CollectFee succeeded in emergency mode")
}

func testPositionDecreaseAllowed(cur realm) {
	testing.SetRealm(aliceRealm2)
	_, liquidity, fee0, fee1, amount0, amount1, _ := position.DecreaseLiquidity(cross(cur), positionCollectID, "1000000", "0", "0", 4102444800)
	ufmt.Printf("[EXPECTED] position.DecreaseLiquidity liquidity: %s, fee0: %s, fee1: %s, amount0: %s, amount1: %s\n", liquidity, fee0, fee1, amount0, amount1)
	ufmt.Println("[EXPECTED] position.DecreaseLiquidity succeeded in emergency mode")
}

func testStakerCollectAllowed(cur realm) {
	testing.SetRealm(aliceRealm2)
	_, gnsAmount, externalRewards, externalPenalties := staker.CollectReward(cross(cur), stakerPositionID)
	ufmt.Printf("[EXPECTED] staker.CollectReward gnsAmount: %s, externalRewards: %d, externalPenalties: %d\n", gnsAmount, len(externalRewards), len(externalPenalties))
	ufmt.Println("[EXPECTED] staker.CollectReward succeeded in emergency mode")
}

func testStakerUnstakeAllowed(cur realm) {
	testing.SetRealm(aliceRealm2)
	staker.UnStakeToken(cross(cur), stakerPositionID)
	ufmt.Println("[EXPECTED] staker.UnStakeToken succeeded in emergency mode")
}

func testGovStakerUndDelegateAllowed(cur realm) {
	testing.SetRealm(bobRealm2)
	govstaker.Undelegate(cross(cur), bobAddr2, undelegatedAmount)
	ufmt.Println("[EXPECTED] gov_staker.Undelegate succeeded in emergency mode")
}

func testGovStakerCollectAllowed(cur realm) {
	testing.SetRealm(bobRealm2)
	beforeGnsBalance := gns.BalanceOf(bobAddr2)
	beforeBarBalance := bar.BalanceOf(bobAddr2)
	govstaker.CollectReward(cross(cur))
	barDelta := bar.BalanceOf(bobAddr2) - beforeBarBalance
	uassert.True(t, barDelta > 0)
	ufmt.Printf("[EXPECTED] gov_staker.CollectReward GNS delta: %d, BAR delta: %d\n", gns.BalanceOf(bobAddr2)-beforeGnsBalance, barDelta)
	ufmt.Println("[EXPECTED] gov_staker.CollectReward succeeded in emergency mode")
}

func testGovStakerCollectUndelegatedAllowed(cur realm) {
	testing.SetRealm(bobRealm2)
	beforeGnsBalance := gns.BalanceOf(bobAddr2)
	collectedAmount := govstaker.CollectUndelegatedGns(cross(cur))
	afterGnsBalance := gns.BalanceOf(bobAddr2)
	uassert.Equal(t, afterGnsBalance-beforeGnsBalance, collectedAmount)
	ufmt.Printf("[EXPECTED] gov_staker.CollectUndelegatedGns amount: %d\n", collectedAmount)
	ufmt.Println("[EXPECTED] gov_staker.CollectUndelegatedGns succeeded in emergency mode")
}

func testProtocolFeeDistributeAllowed(cur realm) {
	testing.SetRealm(govStakerRealm2)
	protocolFeeBarBefore := bar.BalanceOf(protocolFeeAddr2)
	govStakerBarBefore := bar.BalanceOf(govStakerAddr2)
	pf.DistributeProtocolFee(cross(cur))
	barDelta := bar.BalanceOf(govStakerAddr2) - govStakerBarBefore
	uassert.True(t, barDelta > 0)
	uassert.Equal(t, protocolFeeBarBefore-barDelta, bar.BalanceOf(protocolFeeAddr2))
	ufmt.Printf("[EXPECTED] protocol_fee.DistributeProtocolFee BAR amount: %d\n", barDelta)
	ufmt.Println("[EXPECTED] protocol_fee.DistributeProtocolFee succeeded in emergency mode")
}

func testLaunchpadCollectRewardAllowed(cur realm) {
	testing.SetRealm(adminRealm2)
	beforeOblBalance := obl.BalanceOf(adminAddr2)
	launchpad.CollectRewardByDepositId(cross(cur), launchpadDepositID)
	collectedObl := obl.BalanceOf(adminAddr2) - beforeOblBalance
	uassert.True(t, collectedObl > 0)
	ufmt.Printf("[EXPECTED] launchpad.CollectRewardByDepositId OBL amount: %d\n", collectedObl)
	ufmt.Println("[EXPECTED] launchpad.CollectRewardByDepositId succeeded in emergency mode")
}

func testLaunchpadCollectDepositAllowed(cur realm) {
	testing.SetRealm(adminRealm2)
	beforeGnsBalance := gns.BalanceOf(adminAddr2)
	withdrawnAmount, withdrawErr := launchpad.CollectDepositGns(cross(cur), launchpadDepositID)
	if withdrawErr != nil {
		panic(withdrawErr)
	}
	uassert.Equal(t, int64(1000000000), withdrawnAmount)
	uassert.Equal(t, beforeGnsBalance+withdrawnAmount, gns.BalanceOf(adminAddr2))
	ufmt.Printf("[EXPECTED] launchpad.CollectDepositGns amount: %d\n", withdrawnAmount)
	ufmt.Println("[EXPECTED] launchpad.CollectDepositGns succeeded in emergency mode")
}

func testLaunchpadCollectProtocolFeeAllowed(cur realm) {
	testing.SetRealm(projectRealm2)
	beforeBarBalance := bar.BalanceOf(projectAddr2)
	launchpad.CollectProtocolFee(cross(cur))
	barDelta := bar.BalanceOf(projectAddr2) - beforeBarBalance
	uassert.True(t, barDelta > 0)
	ufmt.Printf("[EXPECTED] launchpad.CollectProtocolFee BAR delta: %d\n", barDelta)
	ufmt.Println("[EXPECTED] launchpad.CollectProtocolFee succeeded in emergency mode")
}

func testCommunityPoolTransferAllowed(cur realm) {
	testing.SetRealm(adminRealm2)
	beforeCommunityTransfer := bar.BalanceOf(bobAddr2)
	communitypool.TransferToken(cross(cur), barPath2, bobAddr2, 1)
	uassert.Equal(t, beforeCommunityTransfer+1, bar.BalanceOf(bobAddr2))
	ufmt.Println("[EXPECTED] community_pool.TransferToken amount: 1")
	ufmt.Println("[EXPECTED] community_pool.TransferToken succeeded in emergency mode")
}

func testPoolBurnAllowed(cur realm) {
	testing.SetRealm(positionRealm2)
	amount0, amount1 := pool.Burn(cross(cur), barPath2, fooPath2, fee2, directPoolTickLower, directPoolTickUpper, "1000", aliceAddr2)
	ufmt.Printf("[EXPECTED] pool.Burn amount0: %s, amount1: %s\n", amount0, amount1)
	ufmt.Println("[EXPECTED] pool.Burn succeeded in emergency mode")
}

func testPoolCollectAllowed(cur realm) {
	testing.SetRealm(positionRealm2)
	amount0, amount1 := pool.Collect(cross(cur), barPath2, fooPath2, fee2, aliceAddr2, directPoolTickLower, directPoolTickUpper, strconv.FormatInt(collectInt64Max, 10), strconv.FormatInt(collectInt64Max, 10))
	assertPositiveString(cur, amount0, "pool.Collect amount0")
	assertPositiveString(cur, amount1, "pool.Collect amount1")
	ufmt.Printf("[EXPECTED] pool.Collect amount0: %s, amount1: %s\n", amount0, amount1)
	ufmt.Println("[EXPECTED] pool.Collect succeeded in emergency mode")
}

func testPoolHandleWithdrawalFeeAllowed(cur realm) {
	testing.SetRealm(positionRealm2)
	fee0, fee1, net0, net1 := pool.HandleWithdrawalFee(cross(cur), barPath2, "1000", fooPath2, "1000", aliceAddr2)
	ufmt.Printf("[EXPECTED] pool.HandleWithdrawalFee fee0: %s, fee1: %s, net0: %s, net1: %s\n", fee0, fee1, net0, net1)
	ufmt.Println("[EXPECTED] pool.HandleWithdrawalFee succeeded in emergency mode")
}

func testPoolCollectProtocolAllowed(cur realm) {
	testing.SetRealm(adminRealm2)
	amount0, amount1 := pool.CollectProtocol(cross(cur), barPath2, fooPath2, fee2, adminAddr2, "1000", "1000")
	assertPositiveString(cur, amount0, "pool.CollectProtocol amount0")
	assertPositiveString(cur, amount1, "pool.CollectProtocol amount1")
	ufmt.Printf("[EXPECTED] pool.CollectProtocol amount0: %s, amount1: %s\n", amount0, amount1)
	ufmt.Println("[EXPECTED] pool.CollectProtocol succeeded in emergency mode")
}

func testStakerEndExternalIncentiveAllowed(cur realm) {
	testing.SetRealm(aliceRealm2)
	beforeBarBalance := bar.BalanceOf(aliceAddr2)
	beforeGnsBalance := gns.BalanceOf(aliceAddr2)
	staker.EndExternalIncentive(cross(cur), barPath2+":"+fooPath2+":3000", externalIncentiveID, aliceAddr2)
	ufmt.Printf("[EXPECTED] staker.EndExternalIncentive BAR delta: %d, GNS delta: %d\n", bar.BalanceOf(aliceAddr2)-beforeBarBalance, gns.BalanceOf(aliceAddr2)-beforeGnsBalance)
	ufmt.Println("[EXPECTED] staker.EndExternalIncentive succeeded in emergency mode")
}

func testStakerCollectExternalIncentivePenaltyAllowed(cur realm) {
	testing.SetRealm(aliceRealm2)
	penaltyAmount := staker.CollectExternalIncentivePenalty(cross(cur), barPath2+":"+fooPath2+":3000", externalIncentiveID, aliceAddr2)
	ufmt.Printf("[EXPECTED] staker.CollectExternalIncentivePenalty amount: %d\n", penaltyAmount)
	ufmt.Println("[EXPECTED] staker.CollectExternalIncentivePenalty succeeded in emergency mode")
}

func testGovStakerCollectRewardFromLaunchPadAllowed(cur realm) {
	testing.SetRealm(testing.NewUserRealm(launchpadAddr2))
	beforeBarBalance := bar.BalanceOf(projectRewardAddr2)
	beforeGnsBalance := gns.BalanceOf(projectRewardAddr2)
	govstaker.CollectRewardFromLaunchPad(cross(cur), projectRewardAddr2)
	barDelta := bar.BalanceOf(projectRewardAddr2) - beforeBarBalance
	uassert.True(t, barDelta > 0)
	ufmt.Printf("[EXPECTED] gov_staker.CollectRewardFromLaunchPad BAR delta: %d, GNS delta: %d\n", barDelta, gns.BalanceOf(projectRewardAddr2)-beforeGnsBalance)
	ufmt.Println("[EXPECTED] gov_staker.CollectRewardFromLaunchPad succeeded in emergency mode")
}

func testGovStakerSetAmountByProjectWalletRemoveAllowed(cur realm) {
	testing.SetRealm(testing.NewUserRealm(launchpadAddr2))
	govstaker.SetAmountByProjectWallet(cross(cur), projectAddr2, 1, false)
	ufmt.Println("[EXPECTED] gov_staker.SetAmountByProjectWallet(add=false) amount: 1")
	ufmt.Println("[EXPECTED] gov_staker.SetAmountByProjectWallet(add=false) succeeded in emergency mode")
}

func testXGnsBurnAllowed(cur realm) {
	testing.SetRealm(govStakerRealm2)
	beforeXGnsBalance := xgns.BalanceOf(bobAddr2)
	xgns.Burn(cross(cur), bobAddr2, 1)
	uassert.Equal(t, beforeXGnsBalance-1, xgns.BalanceOf(bobAddr2))
	ufmt.Println("[EXPECTED] xgns.Burn amount: 1")
	ufmt.Println("[EXPECTED] xgns.Burn succeeded in emergency mode")
}

func testGovernanceProposeTextAllowed(cur realm) {
	testing.SetRealm(aliceRealm2)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})
	textProposalID = governance.ProposeText(cross(cur), "Emergency Text Proposal", "Prove governance.ProposeText remains allowed in emergency mode")
	ufmt.Printf("[EXPECTED] governance.ProposeText proposalId: %d\n", textProposalID)
	ufmt.Println("[EXPECTED] governance.ProposeText succeeded in emergency mode")
}

func testGovernanceCancelAllowed(cur realm) {
	testing.SetRealm(aliceRealm2)
	canceledID := governance.Cancel(cross(cur), textProposalID)
	ufmt.Printf("[EXPECTED] governance.Cancel proposalId: %d\n", canceledID)
	ufmt.Println("[EXPECTED] governance.Cancel succeeded in emergency mode")
}

func testGovernanceProposeCommunityPoolSpendAllowed(cur realm) {
	testing.SetRealm(carolRealm2)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})
	communityPoolProposalID = governance.ProposeCommunityPoolSpend(cross(cur), "Emergency Community Spend", "Prove governance.ProposeCommunityPoolSpend remains allowed in emergency mode", carolAddr2, barPath2, 1)
	ufmt.Printf("[EXPECTED] governance.ProposeCommunityPoolSpend proposalId: %d\n", communityPoolProposalID)
	ufmt.Println("[EXPECTED] governance.ProposeCommunityPoolSpend succeeded in emergency mode")
}

func testGovernanceProposeParameterChangeAllowed(cur realm) {
	config := governance.GetLatestConfig()
	executions := ufmt.Sprintf(
		"gno.land/r/gnoswap/gov/governance*EXE*Reconfigure*EXE*%d,%d,%d,%d,%d,%d,%d",
		config.VotingStartDelay,
		config.VotingPeriod,
		config.VotingWeightSmoothingDuration,
		config.Quorum,
		config.ProposalCreationThreshold,
		config.ExecutionDelay,
		config.ExecutionWindow+100,
	)
	testing.SetRealm(projectRealm2)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})
	parameterChangeProposalID = governance.ProposeParameterChange(cross(cur), "Emergency Parameter Change", "Prove governance.ProposeParameterChange remains allowed in emergency mode", 1, executions)
	ufmt.Printf("[EXPECTED] governance.ProposeParameterChange proposalId: %d\n", parameterChangeProposalID)
	ufmt.Println("[EXPECTED] governance.ProposeParameterChange succeeded in emergency mode")
}

func testGovernanceVoteAllowed(cur realm) {
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingStartDelay) / collectCurrentBlockTime)
	testing.SetRealm(aliceRealm2)
	aliceVote := governance.Vote(cross(cur), parameterChangeProposalID, true)
	testing.SetRealm(carolRealm2)
	carolVote := governance.Vote(cross(cur), parameterChangeProposalID, true)
	ufmt.Printf("[EXPECTED] governance.Vote alice: %s, carol: %s\n", aliceVote, carolVote)
	ufmt.Println("[EXPECTED] governance.Vote succeeded in emergency mode")
}

func testGovernanceExecuteAllowed(cur realm) {
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingPeriod) / collectCurrentBlockTime)
	testing.SetRealm(bobRealm2)
	executedID := governance.Execute(cross(cur), parameterChangeProposalID)
	ufmt.Printf("[EXPECTED] governance.Execute proposalId: %d\n", executedID)
	ufmt.Println("[EXPECTED] governance.Execute succeeded in emergency mode")
}

func testGovernanceReconfigureAllowed(cur realm) {
	config := governance.GetLatestConfig()
	testing.SetRealm(adminRealm2)
	version := governance.Reconfigure(cross(cur), config.VotingStartDelay, config.VotingPeriod, config.VotingWeightSmoothingDuration, config.Quorum, config.ProposalCreationThreshold, config.ExecutionDelay, config.ExecutionWindow+100)
	ufmt.Printf("[EXPECTED] governance.Reconfigure version: %d\n", version)
	ufmt.Println("[EXPECTED] governance.Reconfigure succeeded in emergency mode")
}

func positionIdFromCollect(cur realm, positionId any) grc721.TokenID {
	switch positionId.(type) {
	case int:
		return grc721.TokenID(strconv.Itoa(positionId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId.(uint64))))
	case grc721.TokenID:
		return positionId.(grc721.TokenID)
	default:
		panic("unsupported positionId type")
	}
}

func assertPositiveString(cur realm, value string, label string) {
	parsed, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		panic(err)
	}
	uassert.True(t, parsed > 0)
}

// Output:
// [SCENARIO] 1. Setup collect paths before emergency mode
// [INFO] position collect id: 1
// [INFO] staker collect position id: 2
// [INFO] gov staker and launchpad collect paths prepared
//
// [SCENARIO] 2. Set emergency mode
// [INFO] Position halted: true
// [INFO] Staker halted: true
// [INFO] GovStaker halted: true
// [INFO] Launchpad halted: true
// [INFO] Withdraw halted: false
//
// [SCENARIO] 3. position.CollectFee remains allowed
// [EXPECTED] position.CollectFee collected0: 104, collected1: 104, raw0: 105, raw1: 105
// [EXPECTED] position.CollectFee succeeded in emergency mode
//
// [SCENARIO] 4. position.DecreaseLiquidity remains allowed
// [EXPECTED] position.DecreaseLiquidity liquidity: 1000000, fee0: 0, fee1: 0, amount0: 46863, amount1: 46863
// [EXPECTED] position.DecreaseLiquidity succeeded in emergency mode
//
// [SCENARIO] 5. staker.CollectReward remains allowed
// [EXPECTED] staker.CollectReward gnsAmount: 93642955, externalRewards: 0, externalPenalties: 0
// [EXPECTED] staker.CollectReward succeeded in emergency mode
//
// [SCENARIO] 6. staker.UnStakeToken remains allowed
// [EXPECTED] staker.UnStakeToken succeeded in emergency mode
//
// [SCENARIO] 7. protocol_fee.DistributeProtocolFee remains allowed
// [EXPECTED] protocol_fee.DistributeProtocolFee BAR amount: 1000000
// [EXPECTED] protocol_fee.DistributeProtocolFee succeeded in emergency mode
//
// [SCENARIO] 8. gov_staker.Undelegate remains allowed
// [EXPECTED] gov_staker.Undelegate succeeded in emergency mode
//
// [SCENARIO] 9. gov_staker.CollectReward remains allowed
// [EXPECTED] gov_staker.CollectReward GNS delta: 0, BAR delta: 500
// [EXPECTED] gov_staker.CollectReward succeeded in emergency mode
//
// [SCENARIO] 10. gov_staker.CollectUndelegatedGns remains allowed
// [EXPECTED] gov_staker.CollectUndelegatedGns amount: 2000000
// [EXPECTED] gov_staker.CollectUndelegatedGns succeeded in emergency mode
//
// [SCENARIO] 11. launchpad.CollectRewardByDepositId remains allowed
// [EXPECTED] launchpad.CollectRewardByDepositId OBL amount: 99999999
// [EXPECTED] launchpad.CollectRewardByDepositId succeeded in emergency mode
//
// [SCENARIO] 12. launchpad.CollectDepositGns remains allowed
// [EXPECTED] launchpad.CollectDepositGns amount: 1000000000
// [EXPECTED] launchpad.CollectDepositGns succeeded in emergency mode
//
// [SCENARIO] 13. launchpad.CollectProtocolFee remains allowed
// [EXPECTED] launchpad.CollectProtocolFee BAR delta: 125062
// [EXPECTED] launchpad.CollectProtocolFee succeeded in emergency mode
//
// [SCENARIO] 14. community_pool.TransferToken remains allowed
// [EXPECTED] community_pool.TransferToken amount: 1
// [EXPECTED] community_pool.TransferToken succeeded in emergency mode
//
// [SCENARIO] 15. pool.Burn remains allowed
// [EXPECTED] pool.Burn amount0: 5, amount1: 5
// [EXPECTED] pool.Burn succeeded in emergency mode
//
// [SCENARIO] 16. pool.Collect remains allowed
// [EXPECTED] pool.Collect amount0: 5, amount1: 5
// [EXPECTED] pool.Collect succeeded in emergency mode
//
// [SCENARIO] 17. pool.HandleWithdrawalFee remains allowed
// [EXPECTED] pool.HandleWithdrawalFee fee0: 10, fee1: 10, net0: 990, net1: 990
// [EXPECTED] pool.HandleWithdrawalFee succeeded in emergency mode
//
// [SCENARIO] 18. pool.CollectProtocol remains allowed
// [EXPECTED] pool.CollectProtocol amount0: 30, amount1: 30
// [EXPECTED] pool.CollectProtocol succeeded in emergency mode
//
// [SCENARIO] 19. staker.EndExternalIncentive remains allowed
// [EXPECTED] staker.EndExternalIncentive BAR delta: 1000000000, GNS delta: 1000000000
// [EXPECTED] staker.EndExternalIncentive succeeded in emergency mode
//
// [SCENARIO] 20. staker.CollectExternalIncentivePenalty remains allowed
// [EXPECTED] staker.CollectExternalIncentivePenalty amount: 0
// [EXPECTED] staker.CollectExternalIncentivePenalty succeeded in emergency mode
//
// [SCENARIO] 21. gov_staker.CollectRewardFromLaunchPad remains allowed
// [EXPECTED] gov_staker.CollectRewardFromLaunchPad BAR delta: 125062, GNS delta: 0
// [EXPECTED] gov_staker.CollectRewardFromLaunchPad succeeded in emergency mode
//
// [SCENARIO] 22. gov_staker.SetAmountByProjectWallet(add=false) remains allowed
// [EXPECTED] gov_staker.SetAmountByProjectWallet(add=false) amount: 1
// [EXPECTED] gov_staker.SetAmountByProjectWallet(add=false) succeeded in emergency mode
//
// [SCENARIO] 23. xgns.Burn remains allowed
// [EXPECTED] xgns.Burn amount: 1
// [EXPECTED] xgns.Burn succeeded in emergency mode
//
// [SCENARIO] 24. governance.ProposeText remains allowed
// [EXPECTED] governance.ProposeText proposalId: 1
// [EXPECTED] governance.ProposeText succeeded in emergency mode
//
// [SCENARIO] 25. governance.Cancel remains allowed
// [EXPECTED] governance.Cancel proposalId: 1
// [EXPECTED] governance.Cancel succeeded in emergency mode
//
// [SCENARIO] 26. governance.ProposeCommunityPoolSpend remains allowed
// [EXPECTED] governance.ProposeCommunityPoolSpend proposalId: 2
// [EXPECTED] governance.ProposeCommunityPoolSpend succeeded in emergency mode
//
// [SCENARIO] 27. governance.ProposeParameterChange remains allowed
// [EXPECTED] governance.ProposeParameterChange proposalId: 3
// [EXPECTED] governance.ProposeParameterChange succeeded in emergency mode
//
// [SCENARIO] 28. governance.Vote remains allowed
// [EXPECTED] governance.Vote alice: 1000000000, carol: 1000000000
// [EXPECTED] governance.Vote succeeded in emergency mode
//
// [SCENARIO] 29. governance.Execute remains allowed
// [EXPECTED] governance.Execute proposalId: 3
// [EXPECTED] governance.Execute succeeded in emergency mode
//
// [SCENARIO] 30. governance.Reconfigure remains allowed
// [EXPECTED] governance.Reconfigure version: 3
// [EXPECTED] governance.Reconfigure succeeded in emergency mode
