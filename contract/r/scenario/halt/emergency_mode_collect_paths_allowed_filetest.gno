// Scenario: Emergency Mode keeps collect paths available

// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"strconv"
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
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"
	"gno.land/r/gnoswap/test_token/eth"
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

	atomPath2 = "gno.land/r/gnoswap/test_token/atom"
	btcPath2 = "gno.land/r/gnoswap/test_token/btc"
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

func main() {
	println("[SCENARIO] 1. Setup collect paths before emergency mode")
	setupCollectScenario()
	println()

	println("[SCENARIO] 2. Set emergency mode")
	setEmergencyModeForCollect()
	println()

	println("[SCENARIO] 3. position.CollectFee remains allowed")
	testPositionCollectAllowed()
	println()

	println("[SCENARIO] 4. position.DecreaseLiquidity remains allowed")
	testPositionDecreaseAllowed()
	println()

	println("[SCENARIO] 5. staker.CollectReward remains allowed")
	testStakerCollectAllowed()
	println()

	println("[SCENARIO] 6. staker.UnStakeToken remains allowed")
	testStakerUnstakeAllowed()
	println()

	println("[SCENARIO] 7. protocol_fee.DistributeProtocolFee remains allowed")
	testProtocolFeeDistributeAllowed()
	println()

	println("[SCENARIO] 8. gov_staker.CollectReward remains allowed")
	testGovStakerCollectAllowed()
	println()

	println("[SCENARIO] 9. gov_staker.CollectUndelegatedGns remains allowed")
	testGovStakerCollectUndelegatedAllowed()
	println()

	println("[SCENARIO] 10. launchpad.CollectRewardByDepositId remains allowed")
	testLaunchpadCollectRewardAllowed()
	println()

	println("[SCENARIO] 11. launchpad.CollectDepositGns remains allowed")
	testLaunchpadCollectDepositAllowed()
	println()

	println("[SCENARIO] 12. launchpad.CollectProtocolFee remains allowed")
	testLaunchpadCollectProtocolFeeAllowed()
	println()

	println("[SCENARIO] 13. community_pool.TransferToken remains allowed")
	testCommunityPoolTransferAllowed()
	println()

	println("[SCENARIO] 14. pool.Burn remains allowed")
	testPoolBurnAllowed()
	println()

	println("[SCENARIO] 15. pool.Collect remains allowed")
	testPoolCollectAllowed()
	println()

	println("[SCENARIO] 16. pool.HandleWithdrawalFee remains allowed")
	testPoolHandleWithdrawalFeeAllowed()
	println()

	println("[SCENARIO] 17. pool.CollectProtocol remains allowed")
	testPoolCollectProtocolAllowed()
	println()

	println("[SCENARIO] 18. staker.EndExternalIncentive remains allowed")
	testStakerEndExternalIncentiveAllowed()
	println()

	println("[SCENARIO] 19. staker.CollectExternalIncentivePenalty remains allowed")
	testStakerCollectExternalIncentivePenaltyAllowed()
	println()

	println("[SCENARIO] 20. gov_staker.CollectRewardFromLaunchPad remains allowed")
	testGovStakerCollectRewardFromLaunchPadAllowed()
	println()

	println("[SCENARIO] 21. gov_staker.SetAmountByProjectWallet(add=false) remains allowed")
	testGovStakerSetAmountByProjectWalletRemoveAllowed()
	println()

	println("[SCENARIO] 22. xgns.Burn remains allowed")
	testXGnsBurnAllowed()
	println()

	println("[SCENARIO] 23. governance.ProposeText remains allowed")
	testGovernanceProposeTextAllowed()
	println()

	println("[SCENARIO] 24. governance.Cancel remains allowed")
	testGovernanceCancelAllowed()
	println()

	println("[SCENARIO] 25. governance.ProposeCommunityPoolSpend remains allowed")
	testGovernanceProposeCommunityPoolSpendAllowed()
	println()

	println("[SCENARIO] 26. governance.ProposeParameterChange remains allowed")
	testGovernanceProposeParameterChangeAllowed()
	println()

	println("[SCENARIO] 27. governance.Vote remains allowed")
	testGovernanceVoteAllowed()
	println()

	println("[SCENARIO] 28. governance.Execute remains allowed")
	testGovernanceExecuteAllowed()
	println()

	println("[SCENARIO] 29. governance.Reconfigure remains allowed")
	testGovernanceReconfigureAllowed()
	println()
}

func setupCollectScenario() {
	testing.SetRealm(adminRealm2)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	testing.SkipHeights(1)
	pool.SetPoolCreationFee(cross, 0)
	atom.Transfer(cross, aliceAddr2, 2000000000)
	btc.Transfer(cross, aliceAddr2, 100000000)
	gns.Transfer(cross, aliceAddr2, 5000000000)
	gns.Transfer(cross, bobAddr2, 5000000000)
	gns.Transfer(cross, projectAddr2, 5000000000)
	gns.Transfer(cross, carolAddr2, 5000000000)
	pool.CreatePool(cross, atomPath2, btcPath2, fee2, common.TickMathGetSqrtRatioAtTick(0).ToString())
	pool.SetFeeProtocol(cross, 10, 10)
	staker.SetPoolTier(cross, atomPath2+":"+btcPath2+":3000", 1)
	staker.AddToken(cross, atomPath2)
	eth.Approve(cross, launchpadAddr2, 1000000000)
	launchpadProjectID = launchpad.CreateProject(cross, "Atom Project", "gno.land/r/gnoswap/test_token/eth", projectAddr2, 1000000000, "gno.land/r/gnoswap/test_token/atom", "1000000", 10, 20, 70, time.Now().Unix()+604800)
	testing.SkipHeights(120960)
	gns.Approve(cross, launchpadAddr2, 1000000000)
	launchpadDepositID = launchpad.DepositGns(cross, launchpadProjectID+":30", 1000000000, "")
	testing.SetRealm(testing.NewUserRealm(launchpadAddr2))
	govstaker.SetAmountByProjectWallet(cross, projectAddr2, 1, true)
	govstaker.SetAmountByProjectWallet(cross, projectRewardAddr2, 1000000000, true)
	testing.SetRealm(adminRealm2)
	testing.SkipHeights(51840)
	testing.SkipHeights(466560)
	atom.Transfer(cross, communityPoolAddr2, 10)
	atom.Transfer(cross, stakerAddr2, 1000)

	testing.SetRealm(aliceRealm2)
	atom.Approve(cross, poolAddr2, collectInt64Max)
	btc.Approve(cross, poolAddr2, collectInt64Max)
	atom.Approve(cross, stakerAddr2, collectInt64Max)
	gns.Approve(cross, stakerAddr2, collectInt64Max)
	prepareDirectPoolPosition()
	prepareExternalIncentive()
	positionCollectID, _, _, _ = position.Mint(cross, atomPath2, btcPath2, fee2, -960, 960, "50000000", "50000000", "0", "0", 4102444800, aliceAddr2, "")
	stakerPositionID, _, _, _ = position.Mint(cross, atomPath2, btcPath2, fee2, -60, 60, "5000000", "5000000", "1", "1", 4102444800, aliceAddr2, "")
	gnft.Approve(cross, stakerAddr2, positionIdFromCollect(stakerPositionID))
	staker.StakeToken(cross, stakerPositionID, "")
	executeEmergencyCollectFeeSwaps()

	testing.SetRealm(bobRealm2)
	gns.Approve(cross, govStakerAddr2, 5000000)
	govstaker.Delegate(cross, bobAddr2, 5000000, "")
	prepareGovernanceVoters()
	testing.SetRealm(adminRealm2)
	govstaker.SetUnDelegationLockupPeriodByAdmin(cross, 0)
	testing.SetRealm(bobRealm2)
	govstaker.Undelegate(cross, bobAddr2, undelegatedAmount)

	testing.SetRealm(stakerRealm2)
	atom.Approve(cross, protocolFeeAddr2, 1000)
	pf.AddToProtocolFee(cross, atomPath2, 1000)
	testing.SkipHeights(10)
	testing.SetRealm(govStakerRealm2)
	emission.MintAndDistributeGns(cross)
	pf.DistributeProtocolFee(cross)
	testing.SetRealm(adminRealm2)
	atom.Transfer(cross, stakerAddr2, 1000000)
	testing.SetRealm(stakerRealm2)
	atom.Approve(cross, protocolFeeAddr2, 1000000)
	pf.AddToProtocolFee(cross, atomPath2, 1000000)

	ufmt.Printf("[INFO] position collect id: %d\n", positionCollectID)
	ufmt.Printf("[INFO] staker collect position id: %d\n", stakerPositionID)
	ufmt.Println("[INFO] gov staker and launchpad collect paths prepared")
}

func executeEmergencyCollectFeeSwaps() {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	pool.Swap(cross, atomPath2, btcPath2, fee2, adminAddr2, true, "10000000", collectMinPrice, adminAddr2, func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
		return emergencyCollectSwapCallback(amount0Delta, amount1Delta)
	})
	pool.Swap(cross, atomPath2, btcPath2, fee2, adminAddr2, false, "10000000", collectMaxPrice, adminAddr2, func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
		return emergencyCollectSwapCallback(amount0Delta, amount1Delta)
	})
}

func emergencyCollectSwapCallback(amount0Delta, amount1Delta int64) error {
	testing.SetRealm(adminRealm2)
	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross, atomPath2, poolAddr2, amount0Delta)
	}
	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross, btcPath2, poolAddr2, amount1Delta)
	}
	return nil
}

func prepareDirectPoolPosition() {
	testing.SetRealm(positionRealm2)
	pool.Mint(cross, atomPath2, btcPath2, fee2, directPoolTickLower, directPoolTickUpper, directPoolLiquidity, aliceAddr2)
}

func prepareExternalIncentive() {
	testing.SetRealm(aliceRealm2)
	createdAt := time.Now().Unix()
	startAt := createdAt - createdAt%86400 + 86400*2
	endAt := startAt + 86400*90
	externalIncentiveID = ufmt.Sprintf("%s:%d:1", aliceAddr2.String(), createdAt)
	staker.CreateExternalIncentive(cross, atomPath2+":"+btcPath2+":3000", atomPath2, 1000000000, startAt, endAt)
	testing.SkipHeights(endAt - createdAt + 1)
}

func prepareGovernanceVoters() {
	testing.SetRealm(aliceRealm2)
	gns.Approve(cross, govStakerAddr2, 2000000000)
	govstaker.Delegate(cross, aliceAddr2, 2000000000, "")
	testing.SetRealm(projectRealm2)
	gns.Approve(cross, govStakerAddr2, 2000000000)
	govstaker.Delegate(cross, projectAddr2, 2000000000, "")
	testing.SetRealm(carolRealm2)
	gns.Approve(cross, govStakerAddr2, 2000000000)
	govstaker.Delegate(cross, carolAddr2, 2000000000, "")
}

func setEmergencyModeForCollect() {
	testing.SetRealm(adminRealm2)
	halt.SetHaltLevel(cross, halt.HaltLevelEmergency)
	ufmt.Printf("[INFO] Position halted: %t\n", halt.IsHaltedPosition())
	ufmt.Printf("[INFO] Staker halted: %t\n", halt.IsHaltedStaker())
	ufmt.Printf("[INFO] GovStaker halted: %t\n", halt.IsHaltedGovStaker())
	ufmt.Printf("[INFO] Launchpad halted: %t\n", halt.IsHaltedLaunchpad())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func testPositionCollectAllowed() {
	testing.SetRealm(aliceRealm2)
	_, collected0, collected1, _, raw0, raw1 := position.CollectFee(cross, positionCollectID)
	assertPositiveString(collected0, "position.CollectFee collected0")
	assertPositiveString(collected1, "position.CollectFee collected1")
	assertPositiveString(raw0, "position.CollectFee raw0")
	assertPositiveString(raw1, "position.CollectFee raw1")
	ufmt.Printf("[EXPECTED] position.CollectFee collected0: %s, collected1: %s, raw0: %s, raw1: %s\n", collected0, collected1, raw0, raw1)
	ufmt.Println("[EXPECTED] position.CollectFee succeeded in emergency mode")
}

func testPositionDecreaseAllowed() {
	testing.SetRealm(aliceRealm2)
	_, liquidity, fee0, fee1, amount0, amount1, _ := position.DecreaseLiquidity(cross, positionCollectID, "1000000", "0", "0", 4102444800)
	ufmt.Printf("[EXPECTED] position.DecreaseLiquidity liquidity: %s, fee0: %s, fee1: %s, amount0: %s, amount1: %s\n", liquidity, fee0, fee1, amount0, amount1)
	ufmt.Println("[EXPECTED] position.DecreaseLiquidity succeeded in emergency mode")
}

func testStakerCollectAllowed() {
	testing.SetRealm(aliceRealm2)
	_, gnsAmount, externalRewards, externalPenalties := staker.CollectReward(cross, stakerPositionID)
	ufmt.Printf("[EXPECTED] staker.CollectReward gnsAmount: %s, externalRewards: %d, externalPenalties: %d\n", gnsAmount, len(externalRewards), len(externalPenalties))
	ufmt.Println("[EXPECTED] staker.CollectReward succeeded in emergency mode")
}

func testStakerUnstakeAllowed() {
	testing.SetRealm(aliceRealm2)
	staker.UnStakeToken(cross, stakerPositionID)
	ufmt.Println("[EXPECTED] staker.UnStakeToken succeeded in emergency mode")
}

func testGovStakerCollectAllowed() {
	testing.SetRealm(bobRealm2)
	beforeGnsBalance := gns.BalanceOf(bobAddr2)
	beforeAtomBalance := atom.BalanceOf(bobAddr2)
	govstaker.CollectReward(cross)
	atomDelta := atom.BalanceOf(bobAddr2) - beforeAtomBalance
	uassert.True(t, atomDelta > 0)
	ufmt.Printf("[EXPECTED] gov_staker.CollectReward GNS delta: %d, ATOM delta: %d\n", gns.BalanceOf(bobAddr2)-beforeGnsBalance, atomDelta)
	ufmt.Println("[EXPECTED] gov_staker.CollectReward succeeded in emergency mode")
}

func testGovStakerCollectUndelegatedAllowed() {
	testing.SetRealm(bobRealm2)
	beforeGnsBalance := gns.BalanceOf(bobAddr2)
	collectedAmount := govstaker.CollectUndelegatedGns(cross)
	uassert.Equal(t, undelegatedAmount, collectedAmount)
	uassert.Equal(t, beforeGnsBalance+undelegatedAmount, gns.BalanceOf(bobAddr2))
	ufmt.Printf("[EXPECTED] gov_staker.CollectUndelegatedGns amount: %d\n", collectedAmount)
	ufmt.Println("[EXPECTED] gov_staker.CollectUndelegatedGns succeeded in emergency mode")
}

func testProtocolFeeDistributeAllowed() {
	testing.SetRealm(govStakerRealm2)
	protocolFeeAtomBefore := atom.BalanceOf(protocolFeeAddr2)
	govStakerAtomBefore := atom.BalanceOf(govStakerAddr2)
	pf.DistributeProtocolFee(cross)
	atomDelta := atom.BalanceOf(govStakerAddr2) - govStakerAtomBefore
	uassert.True(t, atomDelta > 0)
	uassert.Equal(t, protocolFeeAtomBefore-atomDelta, atom.BalanceOf(protocolFeeAddr2))
	ufmt.Printf("[EXPECTED] protocol_fee.DistributeProtocolFee ATOM amount: %d\n", atomDelta)
	ufmt.Println("[EXPECTED] protocol_fee.DistributeProtocolFee succeeded in emergency mode")
}

func testLaunchpadCollectRewardAllowed() {
	testing.SetRealm(adminRealm2)
	beforeEthBalance := eth.BalanceOf(adminAddr2)
	launchpad.CollectRewardByDepositId(cross, launchpadDepositID)
	collectedEth := eth.BalanceOf(adminAddr2) - beforeEthBalance
	uassert.True(t, collectedEth > 0)
	ufmt.Printf("[EXPECTED] launchpad.CollectRewardByDepositId ETH amount: %d\n", collectedEth)
	ufmt.Println("[EXPECTED] launchpad.CollectRewardByDepositId succeeded in emergency mode")
}

func testLaunchpadCollectDepositAllowed() {
	testing.SetRealm(adminRealm2)
	beforeGnsBalance := gns.BalanceOf(adminAddr2)
	withdrawnAmount, withdrawErr := launchpad.CollectDepositGns(cross, launchpadDepositID)
	if withdrawErr != nil {
		panic(withdrawErr)
	}
	uassert.Equal(t, int64(1000000000), withdrawnAmount)
	uassert.Equal(t, beforeGnsBalance+withdrawnAmount, gns.BalanceOf(adminAddr2))
	ufmt.Printf("[EXPECTED] launchpad.CollectDepositGns amount: %d\n", withdrawnAmount)
	ufmt.Println("[EXPECTED] launchpad.CollectDepositGns succeeded in emergency mode")
}

func testLaunchpadCollectProtocolFeeAllowed() {
	testing.SetRealm(projectRealm2)
	beforeAtomBalance := atom.BalanceOf(projectAddr2)
	launchpad.CollectProtocolFee(cross)
	atomDelta := atom.BalanceOf(projectAddr2) - beforeAtomBalance
	uassert.True(t, atomDelta > 0)
	ufmt.Printf("[EXPECTED] launchpad.CollectProtocolFee ATOM delta: %d\n", atomDelta)
	ufmt.Println("[EXPECTED] launchpad.CollectProtocolFee succeeded in emergency mode")
}

func testCommunityPoolTransferAllowed() {
	testing.SetRealm(adminRealm2)
	beforeCommunityTransfer := atom.BalanceOf(bobAddr2)
	communitypool.TransferToken(cross, atomPath2, bobAddr2, 1)
	uassert.Equal(t, beforeCommunityTransfer+1, atom.BalanceOf(bobAddr2))
	ufmt.Println("[EXPECTED] community_pool.TransferToken amount: 1")
	ufmt.Println("[EXPECTED] community_pool.TransferToken succeeded in emergency mode")
}

func testPoolBurnAllowed() {
	testing.SetRealm(positionRealm2)
	amount0, amount1 := pool.Burn(cross, atomPath2, btcPath2, fee2, directPoolTickLower, directPoolTickUpper, "1000", aliceAddr2)
	ufmt.Printf("[EXPECTED] pool.Burn amount0: %s, amount1: %s\n", amount0, amount1)
	ufmt.Println("[EXPECTED] pool.Burn succeeded in emergency mode")
}

func testPoolCollectAllowed() {
	testing.SetRealm(positionRealm2)
	amount0, amount1 := pool.Collect(cross, atomPath2, btcPath2, fee2, aliceAddr2, directPoolTickLower, directPoolTickUpper, strconv.FormatInt(collectInt64Max, 10), strconv.FormatInt(collectInt64Max, 10))
	assertPositiveString(amount0, "pool.Collect amount0")
	assertPositiveString(amount1, "pool.Collect amount1")
	ufmt.Printf("[EXPECTED] pool.Collect amount0: %s, amount1: %s\n", amount0, amount1)
	ufmt.Println("[EXPECTED] pool.Collect succeeded in emergency mode")
}

func testPoolHandleWithdrawalFeeAllowed() {
	testing.SetRealm(positionRealm2)
	fee0, fee1, net0, net1 := pool.HandleWithdrawalFee(cross, atomPath2, "1000", btcPath2, "1000", aliceAddr2)
	ufmt.Printf("[EXPECTED] pool.HandleWithdrawalFee fee0: %s, fee1: %s, net0: %s, net1: %s\n", fee0, fee1, net0, net1)
	ufmt.Println("[EXPECTED] pool.HandleWithdrawalFee succeeded in emergency mode")
}

func testPoolCollectProtocolAllowed() {
	testing.SetRealm(adminRealm2)
	amount0, amount1 := pool.CollectProtocol(cross, atomPath2, btcPath2, fee2, adminAddr2, "1000", "1000")
	assertPositiveString(amount0, "pool.CollectProtocol amount0")
	assertPositiveString(amount1, "pool.CollectProtocol amount1")
	ufmt.Printf("[EXPECTED] pool.CollectProtocol amount0: %s, amount1: %s\n", amount0, amount1)
	ufmt.Println("[EXPECTED] pool.CollectProtocol succeeded in emergency mode")
}

func testStakerEndExternalIncentiveAllowed() {
	testing.SetRealm(aliceRealm2)
	beforeAtomBalance := atom.BalanceOf(aliceAddr2)
	beforeGnsBalance := gns.BalanceOf(aliceAddr2)
	staker.EndExternalIncentive(cross, atomPath2+":"+btcPath2+":3000", externalIncentiveID, aliceAddr2)
	ufmt.Printf("[EXPECTED] staker.EndExternalIncentive ATOM delta: %d, GNS delta: %d\n", atom.BalanceOf(aliceAddr2)-beforeAtomBalance, gns.BalanceOf(aliceAddr2)-beforeGnsBalance)
	ufmt.Println("[EXPECTED] staker.EndExternalIncentive succeeded in emergency mode")
}

func testStakerCollectExternalIncentivePenaltyAllowed() {
	testing.SetRealm(aliceRealm2)
	penaltyAmount := staker.CollectExternalIncentivePenalty(cross, atomPath2+":"+btcPath2+":3000", externalIncentiveID, aliceAddr2)
	ufmt.Printf("[EXPECTED] staker.CollectExternalIncentivePenalty amount: %d\n", penaltyAmount)
	ufmt.Println("[EXPECTED] staker.CollectExternalIncentivePenalty succeeded in emergency mode")
}

func testGovStakerCollectRewardFromLaunchPadAllowed() {
	testing.SetRealm(testing.NewUserRealm(launchpadAddr2))
	beforeAtomBalance := atom.BalanceOf(projectRewardAddr2)
	beforeGnsBalance := gns.BalanceOf(projectRewardAddr2)
	govstaker.CollectRewardFromLaunchPad(cross, projectRewardAddr2)
	atomDelta := atom.BalanceOf(projectRewardAddr2) - beforeAtomBalance
	uassert.True(t, atomDelta > 0)
	ufmt.Printf("[EXPECTED] gov_staker.CollectRewardFromLaunchPad ATOM delta: %d, GNS delta: %d\n", atomDelta, gns.BalanceOf(projectRewardAddr2)-beforeGnsBalance)
	ufmt.Println("[EXPECTED] gov_staker.CollectRewardFromLaunchPad succeeded in emergency mode")
}

func testGovStakerSetAmountByProjectWalletRemoveAllowed() {
	testing.SetRealm(testing.NewUserRealm(launchpadAddr2))
	govstaker.SetAmountByProjectWallet(cross, projectAddr2, 1, false)
	ufmt.Println("[EXPECTED] gov_staker.SetAmountByProjectWallet(add=false) amount: 1")
	ufmt.Println("[EXPECTED] gov_staker.SetAmountByProjectWallet(add=false) succeeded in emergency mode")
}

func testXGnsBurnAllowed() {
	testing.SetRealm(govStakerRealm2)
	beforeXGnsBalance := xgns.BalanceOf(bobAddr2)
	xgns.Burn(cross, bobAddr2, 1)
	uassert.Equal(t, beforeXGnsBalance-1, xgns.BalanceOf(bobAddr2))
	ufmt.Println("[EXPECTED] xgns.Burn amount: 1")
	ufmt.Println("[EXPECTED] xgns.Burn succeeded in emergency mode")
}

func testGovernanceProposeTextAllowed() {
	testing.SetRealm(aliceRealm2)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})
	textProposalID = governance.ProposeText(cross, "Emergency Text Proposal", "Prove governance.ProposeText remains allowed in emergency mode")
	ufmt.Printf("[EXPECTED] governance.ProposeText proposalId: %d\n", textProposalID)
	ufmt.Println("[EXPECTED] governance.ProposeText succeeded in emergency mode")
}

func testGovernanceCancelAllowed() {
	testing.SetRealm(aliceRealm2)
	canceledID := governance.Cancel(cross, textProposalID)
	ufmt.Printf("[EXPECTED] governance.Cancel proposalId: %d\n", canceledID)
	ufmt.Println("[EXPECTED] governance.Cancel succeeded in emergency mode")
}

func testGovernanceProposeCommunityPoolSpendAllowed() {
	testing.SetRealm(carolRealm2)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000000}})
	communityPoolProposalID = governance.ProposeCommunityPoolSpend(cross, "Emergency Community Spend", "Prove governance.ProposeCommunityPoolSpend remains allowed in emergency mode", carolAddr2, atomPath2, 1)
	ufmt.Printf("[EXPECTED] governance.ProposeCommunityPoolSpend proposalId: %d\n", communityPoolProposalID)
	ufmt.Println("[EXPECTED] governance.ProposeCommunityPoolSpend succeeded in emergency mode")
}

func testGovernanceProposeParameterChangeAllowed() {
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
	parameterChangeProposalID = governance.ProposeParameterChange(cross, "Emergency Parameter Change", "Prove governance.ProposeParameterChange remains allowed in emergency mode", 1, executions)
	ufmt.Printf("[EXPECTED] governance.ProposeParameterChange proposalId: %d\n", parameterChangeProposalID)
	ufmt.Println("[EXPECTED] governance.ProposeParameterChange succeeded in emergency mode")
}

func testGovernanceVoteAllowed() {
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingStartDelay) / collectCurrentBlockTime)
	testing.SetRealm(aliceRealm2)
	aliceVote := governance.Vote(cross, parameterChangeProposalID, true)
	testing.SetRealm(carolRealm2)
	carolVote := governance.Vote(cross, parameterChangeProposalID, true)
	ufmt.Printf("[EXPECTED] governance.Vote alice: %s, carol: %s\n", aliceVote, carolVote)
	ufmt.Println("[EXPECTED] governance.Vote succeeded in emergency mode")
}

func testGovernanceExecuteAllowed() {
	config := governance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingPeriod) / collectCurrentBlockTime)
	testing.SetRealm(bobRealm2)
	executedID := governance.Execute(cross, parameterChangeProposalID)
	ufmt.Printf("[EXPECTED] governance.Execute proposalId: %d\n", executedID)
	ufmt.Println("[EXPECTED] governance.Execute succeeded in emergency mode")
}

func testGovernanceReconfigureAllowed() {
	config := governance.GetLatestConfig()
	testing.SetRealm(adminRealm2)
	version := governance.Reconfigure(cross, config.VotingStartDelay, config.VotingPeriod, config.VotingWeightSmoothingDuration, config.Quorum, config.ProposalCreationThreshold, config.ExecutionDelay, config.ExecutionWindow+100)
	ufmt.Printf("[EXPECTED] governance.Reconfigure version: %d\n", version)
	ufmt.Println("[EXPECTED] governance.Reconfigure succeeded in emergency mode")
}

func positionIdFromCollect(positionId any) grc721.TokenID {
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

func assertPositiveString(value string, label string) {
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
// [EXPECTED] position.CollectFee collected0: 13273, collected1: 13252, raw0: 13407, raw1: 13385
// [EXPECTED] position.CollectFee succeeded in emergency mode
//
// [SCENARIO] 4. position.DecreaseLiquidity remains allowed
// [EXPECTED] position.DecreaseLiquidity liquidity: 1000000, fee0: 0, fee1: 0, amount0: 46850, amount1: 46877
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
// [EXPECTED] protocol_fee.DistributeProtocolFee ATOM amount: 1000000
// [EXPECTED] protocol_fee.DistributeProtocolFee succeeded in emergency mode
//
// [SCENARIO] 8. gov_staker.CollectReward remains allowed
// [EXPECTED] gov_staker.CollectReward GNS delta: 0, ATOM delta: 500
// [EXPECTED] gov_staker.CollectReward succeeded in emergency mode
//
// [SCENARIO] 9. gov_staker.CollectUndelegatedGns remains allowed
// [EXPECTED] gov_staker.CollectUndelegatedGns amount: 1000000
// [EXPECTED] gov_staker.CollectUndelegatedGns succeeded in emergency mode
//
// [SCENARIO] 10. launchpad.CollectRewardByDepositId remains allowed
// [EXPECTED] launchpad.CollectRewardByDepositId ETH amount: 99999999
// [EXPECTED] launchpad.CollectRewardByDepositId succeeded in emergency mode
//
// [SCENARIO] 11. launchpad.CollectDepositGns remains allowed
// [EXPECTED] launchpad.CollectDepositGns amount: 1000000000
// [EXPECTED] launchpad.CollectDepositGns succeeded in emergency mode
//
// [SCENARIO] 12. launchpad.CollectProtocolFee remains allowed
// [EXPECTED] launchpad.CollectProtocolFee ATOM delta: 125062
// [EXPECTED] launchpad.CollectProtocolFee succeeded in emergency mode
//
// [SCENARIO] 13. community_pool.TransferToken remains allowed
// [EXPECTED] community_pool.TransferToken amount: 1
// [EXPECTED] community_pool.TransferToken succeeded in emergency mode
//
// [SCENARIO] 14. pool.Burn remains allowed
// [EXPECTED] pool.Burn amount0: 5, amount1: 5
// [EXPECTED] pool.Burn succeeded in emergency mode
//
// [SCENARIO] 15. pool.Collect remains allowed
// [EXPECTED] pool.Collect amount0: 17, amount1: 17
// [EXPECTED] pool.Collect succeeded in emergency mode
//
// [SCENARIO] 16. pool.HandleWithdrawalFee remains allowed
// [EXPECTED] pool.HandleWithdrawalFee fee0: 10, fee1: 10, net0: 990, net1: 990
// [EXPECTED] pool.HandleWithdrawalFee succeeded in emergency mode
//
// [SCENARIO] 17. pool.CollectProtocol remains allowed
// [EXPECTED] pool.CollectProtocol amount0: 1000, amount1: 1000
// [EXPECTED] pool.CollectProtocol succeeded in emergency mode
//
// [SCENARIO] 18. staker.EndExternalIncentive remains allowed
// [EXPECTED] staker.EndExternalIncentive ATOM delta: 1000000000, GNS delta: 1000000000
// [EXPECTED] staker.EndExternalIncentive succeeded in emergency mode
//
// [SCENARIO] 19. staker.CollectExternalIncentivePenalty remains allowed
// [EXPECTED] staker.CollectExternalIncentivePenalty amount: 0
// [EXPECTED] staker.CollectExternalIncentivePenalty succeeded in emergency mode
//
// [SCENARIO] 20. gov_staker.CollectRewardFromLaunchPad remains allowed
// [EXPECTED] gov_staker.CollectRewardFromLaunchPad ATOM delta: 125062, GNS delta: 0
// [EXPECTED] gov_staker.CollectRewardFromLaunchPad succeeded in emergency mode
//
// [SCENARIO] 21. gov_staker.SetAmountByProjectWallet(add=false) remains allowed
// [EXPECTED] gov_staker.SetAmountByProjectWallet(add=false) amount: 1
// [EXPECTED] gov_staker.SetAmountByProjectWallet(add=false) succeeded in emergency mode
//
// [SCENARIO] 22. xgns.Burn remains allowed
// [EXPECTED] xgns.Burn amount: 1
// [EXPECTED] xgns.Burn succeeded in emergency mode
//
// [SCENARIO] 23. governance.ProposeText remains allowed
// [EXPECTED] governance.ProposeText proposalId: 1
// [EXPECTED] governance.ProposeText succeeded in emergency mode
//
// [SCENARIO] 24. governance.Cancel remains allowed
// [EXPECTED] governance.Cancel proposalId: 1
// [EXPECTED] governance.Cancel succeeded in emergency mode
//
// [SCENARIO] 25. governance.ProposeCommunityPoolSpend remains allowed
// [EXPECTED] governance.ProposeCommunityPoolSpend proposalId: 2
// [EXPECTED] governance.ProposeCommunityPoolSpend succeeded in emergency mode
//
// [SCENARIO] 26. governance.ProposeParameterChange remains allowed
// [EXPECTED] governance.ProposeParameterChange proposalId: 3
// [EXPECTED] governance.ProposeParameterChange succeeded in emergency mode
//
// [SCENARIO] 27. governance.Vote remains allowed
// [EXPECTED] governance.Vote alice: 1000000000, carol: 1000000000
// [EXPECTED] governance.Vote succeeded in emergency mode
//
// [SCENARIO] 28. governance.Execute remains allowed
// [EXPECTED] governance.Execute proposalId: 3
// [EXPECTED] governance.Execute succeeded in emergency mode
//
// [SCENARIO] 29. governance.Reconfigure remains allowed
// [EXPECTED] governance.Reconfigure version: 3
// [EXPECTED] governance.Reconfigure succeeded in emergency mode
