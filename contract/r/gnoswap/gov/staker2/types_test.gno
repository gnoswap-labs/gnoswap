package staker2

import (
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// TestEpochState_Initialization tests EpochState creation
func TestEpochState_Initialization(t *testing.T) {
	t.Run("should create new epoch state", func(t *testing.T) {
		es := NewEpochState(1, 100, 199)

		uassert.Equal(t, uint64(1), es.Epoch)
		uassert.Equal(t, uint64(100), es.StartHeight)
		uassert.Equal(t, uint64(199), es.EndHeight)
		uassert.Equal(t, uint64(0), es.TotalStaked)
		uassert.False(t, es.Finalized)

		// Check initial reward values are zero
		uassert.True(t, es.GNSRewardPerStake.IsZero())
		uassert.Equal(t, 0, len(es.ProtocolFeePerStake))
	})
}

// TestEpochState_UpdateRewards tests reward updates
func TestEpochState_UpdateRewards(t *testing.T) {
	es := NewEpochState(1, 100, 199)
	es.TotalStaked = 1000000 // 1M staked

	t.Run("should update GNS rewards", func(t *testing.T) {
		reward := uint64(100000) // 100k GNS reward
		es.AddGNSReward(reward)

		// Reward per stake = 100000 / 1000000 = 0.1
		expectedPerStake := u256.MustFromDecimal(ufmt.Sprintf("%d", reward))
		expectedPerStake = expectedPerStake.Mul(expectedPerStake, Q128)
		expectedPerStake = expectedPerStake.Div(expectedPerStake, u256.MustFromDecimal(ufmt.Sprintf("%d", es.TotalStaked)))

		uassert.True(t, es.GNSRewardPerStake.Eq(expectedPerStake))
	})

	t.Run("should update protocol fee rewards", func(t *testing.T) {
		token := "USDC"
		fee := uint64(50000) // 50k USDC fee

		es.AddProtocolFee(token, fee)

		// Fee per stake = 50000 / 1000000 = 0.05
		expectedPerStake := u256.NewUint(fee)
		expectedPerStake = expectedPerStake.Mul(expectedPerStake, Q128)
		expectedPerStake = expectedPerStake.Div(expectedPerStake, u256.NewUint(es.TotalStaked))

		uassert.True(t, es.ProtocolFeePerStake[token].Eq(expectedPerStake))
	})

	t.Run("should not update rewards when no stake", func(t *testing.T) {
		emptyEs := NewEpochState(2, 200, 299)
		emptyEs.TotalStaked = 0

		// Should not panic or update
		emptyEs.AddGNSReward(100000)
		uassert.True(t, emptyEs.GNSRewardPerStake.IsZero())
	})
}

// TestRewardSnapshot tests reward snapshot functionality
func TestRewardSnapshot(t *testing.T) {
	t.Run("should create new snapshot", func(t *testing.T) {
		snapshot := NewRewardSnapshot(1)

		uassert.Equal(t, uint64(1), snapshot.Epoch)
		uassert.True(t, snapshot.AccGNSRewardPerStake.IsZero())
		uassert.Equal(t, 0, len(snapshot.AccProtocolFeePerStake))
	})

	t.Run("should copy from epoch state", func(t *testing.T) {
		es := NewEpochState(1, 100, 199)
		es.GNSRewardPerStake = u256.NewUint(1000)
		es.ProtocolFeePerStake["USDC"] = u256.NewUint(500)

		snapshot := NewRewardSnapshotFromEpoch(es)

		uassert.Equal(t, es.Epoch, snapshot.Epoch)
		uassert.True(t, snapshot.AccGNSRewardPerStake.Eq(es.GNSRewardPerStake))
		uassert.True(t, snapshot.AccProtocolFeePerStake["USDC"].Eq(es.ProtocolFeePerStake["USDC"]))
	})
}

// TestDelegationInfo tests delegation info structure
func TestDelegationInfo(t *testing.T) {
	t.Run("should create delegation info", func(t *testing.T) {
		info := DelegationInfo{
			Amount:     1000000,
			StartEpoch: 5,
		}

		uassert.Equal(t, uint64(1000000), info.Amount)
		uassert.Equal(t, uint64(5), info.StartEpoch)
	})
}

// TestLockedGNSInfo tests locked GNS structure
func TestLockedGNSInfo(t *testing.T) {
	t.Run("should create locked GNS info", func(t *testing.T) {
		currentTime := int64(1700000000)
		lockDuration := int64(7 * 24 * 60 * 60) // 7 days

		info := LockedGNSInfo{
			Amount:     5000000,
			UnlockTime: currentTime + lockDuration,
		}

		uassert.Equal(t, uint64(5000000), info.Amount)
		uassert.Equal(t, currentTime+lockDuration, info.UnlockTime)
	})

	t.Run("should check if unlocked", func(t *testing.T) {
		info := LockedGNSInfo{
			Amount:     5000000,
			UnlockTime: 1700000000,
		}

		// Test when current time is before unlock
		uassert.False(t, info.IsUnlocked(1699999999))

		// Test when current time equals unlock time
		uassert.True(t, info.IsUnlocked(1700000000))

		// Test when current time is after unlock
		uassert.True(t, info.IsUnlocked(1700000001))
	})
}
