package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
	pl "gno.land/r/gnoswap/v1/pool"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/onbloc/bar"
)

const (
	// External incentive timestamps
	incentiveDuration       int64 = 90 * 24 * 60 * 60 // 90 days

	rewardMinimumAmount int64 = 1000000000
)

func TestCollectRewardGracefulDegradation(t *testing.T) {
	// setup
	govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)
	testing.SetOriginCaller(govAddr)
	SetMinimumRewardAmount(cross, 1000000000)

	testing.SetOriginCaller(admin)
	SetUnStakingFeeByAdmin(cross, 0)
	
	// Create pool
	pl.SetPoolCreationFeeByAdmin(cross, 0)
	CreatePool(t, barPath, bazPath, fee3000, "79228162514264337593543950336", admin)

	// Set pool tier
	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)
	SetPoolTierByAdmin(cross, poolPath, 1)

	// Give tokens to test user
	TokenFaucet(t, barPath, addr01)
	TokenFaucet(t, bazPath, addr01)
	TokenFaucet(t, gnsPath, addr01)

	// Approve tokens
	testing.SetRealm(std.NewUserRealm(addr01))
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
	testing.SetRealm(std.NewUserRealm(addr01))
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))
	StakeToken(cross, positionId, "")

	// Create external incentive
	testing.SetRealm(adminRealm)
	gns.Approve(cross, stakerAddr, rewardMinimumAmount)
	incentiveStartTimestamp := time.Now().AddDate(0, 0, 1).Truncate(24 * time.Hour).Unix()
	CreateExternalIncentive(
		cross,
		poolPath,
		gnsPath,
		rewardMinimumAmount,
		incentiveStartTimestamp,
		incentiveStartTimestamp+incentiveDuration,
	)

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
		testing.SetRealm(std.NewUserRealm(addr01))

		beforeGns := gns.BalanceOf(addr01)
		beforeBar := bar.BalanceOf(addr01)

		// Should not panic
		CollectReward(cross, positionId, false)

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
		testing.SetRealm(std.NewUserRealm(addr02))
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
		StakeToken(cross, positionId2, "")

		// Create external incentive with very small amount
		testing.SetRealm(adminRealm)
		bar.Approve(cross, stakerAddr, 100)

		expectedMsg := "[GNOSWAP-STAKER-007] invalid input data || rewardAmount(100) is less than minimum required amount(1000000000)"
		uassert.AbortsWithMessage(t, expectedMsg, func() {
			CreateExternalIncentive(
				cross,
				poolPath,
				barPath,
				100, // Very small amount
				incentiveStartTimestamp,
				incentiveStartTimestamp+incentiveDuration,
			)
		})
	})
}
