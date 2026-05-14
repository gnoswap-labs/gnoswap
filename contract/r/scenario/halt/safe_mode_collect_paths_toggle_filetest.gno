// Scenario: Safe Mode blocks delegated protocol-fee collection, while Emergency allows it

package main

import (
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

const (
	safeInt64Max             int64 = 9223372036854775807
	pendingProtocolFeeAmount int64 = 1000
)

var t *testing.T

var (
	adminAddr3, _         = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm3           = testing.NewUserRealm(adminAddr3)
	poolAddr3, _          = access.GetAddress(prbac.ROLE_POOL.String())
	stakerAddr3, _        = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm3          = testing.NewUserRealm(stakerAddr3)
	govStakerAddr3, _     = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm3       = testing.NewUserRealm(govStakerAddr3)
	protocolFeeAddr3, _   = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	launchpadAddr3, _     = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	communityPoolAddr3, _ = access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())

	aliceAddr3    = testutils.TestAddress("alice")
	aliceRealm3   = testing.NewUserRealm(aliceAddr3)
	bobAddr3      = testutils.TestAddress("bob")
	bobRealm3     = testing.NewUserRealm(bobAddr3)
	carolAddr3    = testutils.TestAddress("carol")
	carolRealm3   = testing.NewUserRealm(carolAddr3)
	projectAddr3  = testutils.TestAddress("project-owner")
	projectRealm3 = testing.NewUserRealm(projectAddr3)

	atomPath3 = "gno.land/r/gnoswap/test_token/atom"
	btcPath3 = "gno.land/r/gnoswap/test_token/btc"
	fee3     = uint32(3000)

	launchpadProjectID3 string
	positionCollectID3  uint64
	stakerPositionID3   uint64

	protocolFeeAtomBeforeSafe        int64
	govStakerAtomBeforeSafe          int64
	bobAtomBeforeSafe                int64
	carolAtomBeforeSafe              int64
	launchpadClaimableAtomBeforeSafe int64
)

func main() {
	println("[SCENARIO] 1. Setup collect paths before safe mode")
	setupSafeScenario()
	println()

	println("[SCENARIO] 2. Enable safe mode")
	setSafeModeForCollect()
	println()

	println("[SCENARIO] 3. Collect paths are blocked in safe mode")
	testCollectsBlockedInSafeMode()
	println()

	println("[SCENARIO] 4. Switch to emergency mode")
	setEmergencyModeForProtocolFeeCollect()
	println()

	println("[SCENARIO] 5. Delegated protocol fee collect works in emergency mode")
	testDelegatedProtocolFeeCollectAllowedInEmergencyMode()
	println()
}

func setupSafeScenario() {
	testing.SetRealm(adminRealm3)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	testing.SkipHeights(1)
	pool.SetPoolCreationFee(cross, 0)
	atom.Transfer(cross, aliceAddr3, 100000000)
	btc.Transfer(cross, aliceAddr3, 100000000)
	gns.Transfer(cross, bobAddr3, 5000000)
	gns.Transfer(cross, carolAddr3, 15000000)
	pool.CreatePool(cross, atomPath3, btcPath3, fee3, common.TickMathGetSqrtRatioAtTick(0).ToString())
	staker.SetPoolTier(cross, atomPath3+":"+btcPath3+":3000", 1)
	eth.Approve(cross, launchpadAddr3, 1000000000)
	launchpadProjectID3 = launchpad.CreateProject(cross, "Atom Project", "gno.land/r/gnoswap/test_token/eth", projectAddr3, 1000000000, "gno.land/r/gnoswap/test_token/atom", "1000000", 10, 20, 70, time.Now().Unix()+604800)
	testing.SkipHeights(120960)
	gns.Approve(cross, launchpadAddr3, 1000000000)
	launchpad.DepositGns(cross, launchpadProjectID3+":30", 1000000000, "")
	atom.Transfer(cross, stakerAddr3, 1000)

	testing.SetRealm(aliceRealm3)
	atom.Approve(cross, poolAddr3, safeInt64Max)
	btc.Approve(cross, poolAddr3, safeInt64Max)
	positionCollectID3, _, _, _ = position.Mint(cross, atomPath3, btcPath3, fee3, -960, 960, "50000000", "50000000", "0", "0", 4102444800, aliceAddr3, "")
	stakerPositionID3, _, _, _ = position.Mint(cross, atomPath3, btcPath3, fee3, -60, 60, "5000000", "5000000", "1", "1", 4102444800, aliceAddr3, "")
	gnft.Approve(cross, stakerAddr3, positionIdFromSafe(stakerPositionID3))
	staker.StakeToken(cross, stakerPositionID3, "")

	testing.SetRealm(bobRealm3)
	gns.Approve(cross, govStakerAddr3, 5000000)
	govstaker.Delegate(cross, bobAddr3, 5000000, "")
	testing.SetRealm(carolRealm3)
	gns.Approve(cross, govStakerAddr3, 15000000)
	govstaker.Delegate(cross, carolAddr3, 15000000, "")

	testing.SetRealm(stakerRealm3)
	atom.Approve(cross, protocolFeeAddr3, 1000)
	pf.AddToProtocolFee(cross, atomPath3, 1000)
	testing.SkipHeights(10)
	testing.SetRealm(govStakerRealm3)
	emission.MintAndDistributeGns(cross)
	pf.DistributeProtocolFee(cross)
	_, claimableLaunchpadProtocolFees, claimableLaunchpadErr := govstaker.GetClaimableRewardByLaunchpad(projectAddr3)
	if claimableLaunchpadErr != nil {
		panic(claimableLaunchpadErr)
	}
	launchpadClaimableAtomBeforeSafe = claimableLaunchpadProtocolFees[atomPath3]
	testing.SetRealm(adminRealm3)
	atom.Transfer(cross, stakerAddr3, pendingProtocolFeeAmount)
	testing.SetRealm(stakerRealm3)
	atom.Approve(cross, protocolFeeAddr3, pendingProtocolFeeAmount)
	pf.AddToProtocolFee(cross, atomPath3, pendingProtocolFeeAmount)
	protocolFeeAtomBeforeSafe = atom.BalanceOf(protocolFeeAddr3)
	govStakerAtomBeforeSafe = atom.BalanceOf(govStakerAddr3)
	bobAtomBeforeSafe = atom.BalanceOf(bobAddr3)
	carolAtomBeforeSafe = atom.BalanceOf(carolAddr3)

	ufmt.Printf("[INFO] position collect id: %d\n", positionCollectID3)
	ufmt.Printf("[INFO] staker collect position id: %d\n", stakerPositionID3)
	ufmt.Printf("[INFO] pending protocol fee before safe mode: %d ATOM\n", pendingProtocolFeeAmount)
	ufmt.Printf("[INFO] delegated protocol fee stakers: bob=%d xGNS, carol=%d xGNS\n", 5000000, 15000000)
	ufmt.Printf("[INFO] launchpad claimable ATOM before safe mode: %d\n", launchpadClaimableAtomBeforeSafe)
	ufmt.Println("[INFO] safe mode collect paths prepared")
}

func setSafeModeForCollect() {
	testing.SetRealm(adminRealm3)
	halt.SetHaltLevel(cross, halt.HaltLevelSafeMode)
	ufmt.Printf("[INFO] Position halted: %t\n", halt.IsHaltedPosition())
	ufmt.Printf("[INFO] Staker halted: %t\n", halt.IsHaltedStaker())
	ufmt.Printf("[INFO] GovStaker halted: %t\n", halt.IsHaltedGovStaker())
	ufmt.Printf("[INFO] Launchpad halted: %t\n", halt.IsHaltedLaunchpad())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func testCollectsBlockedInSafeMode() {
	testing.SetRealm(aliceRealm3)
	uassert.AbortsContains(t, "halted: withdraw", func() {
		position.DecreaseLiquidity(cross, positionCollectID3, "1000000", "0", "0", time.Now().Unix()+3600)
	})
	ufmt.Println("[EXPECTED] position decrease liquidity blocked by withdraw halt")

	uassert.AbortsContains(t, "halted: withdraw", func() {
		position.CollectFee(cross, positionCollectID3)
	})
	ufmt.Println("[EXPECTED] position collect fee blocked by withdraw halt")

	uassert.AbortsContains(t, "halted: withdraw", func() {
		pool.Burn(cross, atomPath3, btcPath3, fee3, -960, 960, "1000000", aliceAddr3)
	})
	uassert.AbortsContains(t, "halted: withdraw", func() {
		pool.Collect(cross, atomPath3, btcPath3, fee3, aliceAddr3, -960, 960, "1", "1")
	})
	uassert.AbortsContains(t, "halted: withdraw", func() {
		pool.HandleWithdrawalFee(cross, atomPath3, "1", btcPath3, "1", aliceAddr3)
	})
	uassert.AbortsContains(t, "halted: withdraw", func() {
		pool.CollectProtocol(cross, atomPath3, btcPath3, fee3, aliceAddr3, "1", "1")
	})
	ufmt.Println("[EXPECTED] pool withdraw helpers blocked by withdraw halt")

	uassert.AbortsContains(t, "halted: withdraw", func() {
		staker.CollectReward(cross, stakerPositionID3)
	})
	ufmt.Println("[EXPECTED] staker collect reward blocked by withdraw halt")

	uassert.AbortsContains(t, "halted: withdraw", func() {
		staker.UnStakeToken(cross, stakerPositionID3)
	})
	uassert.AbortsContains(t, "halted: withdraw", func() {
		staker.EndExternalIncentive(cross, atomPath3+":"+btcPath3+":3000", "missing", aliceAddr3)
	})
	uassert.AbortsContains(t, "halted: withdraw", func() {
		staker.CollectExternalIncentivePenalty(cross, atomPath3+":"+btcPath3+":3000", "missing", aliceAddr3)
	})
	ufmt.Println("[EXPECTED] staker recovery helpers blocked by withdraw halt")

	testing.SetRealm(bobRealm3)
	uassert.AbortsContains(t, "halted: withdraw", func() {
		govstaker.CollectUndelegatedGns(cross)
	})
	ufmt.Println("[EXPECTED] gov staker undelegated collect blocked by withdraw halt")

	uassert.AbortsContains(t, "halted: withdraw", func() {
		govstaker.CollectReward(cross)
	})
	ufmt.Printf("[EXPECTED] gov_staker.CollectReward blocked for bob; ATOM before: %d, after: %d\n", bobAtomBeforeSafe, atom.BalanceOf(bobAddr3))
	testing.SetRealm(carolRealm3)
	uassert.AbortsContains(t, "halted: withdraw", func() {
		govstaker.CollectReward(cross)
	})
	ufmt.Printf("[EXPECTED] gov_staker.CollectReward blocked for carol; ATOM before: %d, after: %d\n", carolAtomBeforeSafe, atom.BalanceOf(carolAddr3))
	testing.SetRealm(bobRealm3)
	uassert.AbortsContains(t, "halted: withdraw", func() {
		govstaker.CollectRewardFromLaunchPad(cross, bobAddr3)
	})
	uassert.AbortsContains(t, "halted: withdraw", func() {
		govstaker.SetAmountByProjectWallet(cross, bobAddr3, 1, false)
	})
	ufmt.Println("[EXPECTED] gov staker launchpad reward collect blocked by withdraw halt")

	testing.SetRealm(govStakerRealm3)
	pf.DistributeProtocolFee(cross)
	uassert.Equal(t, protocolFeeAtomBeforeSafe, atom.BalanceOf(protocolFeeAddr3))
	uassert.Equal(t, govStakerAtomBeforeSafe, atom.BalanceOf(govStakerAddr3))
	ufmt.Printf("[EXPECTED] protocol_fee.DistributeProtocolFee in safe mode preserved protocol fee ATOM: %d\n", atom.BalanceOf(protocolFeeAddr3))

	testing.SetRealm(projectRealm3)
	beforeProjectAtomBalance := atom.BalanceOf(projectAddr3)
	uassert.AbortsContains(t, "halted: withdraw", func() {
		launchpad.CollectProtocolFee(cross)
	})
	_, claimableLaunchpadProtocolFeesDuringSafe, claimableLaunchpadErrDuringSafe := govstaker.GetClaimableRewardByLaunchpad(projectAddr3)
	if claimableLaunchpadErrDuringSafe != nil {
		panic(claimableLaunchpadErrDuringSafe)
	}
	uassert.Equal(t, launchpadClaimableAtomBeforeSafe, claimableLaunchpadProtocolFeesDuringSafe[atomPath3])
	uassert.Equal(t, beforeProjectAtomBalance, atom.BalanceOf(projectAddr3))
	ufmt.Println("[EXPECTED] launchpad collect protocol fee blocked by withdraw halt")
	uassert.AbortsContains(t, "halted: withdraw", func() {
		launchpad.CollectDepositGns(cross, "1")
	})
	uassert.AbortsContains(t, "halted: withdraw", func() {
		launchpad.CollectRewardByDepositId(cross, "1")
	})
	ufmt.Println("[EXPECTED] launchpad withdrawal helpers blocked by withdraw halt")

	testing.SetRealm(testing.NewUserRealm(govStakerAddr3))
	uassert.AbortsContains(t, "halted: withdraw", func() {
		xgns.Burn(cross, bobAddr3, 1)
	})
	ufmt.Println("[EXPECTED] xGNS burn blocked by withdraw halt")

	testing.SetRealm(testing.NewUserRealm(communityPoolAddr3))
	uassert.AbortsContains(t, "halted: withdraw", func() {
		communitypool.TransferToken(cross, atomPath3, bobAddr3, 1)
	})
	ufmt.Println("[EXPECTED] community pool transfer blocked by withdraw halt")
}

func setEmergencyModeForProtocolFeeCollect() {
	testing.SetRealm(adminRealm3)
	halt.SetHaltLevel(cross, halt.HaltLevelEmergency)
	ufmt.Printf("[INFO] GovStaker halted: %t\n", halt.IsHaltedGovStaker())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func testDelegatedProtocolFeeCollectAllowedInEmergencyMode() {
	testing.SetRealm(govStakerRealm3)
	pf.DistributeProtocolFee(cross)
	uassert.Equal(t, protocolFeeAtomBeforeSafe-pendingProtocolFeeAmount, atom.BalanceOf(protocolFeeAddr3))
	uassert.Equal(t, govStakerAtomBeforeSafe+pendingProtocolFeeAmount, atom.BalanceOf(govStakerAddr3))
	ufmt.Printf("[EXPECTED] protocol_fee.DistributeProtocolFee distributed ATOM in emergency mode: %d\n", pendingProtocolFeeAmount)

	testing.SetRealm(bobRealm3)
	_, bobProtocolFeeRewards, bobClaimableErr := govstaker.GetClaimableRewardByAddress(bobAddr3)
	if bobClaimableErr != nil {
		panic(bobClaimableErr)
	}
	govstaker.CollectReward(cross)
	bobAtomAfterCollect := atom.BalanceOf(bobAddr3)
	uassert.True(t, bobProtocolFeeRewards[atomPath3] > 0)
	uassert.Equal(t, bobProtocolFeeRewards[atomPath3], bobAtomAfterCollect-bobAtomBeforeSafe)
	ufmt.Printf("[EXPECTED] gov_staker.CollectReward bob ATOM claimable: %d, collected delta: %d\n", bobProtocolFeeRewards[atomPath3], bobAtomAfterCollect-bobAtomBeforeSafe)

	testing.SetRealm(carolRealm3)
	_, carolProtocolFeeRewards, carolClaimableErr := govstaker.GetClaimableRewardByAddress(carolAddr3)
	if carolClaimableErr != nil {
		panic(carolClaimableErr)
	}
	govstaker.CollectReward(cross)
	carolAtomAfterCollect := atom.BalanceOf(carolAddr3)
	uassert.True(t, carolProtocolFeeRewards[atomPath3] > 0)
	uassert.Equal(t, carolProtocolFeeRewards[atomPath3], carolAtomAfterCollect-carolAtomBeforeSafe)
	ufmt.Printf("[EXPECTED] gov_staker.CollectReward carol ATOM claimable: %d, collected delta: %d\n", carolProtocolFeeRewards[atomPath3], carolAtomAfterCollect-carolAtomBeforeSafe)

	testing.SetRealm(projectRealm3)
	_, claimableLaunchpadProtocolFeesAfterDisable, claimableLaunchpadErrAfterDisable := govstaker.GetClaimableRewardByLaunchpad(projectAddr3)
	if claimableLaunchpadErrAfterDisable != nil {
		panic(claimableLaunchpadErrAfterDisable)
	}
	claimableLaunchpadAtomAfterDisable := claimableLaunchpadProtocolFeesAfterDisable[atomPath3]
	if claimableLaunchpadAtomAfterDisable < launchpadClaimableAtomBeforeSafe {
		panic("launchpad claimable ATOM decreased across safe-mode toggle")
	}
	uassert.True(t, claimableLaunchpadAtomAfterDisable > 0)
	beforeProjectAtomBalance := atom.BalanceOf(projectAddr3)
	launchpad.CollectProtocolFee(cross)
	uassert.Equal(t, beforeProjectAtomBalance+claimableLaunchpadAtomAfterDisable, atom.BalanceOf(projectAddr3))
	ufmt.Printf("[EXPECTED] launchpad.CollectProtocolFee ATOM claimable: %d, collected delta: %d\n", claimableLaunchpadAtomAfterDisable, atom.BalanceOf(projectAddr3)-beforeProjectAtomBalance)
}

func positionIdFromSafe(positionId any) grc721.TokenID {
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

// Output:
// [SCENARIO] 1. Setup collect paths before safe mode
// [INFO] position collect id: 1
// [INFO] staker collect position id: 2
// [INFO] pending protocol fee before safe mode: 1000 ATOM
// [INFO] delegated protocol fee stakers: bob=5000000 xGNS, carol=15000000 xGNS
// [INFO] launchpad claimable ATOM before safe mode: 980
// [INFO] safe mode collect paths prepared
//
// [SCENARIO] 2. Enable safe mode
// [INFO] Position halted: false
// [INFO] Staker halted: false
// [INFO] GovStaker halted: false
// [INFO] Launchpad halted: false
// [INFO] Withdraw halted: true
//
// [SCENARIO] 3. Collect paths are blocked in safe mode
// [EXPECTED] position decrease liquidity blocked by withdraw halt
// [EXPECTED] position collect fee blocked by withdraw halt
// [EXPECTED] pool withdraw helpers blocked by withdraw halt
// [EXPECTED] staker collect reward blocked by withdraw halt
// [EXPECTED] staker recovery helpers blocked by withdraw halt
// [EXPECTED] gov staker undelegated collect blocked by withdraw halt
// [EXPECTED] gov_staker.CollectReward blocked for bob; ATOM before: 0, after: 0
// [EXPECTED] gov_staker.CollectReward blocked for carol; ATOM before: 0, after: 0
// [EXPECTED] gov staker launchpad reward collect blocked by withdraw halt
// [EXPECTED] protocol_fee.DistributeProtocolFee in safe mode preserved protocol fee ATOM: 1000
// [EXPECTED] launchpad collect protocol fee blocked by withdraw halt
// [EXPECTED] launchpad withdrawal helpers blocked by withdraw halt
// [EXPECTED] xGNS burn blocked by withdraw halt
// [EXPECTED] community pool transfer blocked by withdraw halt
//
// [SCENARIO] 4. Switch to emergency mode
// [INFO] GovStaker halted: true
// [INFO] Withdraw halted: false
//
// [SCENARIO] 5. Delegated protocol fee collect works in emergency mode
// [EXPECTED] protocol_fee.DistributeProtocolFee distributed ATOM in emergency mode: 1000
// [EXPECTED] gov_staker.CollectReward bob ATOM claimable: 9, collected delta: 9
// [EXPECTED] gov_staker.CollectReward carol ATOM claimable: 29, collected delta: 29
// [EXPECTED] launchpad.CollectProtocolFee ATOM claimable: 1960, collected delta: 1960
