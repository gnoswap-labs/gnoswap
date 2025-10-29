package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/emission"
	pl "gno.land/r/gnoswap/v1/pool"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
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
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	// setup
	govAddr := rbac.DefaultRoleAddresses[prabc.ROLE_GOVERNANCE]
	testing.SetOriginCaller(govAddr)

	func(cur realm) {
		testing.SetRealm(stakerRealm)
		getMockInstance().SetMinimumRewardAmount(1000000000)
	}(cross)

	func(cur realm) {
		testing.SetRealm(stakerRealm)
		getMockInstance().SetUnStakingFee(0)
	}(cross)

	testing.SetOriginCaller(adminAddr)

	// Create pool
	pl.SetPoolCreationFee(cross, 0)
	CreatePool(t, barPath, bazPath, fee3000, "79228162514264337593543950336", adminAddr)

	// Set pool tier
	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)
	func(cur realm) {
		testing.SetRealm(stakerRealm)
		getMockInstance().SetPoolTier(poolPath, 1)
	}(cross)

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
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))

	func(cur realm) {
		testing.SetRealm(stakerRealm)
		getMockInstance().StakeToken(positionId, "")
	}(cross)

	// Create external incentive
	testing.SetRealm(adminRealm)
	gns.Approve(cross, stakerAddr, maxApprove)
	incentiveStartTimestamp := time.Now().AddDate(0, 0, 1).Truncate(24 * time.Hour).Unix()

	func(cur realm) {
		testing.SetRealm(stakerRealm)
		getMockInstance().CreateExternalIncentive(
			poolPath,
			gnsPath,
			rewardMinimumAmount,
			incentiveStartTimestamp,
			incentiveStartTimestamp+incentiveDuration,
		)
	}(cross)

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

	// Test 1: Normal collection with sufficient rewards
	t.Run("normal collection works", func(t *testing.T) {
		testing.SetRealm(testing.NewUserRealm(addr01))

		beforeGns := gns.BalanceOf(addr01)
		beforeBar := bar.BalanceOf(addr01)

		// Should not panic
		func(cur realm) {
			testing.SetRealm(stakerRealm)
			getMockInstance().CollectReward(positionId, false)
		}(cross)

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

		gnft.Approve(cross, stakerAddr, positionIdFrom(positionId2))
		func(cur realm) {
			testing.SetRealm(stakerRealm)
			getMockInstance().StakeToken(positionId2, "")
		}(cross)

		// Create external incentive with very small amount
		testing.SetRealm(adminRealm)
		bar.Approve(cross, stakerAddr, 100)

		expectedMsg := "[GNOSWAP-STAKER-007] invalid input data || rewardAmount(100) is less than minimum required amount(1000000000)"
		uassert.AbortsWithMessage(t, expectedMsg, func() {
			func(cur realm) {
				testing.SetRealm(stakerRealm)
				getMockInstance().CreateExternalIncentive(
					poolPath,
					barPath,
					100,
					incentiveStartTimestamp,
					incentiveStartTimestamp+incentiveDuration,
				)
			}(cross)
		})
	})
}
