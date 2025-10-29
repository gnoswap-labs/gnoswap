package v1

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
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
