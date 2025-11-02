package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/emission"
	pl "gno.land/r/gnoswap/pool"

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
		gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))

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

		gnft.Approve(cross, stakerAddr, positionIdFrom(positionId2))
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

func TestAssertIsValidAmount(t *testing.T) {
	tests := []struct {
		name        string
		amount      int64
		shouldPanic bool
	}{
		{"valid zero", 0, false},
		{"valid positive", 100, false},
		{"valid large positive", 9223372036854775807, false},
		{"invalid negative", -1, true},
		{"invalid large negative", -9223372036854775808, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "must be positive", func() {
					assertIsValidAmount(tt.amount)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidAmount(tt.amount)
				})
			}
		})
	}
}

func TestAssertIsValidRewardAmountFormat(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		shouldPanic bool
	}{
		{"valid format", "gno.land/r/demo/gns:1000", false},
		{"valid format with large amount", "gno.land/r/demo/gns:999999999999", false},
		{"invalid no colon", "gno.land/r/demo/gns1000", true},
		{"invalid empty", "", true},
		{"invalid only colon", ":", false}, // This actually passes the format check
		{"invalid multiple colons", "token:path:amount", false}, // SplitN with 2 allows this
		{"invalid missing amount", "gno.land/r/demo/gns:", false},
		{"invalid missing token", ":1000", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "invalid format", func() {
					assertIsValidRewardAmountFormat(tt.input)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidRewardAmountFormat(tt.input)
				})
			}
		})
	}
}

func TestAssertIsValidPoolTier(t *testing.T) {
	tests := []struct {
		name        string
		tier        uint64
		shouldPanic bool
	}{
		{"valid tier 0", 0, false},
		{"valid tier 1", 1, false},
		{"valid tier 2", 2, false},
		{"invalid tier equals AllTierCount", AllTierCount, true},
		{"invalid tier greater than AllTierCount", AllTierCount + 1, true},
		{"invalid large tier", 999999, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "must be less than", func() {
					assertIsValidPoolTier(tt.tier)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidPoolTier(tt.tier)
				})
			}
		})
	}
}

func TestAssertIsValidFeeRate(t *testing.T) {
	tests := []struct {
		name        string
		fee         int64
		shouldPanic bool
	}{
		{"valid zero fee", 0, false},
		{"valid mid fee", 500, false},
		{"valid max fee", 1000, false},
		{"invalid negative fee", -1, true},
		{"invalid large negative", -999, true},
		{"invalid over max", 1001, true},
		{"invalid large over max", 9999, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "must be in range", func() {
					assertIsValidFeeRate(tt.fee)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidFeeRate(tt.fee)
				})
			}
		})
	}
}

func TestAssertIsValidIncentiveEndTime(t *testing.T) {
	tests := []struct {
		name        string
		endTime     int64
		shouldPanic bool
	}{
		{"valid current time", time.Now().Unix(), false},
		{"valid future time", time.Now().AddDate(1, 0, 0).Unix(), false},
		{"valid far future", 253402300798, false}, // 9999-12-31 23:59:58
		{"invalid at max epoch", 253402300799, true}, // 9999-12-31 23:59:59
		{"invalid over max epoch", 253402300800, true},
		{"invalid far future", 999999999999, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "cannot be later than", func() {
					assertIsValidIncentiveEndTime(tt.endTime)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidIncentiveEndTime(tt.endTime)
				})
			}
		})
	}
}

func TestAssertIsValidIncentiveDuration(t *testing.T) {
	tests := []struct {
		name        string
		duration    int64
		shouldPanic bool
	}{
		{"valid 90 days", TIMESTAMP_90DAYS, false},
		{"valid 180 days", TIMESTAMP_180DAYS, false},
		{"valid 365 days", TIMESTAMP_365DAYS, false},
		{"invalid 0", 0, true},
		{"invalid 1 day", 86400, true},
		{"invalid 30 days", 2592000, true},
		{"invalid 91 days", 7862400, true},
		{"invalid negative", -7776000, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "must be 90, 180, 365 days", func() {
					assertIsValidIncentiveDuration(tt.duration)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidIncentiveDuration(tt.duration)
				})
			}
		})
	}
}

func TestIsMidnight(t *testing.T) {
	tests := []struct {
		name     string
		time     time.Time
		expected bool
	}{
		{"midnight UTC", time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC), true},
		{"midnight local", time.Date(2024, 1, 1, 0, 0, 0, 0, time.Local), true},
		{"not midnight - 1 second after", time.Date(2024, 1, 1, 0, 0, 1, 0, time.UTC), false},
		{"not midnight - 1 minute after", time.Date(2024, 1, 1, 0, 1, 0, 0, time.UTC), false},
		{"not midnight - 1 hour after", time.Date(2024, 1, 1, 1, 0, 0, 0, time.UTC), false},
		{"not midnight - noon", time.Date(2024, 1, 1, 12, 0, 0, 0, time.UTC), false},
		{"not midnight - almost midnight", time.Date(2024, 1, 1, 23, 59, 59, 0, time.UTC), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isMidnight(tt.time)
			uassert.Equal(t, tt.expected, result)
		})
	}
}
