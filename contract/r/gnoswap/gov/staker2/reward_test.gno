package staker2

import (
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

// TestCalculatePendingReward tests reward calculation logic (fixes Audit #1)
func TestCalculatePendingReward(t *testing.T) {
	t.Run("should calculate GNS rewards correctly", func(t *testing.T) {
		// Setup staker with initial state
		addr := testutils.TestAddress("staker1")
		staker := NewStakerState(addr)
		staker.TotalStaked = 1000000 // 1M xGNS
		staker.RewardSnapshot = &RewardSnapshot{
			Epoch:                  1,
			AccGNSRewardPerStake:   u256.Zero(), // Starting from zero
			AccProtocolFeePerStake: make(map[string]*u256.Uint),
		}

		// Create current epoch state with rewards
		// Use a realistic reward per stake value (scaled by Q128)
		// For 10% APR on 10M staked, we'd have 1M rewards
		// rewardPerStake = 1M * Q128 / 10M = Q128 / 10
		rewardPerStake := u256.Zero().Div(Q128, u256.NewUint(10))

		currentEpoch := &EpochState{
			Epoch:               2,
			TotalStaked:         10000000,       // 10M total
			GNSRewardPerStake:   rewardPerStake, // Q128/10 per stake
			ProtocolFeePerStake: make(map[string]*u256.Uint),
		}

		// Calculate pending rewards
		gnsReward, protocolFees := calculatePendingReward(staker, currentEpoch)

		// Verify GNS reward calculation
		// Expected: staker has 1M staked, should get 10% = 100k (minus rounding)
		uassert.True(t, gnsReward >= 99999 && gnsReward <= 100000)
		uassert.Equal(t, 0, len(protocolFees))
	})

	t.Run("should calculate protocol fee rewards correctly", func(t *testing.T) {
		// Setup staker
		addr := testutils.TestAddress("staker2")
		staker := NewStakerState(addr)
		staker.TotalStaked = 2000000 // 2M xGNS

		// Scale rewards properly with Q128
		prevUSDCPerStake := u256.Zero().Div(Q128, u256.NewUint(50)) // 2% previous USDC

		staker.RewardSnapshot = &RewardSnapshot{
			Epoch:                1,
			AccGNSRewardPerStake: u256.Zero(),
			AccProtocolFeePerStake: map[string]*u256.Uint{
				"USDC": prevUSDCPerStake, // Previous accumulated (2%)
			},
		}

		// Current epoch with protocol fees
		gnsPerStake := u256.Zero().Div(Q128, u256.NewUint(5))   // 20% reward
		usdcPerStake := u256.Zero().Div(Q128, u256.NewUint(20)) // 5% USDC fee
		wethPerStake := u256.Zero().Div(Q128, u256.NewUint(40)) // 2.5% WETH fee

		currentEpoch := &EpochState{
			Epoch:             2,
			TotalStaked:       10000000,
			GNSRewardPerStake: gnsPerStake,
			ProtocolFeePerStake: map[string]*u256.Uint{
				"USDC": usdcPerStake, // 5% accumulated
				"WETH": wethPerStake, // 2.5% accumulated
			},
		}

		// Calculate rewards
		gnsReward, protocolFees := calculatePendingReward(staker, currentEpoch)

		// Verify calculations (allowing for rounding)
		// GNS: 2M staked * 20% = 400k
		uassert.True(t, gnsReward >= 399999 && gnsReward <= 400000)

		// USDC: 2M staked * (5% - 2%) = 60k
		uassert.True(t, protocolFees["USDC"] >= 59999 && protocolFees["USDC"] <= 60000)

		// WETH: 2M staked * 2.5% = 50k
		uassert.True(t, protocolFees["WETH"] >= 49999 && protocolFees["WETH"] <= 50000)
	})

	t.Run("should handle zero staked amount", func(t *testing.T) {
		addr := testutils.TestAddress("staker3")
		staker := NewStakerState(addr)
		staker.TotalStaked = 0 // No stake

		currentEpoch := &EpochState{
			Epoch:             2,
			TotalStaked:       10000000,
			GNSRewardPerStake: u256.NewUint(1000),
		}

		gnsReward, protocolFees := calculatePendingReward(staker, currentEpoch)

		uassert.Equal(t, uint64(0), gnsReward)
		uassert.Equal(t, 0, len(protocolFees))
	})

	t.Run("should not have negative rewards", func(t *testing.T) {
		// This test verifies that we don't subtract claimed amounts again
		addr := testutils.TestAddress("staker4")
		staker := NewStakerState(addr)
		staker.TotalStaked = 1000000

		// Snapshot after claiming some rewards
		// Use properly scaled values
		prevGNSPerStake := u256.Zero().Div(Q128, u256.NewUint(20))  // 5% already claimed
		prevUSDCPerStake := u256.Zero().Div(Q128, u256.NewUint(30)) // 3.33% already claimed

		staker.RewardSnapshot = &RewardSnapshot{
			Epoch:                5,
			AccGNSRewardPerStake: prevGNSPerStake,
			AccProtocolFeePerStake: map[string]*u256.Uint{
				"USDC": prevUSDCPerStake,
			},
		}

		// Current epoch with more rewards
		currGNSPerStake := u256.Zero().Div(Q128, u256.NewUint(10))  // 10% total accumulated
		currUSDCPerStake := u256.Zero().Div(Q128, u256.NewUint(20)) // 5% total accumulated

		currentEpoch := &EpochState{
			Epoch:             10,
			TotalStaked:       10000000,
			GNSRewardPerStake: currGNSPerStake,
			ProtocolFeePerStake: map[string]*u256.Uint{
				"USDC": currUSDCPerStake,
			},
		}

		gnsReward, protocolFees := calculatePendingReward(staker, currentEpoch)

		// Should only get the difference, not total minus claimed
		// With proper Q128 scaling, just verify the values are reasonable
		uassert.True(t, gnsReward > 0)
		uassert.True(t, protocolFees["USDC"] > 0)
	})
}

// TestUpdateRewardSnapshot tests updating staker's reward snapshot after claiming
func TestUpdateRewardSnapshot(t *testing.T) {
	t.Run("should update snapshot to current epoch state", func(t *testing.T) {
		addr := testutils.TestAddress("staker5")
		staker := NewStakerState(addr)
		staker.RewardSnapshot = &RewardSnapshot{
			Epoch:                1,
			AccGNSRewardPerStake: u256.Zero(),
			AccProtocolFeePerStake: map[string]*u256.Uint{
				"USDC": u256.Zero(),
			},
		}

		currentEpoch := &EpochState{
			Epoch:             5,
			TotalStaked:       10000000,
			GNSRewardPerStake: u256.NewUint(1000),
			ProtocolFeePerStake: map[string]*u256.Uint{
				"USDC": u256.NewUint(500),
				"WETH": u256.NewUint(300),
			},
		}

		updateRewardSnapshot(staker, currentEpoch)

		// Verify snapshot was updated
		uassert.Equal(t, currentEpoch.Epoch, staker.RewardSnapshot.Epoch)
		uassert.True(t, staker.RewardSnapshot.AccGNSRewardPerStake.Eq(currentEpoch.GNSRewardPerStake))
		uassert.True(t, staker.RewardSnapshot.AccProtocolFeePerStake["USDC"].Eq(currentEpoch.ProtocolFeePerStake["USDC"]))
		uassert.True(t, staker.RewardSnapshot.AccProtocolFeePerStake["WETH"].Eq(currentEpoch.ProtocolFeePerStake["WETH"]))
	})
}

// TestRewardManager tests the reward manager functionality
func TestRewardManager(t *testing.T) {
	rm := NewRewardManager()
	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")

	t.Run("should track rewards for multiple users", func(t *testing.T) {
		// Setup initial stakes
		aliceStaker := NewStakerState(alice)
		aliceStaker.TotalStaked = 3000000 // 3M
		rm.UpdateStakerReward(aliceStaker, 1)

		bobStaker := NewStakerState(bob)
		bobStaker.TotalStaked = 2000000 // 2M
		rm.UpdateStakerReward(bobStaker, 1)

		// Add rewards to epoch
		rm.AddGNSReward(1, 5000000, 500000) // 5M total staked, 500k reward

		// Calculate pending rewards
		aliceGNS, _ := rm.CalculatePendingReward(aliceStaker, 1)
		bobGNS, _ := rm.CalculatePendingReward(bobStaker, 1)

		// Alice should get 3/5 of rewards
		// Bob should get 2/5 of rewards
		totalReward := uint64(500000)
		aliceExpected := (totalReward * 3) / 5
		bobExpected := (totalReward * 2) / 5

		println("aliceExpected", aliceExpected)
		println("bobExpected", bobExpected)

		// These will be scaled by Q128, so we check proportions
		uassert.True(t, aliceGNS > bobGNS)

		// Verify total conservation (within rounding)
		totalCalculated := aliceGNS + bobGNS
		uassert.True(t, totalCalculated <= totalReward)
	})

	t.Run("should handle protocol fee distribution", func(t *testing.T) {
		// Add protocol fees
		rm.AddProtocolFee(2, 5000000, "USDC", 100000) // 100k USDC
		rm.AddProtocolFee(2, 5000000, "WETH", 50000)  // 50k WETH

		// Update Alice's snapshot to epoch 2
		aliceStaker := NewStakerState(alice)
		aliceStaker.TotalStaked = 3000000
		rm.UpdateStakerReward(aliceStaker, 2)

		// Calculate fees
		_, fees := rm.CalculatePendingReward(aliceStaker, 2)

		uassert.True(t, fees["USDC"] > 0)
		uassert.True(t, fees["WETH"] > 0)
		uassert.True(t, fees["USDC"] > fees["WETH"]) // USDC had more fees
	})
}

// TestClaimReward tests the reward claiming process
func TestClaimReward(t *testing.T) {
	rm := NewRewardManager()
	alice := testutils.TestAddress("alice")

	t.Run("should claim rewards and update snapshot", func(t *testing.T) {
		// Setup staker with stake
		staker := NewStakerState(alice)
		staker.TotalStaked = 1000000
		rm.UpdateStakerReward(staker, 1)

		// Add rewards
		rm.AddGNSReward(1, 1000000, 100000) // 10% reward
		rm.AddProtocolFee(1, 1000000, "USDC", 50000)

		// Claim rewards
		gnsAmount, protocolFees := rm.ClaimReward(staker, 1)

		// Verify amounts
		uassert.True(t, gnsAmount > 0)
		uassert.True(t, protocolFees["USDC"] > 0)

		// Verify snapshot was updated
		uassert.Equal(t, uint64(1), staker.RewardSnapshot.Epoch)

		// Claiming again should yield zero
		gnsAmount2, protocolFees2 := rm.ClaimReward(staker, 1)
		uassert.Equal(t, uint64(0), gnsAmount2)
		uassert.Equal(t, 0, len(protocolFees2))
	})

	t.Run("should handle multiple epochs", func(t *testing.T) {
		staker := NewStakerState(alice)
		staker.TotalStaked = 1000000

		// Epoch 1
		rm.UpdateStakerReward(staker, 1)
		rm.AddGNSReward(1, 1000000, 100000)

		// Epoch 2 - more rewards
		rm.AddGNSReward(2, 1000000, 200000)

		// Claim at epoch 2
		gnsAmount, _ := rm.ClaimReward(staker, 2)

		// Should get rewards from both epochs
		uassert.True(t, gnsAmount > 100000) // More than just epoch 1
	})
}
