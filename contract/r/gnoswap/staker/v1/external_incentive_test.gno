package v1

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
	sr "gno.land/r/gnoswap/staker"
)

func TestCreateExternalIncentiveWithAllowedTokens(t *testing.T) {
	poolPath := "test_pool"
	account1 := testutils.TestAddress("account1")
	account2 := testutils.TestAddress("account2")

	// create pool
	pool := sr.NewPool(poolPath, 100)

	pools := getMockInstance().getPools()
	pools.set(poolPath, pool)

	currentTime := time.Now().Unix()
	startTime := currentTime + 86400   // 1 day later
	endTime := startTime + (86400 * 7) // 7 days after start

	// Define allowed tokens and test scenarios
	allowedTokens := []string{GNS_PATH, WUGNOT_PATH, "token0_path", "token1_path"}
	accounts := []address{account1, account2}
	amounts := []int64{1000, 2000, 1500, 2500, 3000, 3500}

	// Test various combinations
	tests := []struct {
		accountIdx int
		tokenIdx   int
		amountIdx  int
	}{
		{0, 0, 0}, // account1, GNS, 1000
		{0, 1, 1}, // account1, WUGNOT, 2000
		{1, 2, 2}, // account2, token0_path, 1500
		{1, 3, 3}, // account2, token1_path, 2500
		{0, 2, 4}, // account1, token0_path, 3000
		{1, 0, 5}, // account2, GNS, 3500
	}

	for i, tc := range tests {
		creator := accounts[tc.accountIdx]
		token := allowedTokens[tc.tokenIdx]
		amount := amounts[tc.amountIdx]

		incentiveId := ufmt.Sprintf("%d", i+1)
		name := ufmt.Sprintf("account_%d_token_%s_amount_%d", tc.accountIdx+1, token, amount)

		t.Run(name, func(t *testing.T) {
			// create incentive
			incentive := sr.NewExternalIncentive(
				incentiveId,
				poolPath,
				token,
				amount,
				startTime,
				endTime,
				creator,
				0,
				runtime.ChainHeight(),
				currentTime,
				true,
			)

			// add incentive
			poolResolver := NewPoolResolver(pool)
			poolResolver.IncentivesResolver().create(creator, incentive)

			// verify incentive was created
			ictv, exists := poolResolver.IncentivesResolver().Get(incentive.IncentiveId())
			if !exists {
				t.Fatal("incentive was not created")
			}

			if ictv.RewardAmount() != amount {
				t.Errorf("expected reward amount %d, got %d", amount, ictv.RewardAmount())
			}

			if ictv.RewardToken() != token {
				t.Errorf("expected reward token %s, got %s", token, ictv.RewardToken())
			}

			if ictv.Refundee() != creator {
				t.Errorf("expected refundee %s, got %s", creator, ictv.Refundee())
			}
		})
	}

	// clean up after test
	pools.tree.Remove(poolPath)
}

// Test endExternalIncentive logic
func TestEndExternalIncentive(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10 // 10 days ago
	endTime := currentTime - 1          // ended 1 second ago
	rewardAmount := int64(10_000_000_000)

	// Create pool
	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	// Create incentive
	incentiveId := "test-incentive-1"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		rewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000, // depositGnsAmount
		runtime.ChainHeight(),
		currentTime,
		false,
	)

	// Add incentive to pool
	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(creator, incentive)

	tests := []struct {
		name             string
		caller           address
		currentTime      int64
		expectError      bool
		expectedErrorMsg string
	}{
		{
			name:             "end incentive before end time",
			caller:           creator,
			currentTime:      endTime - 1,
			expectError:      true,
			expectedErrorMsg: "cannot end incentive before endTime",
		},
		{
			name:             "end incentive at exact end time by creator",
			caller:           creator,
			currentTime:      endTime,
			expectError:      false,
			expectedErrorMsg: "",
		},
		{
			name:             "end incentive by non-creator non-admin",
			caller:           testutils.TestAddress("stranger"),
			currentTime:      endTime + 1,
			expectError:      true,
			expectedErrorMsg: "only refundee",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset incentive for each test
			incentive.SetRefunded(false)
			poolResolver.IncentivesResolver().update(creator, incentive)

			_, _, err := instance.endExternalIncentive(pool, incentiveId, tt.caller, tt.currentTime)

			if tt.expectError {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, tt.expectedErrorMsg)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// Test archiveEndedExternalIncentive
func TestArchiveEndedExternalIncentive(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	currentTime := time.Now().Unix()

	// Create pool
	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	// Create incentive
	incentiveId := "test-incentive-archive"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		1_000_000_000,
		currentTime,
		currentTime+86400,
		testutils.TestAddress("creator"),
		100_000_000,
		runtime.ChainHeight(),
		currentTime,
		false,
	)

	// Add incentive to pool
	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(testutils.TestAddress("creator"), incentive)

	// Verify incentive exists before archiving
	_, exists := poolResolver.IncentivesResolver().Get(incentiveId)
	uassert.True(t, exists)

	// Archive the incentive
	err := instance.archiveEndedExternalIncentive(incentive)
	uassert.NoError(t, err)

	archived := poolResolver.IncentivesResolver().IsArchived(incentiveId)
	if err == nil {
		uassert.True(t, archived, "incentive should be archived")
	} else {
		uassert.False(t, archived, "incentive should not be archived")
	}
}
