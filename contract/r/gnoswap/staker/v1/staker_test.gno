package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/emission"
	pl "gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
	sr "gno.land/r/gnoswap/staker"
	"gno.land/r/onbloc/bar"

	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/position/v1"
)

const (
	// External incentive timestamps
	incentiveDuration int64 = 90 * 24 * 60 * 60 // 90 days

	rewardMinimumAmount int64 = 1000000000
)

func TestCollectRewardGracefulDegradation(t *testing.T) {
	initStakerTest(t)
	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)
	incentiveStartTimestamp := time.Now().AddDate(0, 0, 1).Truncate(24 * time.Hour).Unix()

	// Test 1: Normal collection with sufficient rewards
	t.Run("normal collection works", func(t *testing.T) {
		testing.SetRealm(adminRealm)
		pl.SetPoolCreationFee(cross, 0)
		emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

		// setup
		govAddr := rbac.DefaultRoleAddresses[prabc.ROLE_GOVERNANCE]
		testing.SetRealm(testing.NewUserRealm(govAddr))

		mockInstanceSetMinimumRewardAmount(1000000000)
		mockInstanceSetUnstakingFee(0)

		// Create pool
		testing.SetRealm(adminRealm)
		pl.CreatePool(cross, barPath, bazPath, fee3000, "79228162514264337593543950336")

		// Set pool tier
		mockInstanceSetPoolTier(poolPath, 1)

		// Give tokens to test user
		TokenFaucet(t, barPath, addr01)
		TokenFaucet(t, bazPath, addr01)
		TokenFaucet(t, gnsPath, addr01)

		// Approve tokens
		testing.SetRealm(testing.NewUserRealm(addr01))
		TokenApprove(t, barPath, addr01, poolAddr, maxApprove)
		TokenApprove(t, bazPath, addr01, poolAddr, maxApprove)

		// Mint position
		positionId, _, _, _ := MintPosition(
			t,
			barPath,
			bazPath,
			fee3000,
			-18000, // Multiple of 60
			18000,  // Multiple of 60
			"1000000",
			"1000000",
			"0",
			"0",
			max_timeout,
			addr01,
			addr01,
		)

		// Stake position
		testing.SetRealm(testing.NewUserRealm(addr01))
		getMockInstance().nftAccessor.Mint(addr01, positionIdFrom(positionId))
		getMockInstance().nftAccessor.Approve(stakerAddr, positionIdFrom(positionId))

		mockInstanceStakeToken(positionId, "")

		// Create external incentive
		testing.SetRealm(adminRealm)
		gns.Approve(cross, stakerAddr, maxApprove)

		mockInstanceCreateExternalIncentive(poolPath, gnsPath, rewardMinimumAmount, incentiveStartTimestamp, incentiveStartTimestamp+incentiveDuration)

		// Wait for external incentive to start (skip to start timestamp)
		// Calculate blocks to skip based on current time vs start timestamp
		// Assuming 2 seconds per block as in scenario test
		currentTime := time.Now().Unix()
		timeToWait := incentiveStartTimestamp - currentTime
		blocksToSkip := timeToWait / 2
		if blocksToSkip > 0 {
			testing.SkipHeights(blocksToSkip)
		}

		// Skip some more blocks to accumulate rewards
		testing.SkipHeights(20)

		testing.SetRealm(testing.NewUserRealm(addr01))

		beforeGns := gns.BalanceOf(addr01)
		beforeBar := bar.BalanceOf(addr01)

		// Should not panic
		mockInstanceCollectReward(positionId, false)

		afterGns := gns.BalanceOf(addr01)
		afterBar := bar.BalanceOf(addr01)

		t.Logf("beforeGns: %d, afterGns: %d", beforeGns, afterGns)
		t.Logf("beforeBar: %d, afterBar: %d", beforeBar, afterBar)

		// Should have received some rewards
		if afterGns <= beforeGns {
			t.Error("expected to receive GNS rewards")
		}
	})

	// Test 2: Create incentive with insufficient reward amount
	t.Run("very small amount of external reward", func(t *testing.T) {
		// Create another position for testing
		testing.SetRealm(testing.NewUserRealm(addr02))
		TokenFaucet(t, barPath, addr02)
		TokenFaucet(t, bazPath, addr02)
		TokenApprove(t, barPath, addr02, poolAddr, maxApprove)
		TokenApprove(t, bazPath, addr02, poolAddr, maxApprove)

		positionId2, _, _, _ := MintPosition(
			t,
			barPath,
			bazPath,
			fee3000,
			-18000,
			18000,
			"1000000",
			"1000000",
			"0",
			"0",
			max_timeout,
			addr02,
			addr02,
		)

		getMockInstance().nftAccessor.Mint(addr02, positionIdFrom(positionId2))
		getMockInstance().nftAccessor.Approve(stakerAddr, positionIdFrom(positionId2))
		mockInstanceStakeToken(positionId2, "")

		// Create external incentive with very small amount
		testing.SetRealm(adminRealm)
		bar.Approve(cross, stakerAddr, 100)

		expectedMsg := "[GNOSWAP-STAKER-007] invalid input data || rewardAmount(100) is less than minimum required amount(1000000000)"
		uassert.AbortsWithMessage(t, expectedMsg, func() {
			mockInstanceCreateExternalIncentive(poolPath, barPath, 100, incentiveStartTimestamp, incentiveStartTimestamp+incentiveDuration)
		})
	})
}

// CollectReward should not process the same external penalty multiple times
// when an incentive is missing/archived but the deposit's reward state is kept.
func TestCollectReward_ExternalPenaltyNotDoubleCountedWhenIncentiveMissing(t *testing.T) {
	initStakerTest(t)

	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	CreatePool(barPath, bazPath, fee3000, "79228162514264337593543950336", adminAddr)
	mockInstanceSetPoolTier(poolPath, 1)
	mockInstanceAddToken(barPath)

	// Prepare user liquidity and stake.
	TokenFaucet(t, barPath, addr01)
	TokenFaucet(t, bazPath, addr01)

	testing.SetRealm(testing.NewUserRealm(addr01))
	TokenApprove(t, barPath, addr01, poolAddr, maxApprove)
	TokenApprove(t, bazPath, addr01, poolAddr, maxApprove)

	positionId, _, _, _ := MintPosition(
		t,
		barPath,
		bazPath,
		fee3000,
		-18000,
		18000,
		"1000000",
		"1000000",
		"0",
		"0",
		max_timeout,
		addr01,
		addr01,
	)

	getMockInstance().nftAccessor.Mint(addr01, positionIdFrom(positionId))
	getMockInstance().nftAccessor.Approve(stakerAddr, positionIdFrom(positionId))
	mockInstanceStakeToken(positionId, "")

	// Fund caller for incentive creation.
	TokenFaucet(t, gnsPath, addr01)
	TokenFaucet(t, barPath, addr01)

	// Create an external incentive that has already started.
	testing.SetRealm(testing.NewUserRealm(addr01))
	gnsApprove(t, addr01, stakerAddr, maxApprove)
	barApprove(t, addr01, stakerAddr, maxApprove)

	startTimestamp := int64(1234569600)
	mockInstanceCreateExternalIncentive(
		poolPath,
		barPath,
		rewardMinimumAmount,
		startTimestamp,
		startTimestamp+incentiveDuration,
	)

	// Allow some rewards to accrue.
	testing.SkipHeights(3600)

	// Locate the incentive ID and mutate the stored amount to simulate missing metadata/funds.
	incentives := getMockInstance().getExternalIncentives()
	incentiveId := ""
	var incentive *sr.ExternalIncentive
	incentives.tree.Iterate("", "", func(key string, value any) bool {
		if incentive == nil {
			incentiveId = key
			incentive = value.(*sr.ExternalIncentive)
		}
		return false
	})

	if incentive == nil {
		t.Fatal("expected incentive to be created")
	}

	originalRewardAmount := incentive.RewardAmount()
	incentive.SetRewardAmount(0)
	incentives.set(incentiveId, incentive)

	// First collect should skip external processing because rewardAmount is zero.
	testing.SetRealm(testing.NewUserRealm(addr01))
	communityPoolBefore := TokenBalance(t, barPath, communityPoolAddr)
	resolver := getMockInstance().getDepositResolver(positionId)
	firstLastCollect := resolver.ExternalRewardLastCollectTime(incentiveId)

	mockInstanceCollectReward(positionId, false)

	resolver = getMockInstance().getDepositResolver(positionId)
	uassert.Equal(t, firstLastCollect, resolver.ExternalRewardLastCollectTime(incentiveId))
	uassert.Equal(t, int64(0), resolver.CollectedExternalReward(incentiveId))
	uassert.Equal(t, communityPoolBefore, TokenBalance(t, barPath, communityPoolAddr))

	// Restore reward amount and collect again; penalty should be processed once.
	incentive.SetRewardAmount(originalRewardAmount)
	incentives.set(incentiveId, incentive)

	communityPoolBefore = TokenBalance(t, barPath, communityPoolAddr)
	mockInstanceCollectReward(positionId, false)

	resolver = getMockInstance().getDepositResolver(positionId)
	communityPoolAfter := TokenBalance(t, barPath, communityPoolAddr)
	penaltyDelta := communityPoolAfter - communityPoolBefore
	if penaltyDelta <= 0 {
		t.Fatalf("expected external penalty to be applied once, got %d", penaltyDelta)
	}
	collectedAfter := resolver.CollectedExternalReward(incentiveId)
	if collectedAfter == 0 {
		t.Fatal("expected external reward to be collected after incentive recovery")
	}
	lastCollectAfter := resolver.ExternalRewardLastCollectTime(incentiveId)

	// Subsequent collect in the same second should not apply the penalty again.
	mockInstanceCollectReward(positionId, false)
	resolver = getMockInstance().getDepositResolver(positionId)
	uassert.Equal(t, communityPoolAfter, TokenBalance(t, barPath, communityPoolAddr))
	uassert.Equal(t, collectedAfter, resolver.CollectedExternalReward(incentiveId))
	uassert.Equal(t, lastCollectAfter, resolver.ExternalRewardLastCollectTime(incentiveId))
}
