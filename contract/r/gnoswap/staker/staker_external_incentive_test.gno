package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/gnoswap/consts"
)

func TestCreateExternalIncentiveWithAllowedTokens(t *testing.T) {
	poolPath := "test_pool"
	account1 := testutils.TestAddress("account1")
	account2 := testutils.TestAddress("account2")

	// create pool
	pool := NewPool(poolPath, 100)
	pools.set(poolPath, pool)

	// allowed tokens
	allowedTokens := []string{
		consts.GNS_PATH,    // GNS
		consts.WUGNOT_PATH, // GNOT (wrapped)
		"token0_path",      // pool's first token
		"token1_path",      // pool's second token
	}

	currentTime := time.Now().Unix()
	startTime := currentTime + 86400   // 1 day later
	endTime := startTime + (86400 * 7) // 7 days after start

	tests := []struct {
		name        string
		creator     std.Address
		rewardToken string
		amount      uint64
		shouldPass  bool
	}{
		{
			name:        "create incentive with GNS token",
			creator:     account1,
			rewardToken: consts.GNS_PATH,
			amount:      1000,
			shouldPass:  true,
		},
		{
			name:        "create incentive with WUGNOT token",
			creator:     account1,
			rewardToken: consts.WUGNOT_PATH,
			amount:      2000,
			shouldPass:  true,
		},
		{
			name:        "create incentive with pool's first token",
			creator:     account2,
			rewardToken: "token0_path",
			amount:      1500,
			shouldPass:  true,
		},
		{
			name:        "create incentive with pool's second token",
			creator:     account2,
			rewardToken: "token1_path",
			amount:      2500,
			shouldPass:  true,
		},
		{
			name:        "create incentive with different token by same account",
			creator:     account1,
			rewardToken: "token0_path",
			amount:      3000,
			shouldPass:  true,
		},
		{
			name:        "create incentive with same token by different account",
			creator:     account2,
			rewardToken: consts.GNS_PATH,
			amount:      3500,
			shouldPass:  true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// create incentive
			incentive := &ExternalIncentive{
				startTimestamp: startTime,
				endTimestamp:   endTime,
				startHeight:    100,
				endHeight:      200,
				rewardToken:    tc.rewardToken,
				rewardAmount:   tc.amount,
				refundee:       tc.creator,
			}

			// add incentive
			pool.incentives.create(tc.creator, incentive)

			if tc.shouldPass {
				// check if incentive was actually created
				ictv, exists := pool.incentives.Get(startTime, endTime, tc.creator, tc.rewardToken)
				if !exists {
					t.Error("incentive was not created")
				}

				if ictv.rewardAmount != tc.amount {
					t.Errorf("expected reward amount %d, got %d", tc.amount, ictv.rewardAmount)
				}
			}
		})
	}

	// clean up after test
	pools.tree.Remove(poolPath)
}

func TestCreateExternalIncentive_BelowMinimumAmount(t *testing.T) {
	// Save original minimum amount and defer restoration
	originalMinAmount := minimumRewardAmount
	defer func() {
		minimumRewardAmount = originalMinAmount
	}()

	// Set a minimum reward amount for the test
	minimumRewardAmount = 1000 * 1_000_000 // Example: 1000 tokens (assuming 6 decimals)

	// Prepare arguments for CreateExternalIncentive
	poolPath := "test_pool_min_check"
	caller := testutils.TestAddress("min_check_caller")
	// Ensure necessary setup for the function call to proceed up to the check
	// Mock pool existence
	pool := NewPool(poolPath, 100)
	pools.set(poolPath, pool)
	// Mock externalIncentives map
	externalIncentives = NewExternalIncentives()

	// Mock GNS transfer (replace with actual mocking if needed)
	_ = gns.Mint // Reference gns package to avoid unused import error

	// Mock token teller (replace with actual mocking if needed)
	testing.MockBalance(consts.GNS_PATH, caller, 10000*1_000_000) // Ensure caller has enough GNS for deposit
	testing.MockBalance(consts.GNS_PATH, stakerAddr, 0)

	// Define arguments with reward amount *below* minimum
	rewardAmountBelowMin := minimumRewardAmount - 1
	currentTime := time.Now().AddDate(0, 0, 2) // Ensure start time > tomorrow midnight
	startTime := currentTime.Truncate(24*time.Hour).Unix() + 86400
	endTime := startTime + TIMESTAMP_90DAYS // Use a valid duration

	// Set up panic catcher
	defer func() {
		r := recover()
		if r == nil {
			t.Error("CreateExternalIncentive did not panic with reward amount below minimum")
		}
		// Optionally: check the error message
		// errMsg := fmt.Sprintf("%v", r)
		// expectedMsg := "rewardAmount ... is less than minimum required amount"
		// if !strings.Contains(errMsg, expectedMsg) {
		// 	t.Errorf("Expected panic message containing '%s', got '%s'", expectedMsg, errMsg)
		// }
	}()

	// Call the function that should panic
	// Note: This assumes isAllowedForExternalReward, checkStartTime, isValidIncentiveDuration will pass
	// and doesn't fully mock Transfers, etc.
	CreateExternalIncentive(
		poolPath,
		consts.GNS_PATH, // Using GNS as an example reward token
		rewardAmountBelowMin,
		startTime,
		endTime,
	)

	// If the function did not panic, this line will be reached, and the test should fail.
	// The actual failure is asserted within the defer/recover block.
}
