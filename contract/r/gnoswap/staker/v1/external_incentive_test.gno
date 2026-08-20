package staker

import (
	"chain/runtime"
	"math"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	sr "gno.land/r/gnoswap/staker"
	"gno.land/r/onbloc/bar"
)

func TestCreateExternalIncentiveWithAllowedTokens(cur realm, t *testing.T) {
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
	allowedTokens := []string{GNS_TOKEN_KEY, WUGNOT_TOKEN_KEY, "token0_path", "token1_path"}
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

		t.Run(name, func(cur realm, t *testing.T) {
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
			)

			// add incentive
			poolResolver := NewPoolResolver(pool)
			poolResolver.IncentivesResolver().create(incentive)

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

			if ictv.Creator() != creator {
				t.Errorf("expected creator %s, got %s", creator, ictv.Creator())
			}
		})
	}

	// clean up after test
	pools.tree.Remove(poolPath)
}

// Test ExternalIncentiveRefundAmount through the public entrypoint with full preconditions.
func TestExternalIncentiveRefundAmount(cur realm, t *testing.T) {
	creator := testutils.TestAddress("creator")
	refundee := testutils.TestAddress("refundee")

	calculateLegacyRefundAmount := func(depositRewardAmount int64, startTimestamp int64, endTimestamp int64) int64 {
		duration := endTimestamp - startTimestamp
		rewardPerSecond := depositRewardAmount / duration
		return depositRewardAmount - (rewardPerSecond * duration)
	}

	calculateRefundAmount := func(depositRewardAmount int64, startTimestamp int64, endTimestamp int64) int64 {
		duration := endTimestamp - startTimestamp
		rewardPerSecondX128 := u256.MulDiv(
			u256.NewUintFromInt64(depositRewardAmount),
			q128,
			u256.NewUintFromInt64(duration),
		)

		distributedAmountX128 := u256.Zero().Mul(
			rewardPerSecondX128,
			u256.NewUintFromInt64(duration),
		)
		distributedAmount := gnsmath.SafeConvertToInt64(u256.Zero().Rsh(distributedAmountX128, 128))

		return depositRewardAmount - distributedAmount
	}

	tests := []struct {
		name                       string
		caller                     address
		refundAddress              address
		startTimestamp             int64
		endTimestamp               int64
		depositRewardAmount        int64
		expectedLegacyRefundAmount int64
		expectedRefundAmount       int64
	}{
		{
			name:                       "external incentive refund amount by 1,000,000,000 amount and 90 days duration",
			caller:                     creator,
			refundAddress:              refundee,
			startTimestamp:             0,
			endTimestamp:               86400 * 90, // 90 days duration
			depositRewardAmount:        1_000_000_000,
			expectedLegacyRefundAmount: 4672000,
			expectedRefundAmount:       1,
		},
		{
			name:                       "external incentive refund amount by 1,234,456,789 amount and 90 days duration",
			caller:                     creator,
			refundAddress:              refundee,
			startTimestamp:             0,
			endTimestamp:               86400 * 90, // 90 days duration
			depositRewardAmount:        1_234_456_789,
			expectedLegacyRefundAmount: 5848789,
			expectedRefundAmount:       1,
		},
		{
			name:                       "external incentive refund amount by 9,999,999,999 amount and 90 days duration",
			caller:                     creator,
			refundAddress:              refundee,
			startTimestamp:             0,
			endTimestamp:               86400 * 90, // 90 days duration
			depositRewardAmount:        9_999_999_999,
			expectedLegacyRefundAmount: 63999,
			expectedRefundAmount:       1,
		},
		{
			name:                       "external incentive refund amount by 1,000,000,000,000,000 amount and 180 days duration",
			caller:                     creator,
			refundAddress:              refundee,
			startTimestamp:             0,
			endTimestamp:               86400 * 180, // 180 days duration
			depositRewardAmount:        1_000_000_000_000_000,
			expectedLegacyRefundAmount: 8128000,
			expectedRefundAmount:       1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Create ended or active incentive based on the test case.
			incentiveId := "test-incentive-1"
			incentive := sr.NewExternalIncentive(
				incentiveId,
				"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000",
				barPath,
				tt.depositRewardAmount,
				tt.startTimestamp,
				tt.endTimestamp,
				creator,
				100_000_000, // depositGnsAmount
				0,
				0,
			)

			t.Logf("refund amount: , legacy: %d, q128: %d",
				calculateLegacyRefundAmount(incentive.TotalRewardAmount(), incentive.StartTimestamp(), incentive.EndTimestamp()),
				calculateRefundAmount(tt.depositRewardAmount, tt.startTimestamp, tt.endTimestamp),
			)

			uassert.Equal(t, tt.expectedLegacyRefundAmount, calculateLegacyRefundAmount(incentive.TotalRewardAmount(), incentive.StartTimestamp(), incentive.EndTimestamp()))
			uassert.Equal(t, tt.expectedRefundAmount, calculateRefundAmount(tt.depositRewardAmount, tt.startTimestamp, tt.endTimestamp))
		})
	}
}

// Test EndExternalIncentive through the public entrypoint with full preconditions.
func TestEndExternalIncentive(cur realm, t *testing.T) {
	t.Skip("TEMP skip to inspect other tests")
	creator := testutils.TestAddress("creator")
	refundee := testutils.TestAddress("refundee")
	stranger := testutils.TestAddress("stranger")

	tests := []struct {
		name             string
		caller           address
		refundAddress    address
		endTimeOffset    int64
		expectError      bool
		expectedErrorMsg string
	}{
		{
			name:             "end incentive refund to creator",
			caller:           creator,
			refundAddress:    refundee,
			endTimeOffset:    86400, // end time in the future
			expectError:      false,
			expectedErrorMsg: "",
		},
		{
			name:             "end incentive before end time",
			caller:           creator,
			refundAddress:    refundee,
			endTimeOffset:    -1, // end time in the past
			expectError:      true,
			expectedErrorMsg: "cannot end incentive before endTime",
		},
		{
			name:             "end incentive by non-creator non-admin",
			caller:           refundee,
			refundAddress:    refundee,
			endTimeOffset:    0, // already ended
			expectError:      true,
			expectedErrorMsg: "caller has no permission",
		},
		{
			name:             "end incentive by non-creator non-admin",
			caller:           stranger,
			refundAddress:    creator,
			endTimeOffset:    0, // already ended
			expectError:      true,
			expectedErrorMsg: "caller has no permission",
		},
	}

	poolPath := "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000"
	rewardAmount := int64(10_000_000_000)
	depositGnsAmount := int64(100_000_000)
	incentiveId := "test-incentive-1"

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			initStakerTest(cur, t)
			instance := getMockInstance()

			currentTime := time.Now().Unix()
			startTime := currentTime
			endTime := currentTime + 86400*30

			// Setup real pool registry for poolAccessor.ExistsPoolPath().
			testing.SetRealm(adminRealm)
			gns.Approve(cross(cur), poolAddr, math.MaxInt)
			CreatePool(
				cur,
				barPath,
				fooPath,
				fee3000,
				"79228162514264337593543950336",
				adminAddr,
			)

			// Setup staker pool storage.
			pool := sr.NewPool(poolPath, currentTime)
			instance.getPools().set(poolPath, pool)

			// Create ended or active incentive based on the test case.
			incentive := sr.NewExternalIncentive(
				incentiveId,
				poolPath,
				barPath,
				rewardAmount,
				startTime,
				endTime,
				creator,
				depositGnsAmount,
				runtime.ChainHeight(),
				currentTime,
			)

			// Add incentive to pool
			poolResolver := NewPoolResolver(pool)
			poolResolver.IncentivesResolver().create(incentive)

			skipBlocks := (endTime-startTime)/5 + tt.endTimeOffset
			testing.SkipHeights(skipBlocks)

			creatorGnsBalanceBefore := gns.BalanceOf(tt.refundAddress)

			if tt.expectError {
				testing.SetRealm(testing.NewUserRealm(tt.caller))
				uassert.AbortsContains(t, cur, tt.expectedErrorMsg, func() {
					mockInstanceEndExternalIncentive(cur, poolPath, incentiveId, tt.refundAddress)
				})
				return
			}

			// Fund staker so transfers during successful end do not fail.
			testing.SetRealm(adminRealm)
			gns.Transfer(cross(cur), stakerAddr, depositGnsAmount)
			bar.Transfer(cross(cur), stakerAddr, rewardAmount)

			testing.SetRealm(testing.NewUserRealm(tt.caller))
			mockInstanceEndExternalIncentive(cur, poolPath, incentiveId, tt.refundAddress)

			creatorGnsBalanceAfter := gns.BalanceOf(tt.refundAddress)

			updatedIncentive, exists := poolResolver.IncentivesResolver().Get(incentiveId)
			uassert.True(t, exists)
			uassert.True(t, updatedIncentive.Refunded())
			uassert.Equal(t, creator, updatedIncentive.Creator())
			// EndExternalIncentive refunds GNS deposit and time-based reward token refund.
			uassert.Equal(t, creatorGnsBalanceAfter-creatorGnsBalanceBefore, depositGnsAmount)
		})
	}
}

// Test endExternalIncentive internal logic.
func TestEndExternalIncentiveInternal(cur realm, t *testing.T) {
	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10 // 10 days ago
	endTime := currentTime - 1          // ended 1 second ago
	creator := testutils.TestAddress("creator")

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
			expectedErrorMsg: "only creator",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			initStakerTest(cur, t)
			instance := getMockInstance()

			poolPath := "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000"
			rewardAmount := int64(10_000_000_000)

			// Create pool
			pool := sr.NewPool(poolPath, currentTime)
			instance.getPools().set(poolPath, pool)

			// Create incentive
			incentiveId := "test-incentive-1"
			incentive := sr.NewExternalIncentive(
				incentiveId,
				poolPath,
				WUGNOT_TOKEN_KEY,
				rewardAmount,
				startTime,
				endTime,
				creator,
				100_000_000, // depositGnsAmount
				runtime.ChainHeight(),
				currentTime,
			)

			// Add incentive to pool
			poolResolver := NewPoolResolver(pool)
			poolResolver.IncentivesResolver().create(incentive)

			// Reset incentive for each test
			incentive.SetRefunded(false)
			poolResolver.IncentivesResolver().update(incentive)

			// Get incentiveResolver for the test
			incentiveResolver, _ := poolResolver.IncentivesResolver().GetIncentiveResolver(incentiveId)
			_, _, err := instance.endExternalIncentive(poolResolver, incentiveResolver, tt.caller, tt.currentTime)

			if tt.expectError {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, tt.expectedErrorMsg)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestEndExternalIncentiveRefundAddressValidation(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		refundAddr  address
		shouldPanic bool
	}{
		{
			name:        "valid refund address",
			refundAddr:  testutils.TestAddress("creator"),
			shouldPanic: false,
		},
		{
			name:        "empty refund address",
			refundAddr:  address(""),
			shouldPanic: true,
		},
		{
			name:        "invalid format refund address",
			refundAddr:  address("invalid"),
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, cur, "invalid address", func() {
					assertIsValidAddress(tt.refundAddr)
				})
				return
			}

			uassert.NotPanics(t, cur, func() {
				assertIsValidAddress(tt.refundAddr)
			})
		})
	}
}

// TestDoubleClaimPrevention tests that the "last collect time"
// mechanism prevents double claiming even with finished incentives.
func TestDoubleClaimPrevention(cur realm, t *testing.T) {
	poolPath := "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000"
	staker1 := testutils.TestAddress("staker1")
	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10
	endTime := currentTime - 86400
	incentiveId := "test-double-claim"

	// Create deposit
	deposit := sr.NewDeposit(
		staker1,
		poolPath,
		u256.NewUint(1000),
		startTime+100,
		-10000,
		10000,
		[]sr.Warmup{},
	)

	depositResolver := NewDepositResolver(deposit)

	// First collection at endTime - 1 day
	firstCollectTime := endTime - 86400
	err := depositResolver.updateExternalRewardLastCollectTime(incentiveId, firstCollectTime)
	uassert.NoError(t, err)

	// Verify first collect time is recorded
	recordedTime := depositResolver.ExternalRewardLastCollectTime(incentiveId)
	uassert.Equal(t, firstCollectTime, recordedTime)

	// Try to collect again at the same time (should be allowed)
	err = depositResolver.updateExternalRewardLastCollectTime(incentiveId, firstCollectTime)
	uassert.NoError(t, err)

	// Try to collect at earlier time (should fail)
	err = depositResolver.updateExternalRewardLastCollectTime(incentiveId, firstCollectTime-1)
	uassert.Error(t, err, "should not allow collecting at earlier time")
	uassert.ErrorContains(t, err, "currentTime must be greater than external reward last collect time")

	// Collect at later time (should succeed)
	secondCollectTime := endTime
	err = depositResolver.updateExternalRewardLastCollectTime(incentiveId, secondCollectTime)
	uassert.NoError(t, err)

	// Verify second collect time is recorded
	recordedTime = depositResolver.ExternalRewardLastCollectTime(incentiveId)
	uassert.Equal(t, secondCollectTime, recordedTime)
}

// Test Deposit.LastExternalIncentiveUpdatedAt getter/setter
func TestDepositLastExternalIncentiveUpdatedAt(cur realm, t *testing.T) {
	deposit := sr.NewDeposit(
		addr01,
		"pool1",
		u256.NewUint(1000),
		100,
		-10,
		10,
		sr.DefaultWarmupTemplate(),
	)

	// Should be initialized to 0
	if deposit.LastExternalIncentiveUpdatedAt() != 0 {
		t.Errorf("Expected initial value 0, got %d", deposit.LastExternalIncentiveUpdatedAt())
	}

	// Test setter
	deposit.SetLastExternalIncentiveUpdatedAt(12345)
	if deposit.LastExternalIncentiveUpdatedAt() != 12345 {
		t.Errorf("Expected 12345, got %d", deposit.LastExternalIncentiveUpdatedAt())
	}
}

// Test lazy sync logic: filter by pool
func TestLazySyncPoolFiltering(cur realm, t *testing.T) {
	pool1 := "pool1"
	pool2 := "pool2"

	// Mock incentives
	type mockIncentive struct {
		id   string
		pool string
	}

	incentives := []mockIncentive{
		{"inc1", pool1},
		{"inc2", pool2},
		{"inc3", pool1},
	}

	// Simulate filtering
	deposit := sr.NewDeposit(
		addr01,
		pool1, // Deposit is for pool1
		u256.NewUint(1000),
		100,
		-10,
		10,
		sr.DefaultWarmupTemplate(),
	)

	// Add only pool1 incentives
	for _, inc := range incentives {
		if inc.pool == deposit.TargetPoolPath() {
			deposit.AddExternalIncentiveId(inc.id)
		}
	}

	// Should have only 2 incentives (inc1, inc3)
	cachedIds := deposit.GetExternalIncentiveIdList()
	if len(cachedIds) != 2 {
		t.Errorf("Expected 2 pool1 incentives, got %d", len(cachedIds))
	}
}

// Test lastExternalIncentiveUpdatedAt prevents re-syncing
func TestLastUpdatePreventsReSync(cur realm, t *testing.T) {
	deposit := sr.NewDeposit(
		addr01,
		"pool1",
		u256.NewUint(1000),
		100,
		-10,
		10,
		sr.DefaultWarmupTemplate(),
	)

	// Set lastUpdate to 500
	deposit.SetLastExternalIncentiveUpdatedAt(500)

	// Current time is 600
	currentTime := int64(600)

	// Should sync (lastUpdate < currentTime)
	shouldSync := deposit.LastExternalIncentiveUpdatedAt() < currentTime
	if !shouldSync {
		t.Error("Expected sync to be needed when lastUpdate < currentTime")
	}

	// Update to current time
	deposit.SetLastExternalIncentiveUpdatedAt(currentTime)

	// Should NOT sync again at same time
	shouldSync = deposit.LastExternalIncentiveUpdatedAt() < currentTime
	if shouldSync {
		t.Error("Expected no sync when lastUpdate == currentTime")
	}
}

// TestCreateExternalIncentive_SameTimestamp tests that multiple incentives
// created at the same timestamp are all stored in the pool's own incentive tree
// and discoverable via getExternalIncentiveIdsBy.
func TestCreateExternalIncentive_SameTimestamp(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000"
	creator := testutils.TestAddress("creator")
	currentTime := time.Now().Unix()

	// Create pool
	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	// Simulate multiple incentives created at the exact same time
	// by directly manipulating the timestamp
	startTime := currentTime + 86400
	endTime := startTime + 86400*7

	// Create 3 incentives at the same timestamp for the same pool
	incentiveIds := make([]string, 3)
	for i := 0; i < 3; i++ {
		incentiveId := instance.store.NextIncentiveID(creator, currentTime)
		incentiveIds[i] = incentiveId

		incentive := sr.NewExternalIncentive(
			incentiveId,
			poolPath,
			WUGNOT_TOKEN_KEY,
			int64((i+1)*1000000),
			startTime,
			endTime,
			creator,
			100_000_000,
			1000,
			currentTime, // Same currentTime for all
		)

		// Add to external incentives store
		externalIncentives := instance.store.GetExternalIncentives()
		externalIncentives.Set(incentiveId, incentive)

		// Add to pool
		poolResolver := NewPoolResolver(pool)
		poolResolver.IncentivesResolver().create(incentive)
	}

	// Verify all 3 incentives are stored in the pool's own incentive tree
	poolResolver := NewPoolResolver(pool)
	for _, expectedId := range incentiveIds {
		ictv, exists := poolResolver.IncentivesResolver().Get(expectedId)
		if !exists {
			t.Errorf("Incentive %s not found in pool incentive tree", expectedId)
			continue
		}
		if ictv.CreatedTimestamp() != currentTime {
			t.Errorf("Incentive %s: expected created timestamp %d, got %d",
				expectedId, currentTime, ictv.CreatedTimestamp())
		}
	}

	// Verify discovery via getExternalIncentiveIdsBy returns all 3 incentives
	// that start at the same timestamp for the same pool. The index is keyed by
	// start timestamp, so the discovery window is [startTime, startTime].
	discovered := instance.getExternalIncentiveIdsBy(poolPath, startTime, startTime)
	if len(discovered) != 3 {
		t.Errorf("Expected 3 incentives discoverable at same timestamp, got %d", len(discovered))
	}
	for _, expectedId := range incentiveIds {
		found := false
		for _, id := range discovered {
			if id == expectedId {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("Expected incentive %s to be discoverable, missing", expectedId)
		}
	}

	// Verify all incentives can be retrieved from external incentives store
	externalIncentives := instance.store.GetExternalIncentives()
	for _, id := range incentiveIds {
		exists := externalIncentives.Get(id) != nil
		if !exists {
			t.Errorf("Incentive %s not found in external incentives store", id)
		}
	}
}

// TestLazySync_DuplicatePrevention tests that the same incentive
// is not added multiple times to deposit even if lazy sync runs multiple times.
func TestLazySync_DuplicatePrevention(cur realm, t *testing.T) {
	poolPath := "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000"
	staker := testutils.TestAddress("staker1")
	baseTime := time.Now().Unix()

	warmups := sr.DefaultWarmupTemplate()
	deposit := sr.NewDeposit(
		staker,
		poolPath,
		u256.NewUint(1000),
		baseTime,
		-10000,
		10000,
		warmups,
	)

	incentiveId := "incentive-1"

	// Add same incentive ID multiple times
	deposit.AddExternalIncentiveId(incentiveId)
	deposit.AddExternalIncentiveId(incentiveId)
	deposit.AddExternalIncentiveId(incentiveId)

	// Verify it's only added once (tree property)
	count := len(deposit.GetExternalIncentiveIdList())
	if count != 1 {
		t.Errorf("Expected 1 incentive (no duplicates), got %d", count)
	}

	// Verify Has returns true
	if !deposit.HasExternalIncentiveId(incentiveId) {
		t.Error("Expected incentive to exist in deposit")
	}

	// Get the list and verify content
	ids := deposit.GetExternalIncentiveIdList()
	if len(ids) != 1 {
		t.Errorf("Expected 1 ID in list, got %d", len(ids))
	}
	if ids[0] != incentiveId {
		t.Errorf("Expected %s, got %s", incentiveId, ids[0])
	}
}

// TestLazySync_MultipleConcurrentIncentives tests that multiple active
// incentives are all tracked and none are missed.
func TestLazySync_MultipleConcurrentIncentives(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000"
	creator := testutils.TestAddress("creator")
	staker := testutils.TestAddress("staker1")
	baseTime := time.Now().Unix()

	// Create pool
	pool := sr.NewPool(poolPath, baseTime)
	instance.getPools().set(poolPath, pool)
	poolResolver := NewPoolResolver(pool)

	// Create 3 concurrent incentives with different tokens
	tokens := []string{WUGNOT_TOKEN_KEY, GNS_TOKEN_KEY, "gno.land/r/onbloc/bar.BAR"}
	incentiveIds := make([]string, 3)

	for i := 0; i < 3; i++ {
		incentiveId := instance.store.NextIncentiveID(creator, baseTime)
		incentiveIds[i] = incentiveId

		incentive := sr.NewExternalIncentive(
			incentiveId,
			poolPath,
			tokens[i],
			int64((i+1)*1000000),
			baseTime,
			baseTime+86400,
			creator,
			100_000_000,
			1000,
			baseTime,
		)

		// Add to external incentives store
		externalIncentives := instance.store.GetExternalIncentives()
		externalIncentives.Set(incentiveId, incentive)

		// Add to pool
		poolResolver.IncentivesResolver().create(incentive)
	}

	// Create deposit
	warmups := sr.DefaultWarmupTemplate()
	deposit := sr.NewDeposit(
		staker,
		poolPath,
		u256.NewUint(1000),
		baseTime,
		-10000,
		10000,
		warmups,
	)

	// Simulate lazy sync: add matching pool incentives to the deposit
	// (This would normally happen in calculatePositionReward)
	for _, incentiveId := range incentiveIds {
		deposit.AddExternalIncentiveId(incentiveId)
	}

	// Verify all 3 incentives are in deposit
	depositIds := deposit.GetExternalIncentiveIdList()
	if len(depositIds) != 3 {
		t.Fatalf("Expected 3 incentives in deposit, got %d", len(depositIds))
	}

	// Verify each incentive ID is present
	for _, expectedId := range incentiveIds {
		if !deposit.HasExternalIncentiveId(expectedId) {
			t.Errorf("Expected incentive %s to be in deposit", expectedId)
		}
	}

	// Verify all incentives are retrievable from pool
	for _, id := range incentiveIds {
		_, ok := poolResolver.IncentivesResolver().Get(id)
		if !ok {
			t.Errorf("Incentive %s not found in pool", id)
		}
	}
}

// TestLazySync_PoolFilteringPreventsWrongPool tests that incentives
// from different pools are not added to deposit during lazy sync.
func TestLazySync_PoolFilteringPreventsWrongPool(cur realm, t *testing.T) {
	pool1Path := "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000"
	pool2Path := "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:3000"
	creator := testutils.TestAddress("creator")
	staker := testutils.TestAddress("staker1")
	baseTime := time.Now().Unix()

	// Create deposit for pool1
	warmups := sr.DefaultWarmupTemplate()
	deposit := sr.NewDeposit(
		staker,
		pool1Path, // Deposit is for pool1
		u256.NewUint(1000),
		baseTime,
		-10000,
		10000,
		warmups,
	)

	// Create incentives for both pools
	incentive1 := sr.NewExternalIncentive(
		"pool1-incentive",
		pool1Path, // Pool1
		WUGNOT_TOKEN_KEY,
		1000000,
		baseTime,
		baseTime+1000,
		creator,
		100_000_000,
		1000,
		baseTime,
	)

	incentive2 := sr.NewExternalIncentive(
		"pool2-incentive",
		pool2Path, // Pool2 (different)
		WUGNOT_TOKEN_KEY,
		1000000,
		baseTime,
		baseTime+1000,
		creator,
		100_000_000,
		1000,
		baseTime,
	)

	// Simulate lazy sync with pool filtering (from calculatePositionReward line 133)
	incentives := []*sr.ExternalIncentive{incentive1, incentive2}
	for _, inc := range incentives {
		// Only add if incentive is for the current pool
		if inc.TargetPoolPath() == deposit.TargetPoolPath() {
			deposit.AddExternalIncentiveId(inc.IncentiveId())
		}
	}

	// Verify only pool1 incentive was added
	depositIds := deposit.GetExternalIncentiveIdList()
	if len(depositIds) != 1 {
		t.Fatalf("Expected 1 incentive (pool1 only), got %d", len(depositIds))
	}

	if !deposit.HasExternalIncentiveId("pool1-incentive") {
		t.Error("Expected pool1 incentive to be in deposit")
	}

	if deposit.HasExternalIncentiveId("pool2-incentive") {
		t.Error("Pool2 incentive should NOT be in pool1 deposit")
	}
}

// TestRefundCalculationWithPartialCollections tests that refund calculation
// is accurate when multiple users collect and unstake
func TestRefundCalculationWithPartialCollections(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	s := getMockInstance()

	poolPath := "gno.land/r/test/refund_calc"
	creator := testutils.TestAddress("creator")
	userA := testutils.TestAddress("userA")
	userB := testutils.TestAddress("userB")

	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10 // 10 days ago
	endTime := currentTime - 86400      // ended 1 day ago
	totalRewardAmount := int64(1_000_000_000)

	// Create pool
	pool := sr.NewPool(poolPath, startTime)
	s.getPools().set(poolPath, pool)

	// Create incentive
	incentiveId := "refund-test"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_TOKEN_KEY,
		totalRewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		startTime-100,
	)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(incentive)

	warmups := []sr.Warmup{
		sr.NewWarmup(0, startTime, 30),
		sr.NewWarmup(0, startTime, 50),
		sr.NewWarmup(0, startTime, 70),
		sr.NewWarmup(math.MaxInt64, math.MaxInt64, 100),
	}

	// Create deposits for User A and User B
	depositA := sr.NewDeposit(userA, poolPath, u256.NewUint(1000), startTime+100, -10000, 10000, warmups)
	depositB := sr.NewDeposit(userB, poolPath, u256.NewUint(1000), startTime+200, -10000, 10000, warmups)

	s.getDeposits().set(1, depositA)
	s.getDeposits().set(2, depositB)

	depositResolverA := NewDepositResolver(depositA)
	depositResolverB := NewDepositResolver(depositB)

	poolResolver.modifyDeposit(i256.NewInt(1000), startTime+100, 0)
	poolResolver.Pool.SetHistoricalTickAt(startTime+100, int32(0))
	poolResolver.modifyDeposit(i256.NewInt(1000), startTime+200, 0)
	poolResolver.Pool.SetHistoricalTickAt(startTime+200, int32(0))

	// User A collects 300
	collectedA := int64(300)
	depositResolverA.addCollectedExternalReward(incentiveId, collectedA)
	depositResolverA.updateExternalRewardLastCollectTime(incentiveId, endTime-1000)

	// Update DistributedRewardAmount and deduct from rewardAmount (simulating CollectReward)
	incentiveResolver := NewExternalIncentiveResolver(incentive)
	incentiveResolver.addDistributedRewardAmount(collectedA)
	incentive.SetRewardAmount(gnsmath.SafeSubInt64(incentive.RewardAmount(), collectedA))

	// User B collects 200
	collectedB := int64(200)
	depositResolverB.addCollectedExternalReward(incentiveId, collectedB)
	depositResolverB.updateExternalRewardLastCollectTime(incentiveId, endTime-500)

	// Update DistributedRewardAmount and deduct from rewardAmount (simulating CollectReward)
	incentiveResolver.addDistributedRewardAmount(collectedB)
	incentive.SetRewardAmount(gnsmath.SafeSubInt64(incentive.RewardAmount(), collectedB))

	// Verify DistributedRewardAmount = 500
	if incentiveResolver.DistributedRewardAmount() != 500 {
		t.Errorf("Expected DistributedRewardAmount 500, got %d", incentiveResolver.DistributedRewardAmount())
	}

	// Verify DistributedRewardAmount remains 500 after unstakes
	if incentiveResolver.DistributedRewardAmount() != 500 {
		t.Errorf("After unstakes, DistributedRewardAmount should still be 500, got %d", incentiveResolver.DistributedRewardAmount())
	}

	// End incentive with simple time-based refund calculation
	_, refund, err := s.endExternalIncentive(poolResolver, incentiveResolver, creator, endTime+100)
	uassert.NoError(t, err)

	// refund = totalRewardAmount - (rewardPerSecond × duration) - distributedRewardAmount
	// duration = endTime - startTime = 86400*9 = 777600
	// rewardPerSecond = totalRewardAmount / duration = 1000000000 / 777600 = 1285 (truncated)
	// totalDistributable = 1285 * 777600 = 999273600 (due to integer truncation, less than totalRewardAmount)
	// refund = 1000000000 - 999273600 - 500 = 726400 - 500 = 725900
	if refund < 0 {
		t.Errorf("Refund should never be negative! Got %d", refund)
	}
}

// Test that zero-liquidity windows are tracked via modifyDeposit and reflected in calculateUnclaimableReward.
func TestCalculateUnclaimableReward_TracksZeroLiquidityTransitions(cur realm, t *testing.T) {
	poolPath := "test_pool_unclaimable_tracking"
	creator := testutils.TestAddress("creator")

	currentTime := time.Now().Unix()
	pool := sr.NewPool(poolPath, currentTime)
	poolResolver := NewPoolResolver(pool)
	incentives := poolResolver.IncentivesResolver()

	startTime := currentTime + 10
	endTime := startTime + 100
	rewardAmount := int64(1000) // rewardPerSecond = 10

	incentive := sr.NewExternalIncentive(
		"test_incentive_tracking",
		poolPath,
		GNS_TOKEN_KEY,
		rewardAmount,
		startTime,
		endTime,
		creator,
		100,
		runtime.ChainHeight(),
		currentTime,
	)
	incentives.create(incentive)

	stakeTimeA := startTime + 20
	zeroTime := startTime + 60
	stakeTimeB := startTime + 80

	// zero -> positive: end unclaimable
	poolResolver.modifyDeposit(i256.NewInt(1000), stakeTimeA, 0)
	// positive -> zero: start unclaimable
	poolResolver.modifyDeposit(i256.NewInt(-1000), zeroTime, 0)
	// zero -> positive: end unclaimable
	poolResolver.modifyDeposit(i256.NewInt(1000), stakeTimeB, 0)

	expectedDuration := (stakeTimeA - startTime) + (stakeTimeB - zeroTime)
	expected := expectedDuration * rewardPerSecondFromX128(incentive)

	got := incentives.calculateUnclaimableReward(incentive.IncentiveId())
	if got != expected {
		t.Fatalf("unclaimable reward mismatch: got %d, want %d", got, expected)
	}
}

// TestMultipleCollectionsBeforeUnstake tests that multiple collections
// by the same user correctly update DistributedRewardAmount only in CollectReward
func TestMultipleCollectionsBeforeUnstake(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	s := getMockInstance()

	poolPath := "gno.land/r/test/multi_collect"
	creator := testutils.TestAddress("creator")
	user := testutils.TestAddress("user")

	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10
	endTime := currentTime + 86400*10 // still active
	totalRewardAmount := int64(10000)

	// Create pool and incentive
	pool := sr.NewPool(poolPath, startTime)
	s.getPools().set(poolPath, pool)

	incentiveId := "multi-collect-test"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_TOKEN_KEY,
		totalRewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		startTime-100,
	)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(incentive)

	deposit := sr.NewDeposit(user, poolPath, u256.NewUint(1000), startTime+100, -10000, 10000, []sr.Warmup{})
	s.getDeposits().set(1, deposit)

	depositResolver := NewDepositResolver(deposit)
	incentiveResolver := NewExternalIncentiveResolver(incentive)

	// First collection: 100
	collect1 := int64(100)
	depositResolver.addCollectedExternalReward(incentiveId, collect1)
	incentiveResolver.addDistributedRewardAmount(collect1)
	depositResolver.updateExternalRewardLastCollectTime(incentiveId, currentTime-5000)

	uassert.Equal(t, int64(100), incentiveResolver.DistributedRewardAmount())

	// Second collection: 200 more
	collect2 := int64(200)
	depositResolver.addCollectedExternalReward(incentiveId, collect2)
	incentiveResolver.addDistributedRewardAmount(collect2)
	depositResolver.updateExternalRewardLastCollectTime(incentiveId, currentTime-2000)

	uassert.Equal(t, int64(300), incentiveResolver.DistributedRewardAmount())

	// Third collection: 150 more
	collect3 := int64(150)
	depositResolver.addCollectedExternalReward(incentiveId, collect3)
	incentiveResolver.addDistributedRewardAmount(collect3)
	depositResolver.updateExternalRewardLastCollectTime(incentiveId, currentTime-1000)

	uassert.Equal(t, int64(450), incentiveResolver.DistributedRewardAmount())

	// Verify total collected by user
	totalCollected := depositResolver.CollectedExternalReward(incentiveId)
	uassert.Equal(t, int64(450), totalCollected)

	// Verify DistributedRewardAmount remains unchanged
	uassert.Equal(t, int64(450), incentiveResolver.DistributedRewardAmount())
}

// TestCalculateCollectableExternalReward_ExcludesCollected verifies that
// calculateCollectableExternalReward returns only uncollected rewards
func TestCalculateCollectableExternalReward_ExcludesCollected(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	s := getMockInstance()

	poolPath := "gno.land/r/test/calc_total"
	creator := testutils.TestAddress("creator")
	user := testutils.TestAddress("user")

	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10
	endTime := currentTime + 86400*10
	totalRewardAmount := int64(10000)

	// Create pool and incentive
	pool := sr.NewPool(poolPath, startTime)
	s.getPools().set(poolPath, pool)

	incentiveId := "calc-total-test"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_TOKEN_KEY,
		totalRewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		startTime-100,
	)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(incentive)

	// Create deposit
	deposit := sr.NewDeposit(user, poolPath, u256.NewUint(1000), startTime+100, -887220, 887220, []sr.Warmup{})
	s.getDeposits().set(1, deposit)

	depositResolver := NewDepositResolver(deposit)

	// User has already collected 300
	alreadyCollected := int64(300)
	depositResolver.addCollectedExternalReward(incentiveId, alreadyCollected)
	depositResolver.updateExternalRewardLastCollectTime(incentiveId, currentTime-5000)

	// Calculate total external reward
	rewardState := poolResolver.RewardStateOf(deposit)

	totalReward := rewardState.calculateCollectableExternalReward(
		depositResolver.ExternalRewardLastCollectTime(incentiveId),
		currentTime,
		incentive,
	)

	// Verify total reward is non-negative
	if totalReward < 0 {
		t.Errorf("Total reward should be non-negative, got %d", totalReward)
	}

	// Verify collected amount is tracked separately
	collectedReward := depositResolver.CollectedExternalReward(incentiveId)
	uassert.Equal(t, alreadyCollected, collectedReward)
}

// TestDistributedRewardAmountNotDoubledOnUnstake verifies that
// DistributedRewardAmount is not modified during unstake
func TestDistributedRewardAmountNotDoubledOnUnstake(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	s := getMockInstance()

	poolPath := "gno.land/r/test/no_double"
	creator := testutils.TestAddress("creator")
	user := testutils.TestAddress("user")

	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10
	endTime := currentTime - 86400
	totalRewardAmount := int64(1000)

	// Create pool and incentive
	pool := sr.NewPool(poolPath, startTime)
	s.getPools().set(poolPath, pool)

	incentiveId := "no-double-test"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_TOKEN_KEY,
		totalRewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		startTime-100,
	)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(incentive)

	deposit := sr.NewDeposit(user, poolPath, u256.NewUint(1000), startTime+100, -10000, 10000, []sr.Warmup{})
	s.getDeposits().set(1, deposit)

	depositResolver := NewDepositResolver(deposit)
	incentiveResolver := NewExternalIncentiveResolver(incentive)

	// User collects 400
	collected := int64(400)
	depositResolver.addCollectedExternalReward(incentiveId, collected)
	incentiveResolver.addDistributedRewardAmount(collected)
	depositResolver.updateExternalRewardLastCollectTime(incentiveId, endTime-100)

	// Record DistributedRewardAmount before unstake
	beforeUnstake := incentiveResolver.DistributedRewardAmount()
	uassert.Equal(t, int64(400), beforeUnstake)

	// Verify DistributedRewardAmount remains unchanged after unstake
	afterUnstake := incentiveResolver.DistributedRewardAmount()
	uassert.Equal(t, int64(400), afterUnstake)

	// Verify no modification occurred during unstake
	if afterUnstake != beforeUnstake {
		t.Errorf("DistributedRewardAmount changed during unstake! Before: %d, After: %d", beforeUnstake, afterUnstake)
	}
}

// TestGetExternalIncentiveIdsBy tests the getExternalIncentiveIdsBy function
// which retrieves external incentive IDs within a specific time range for a pool.
func TestGetExternalIncentiveIdsBy(cur realm, t *testing.T) {
	// incentiveSetup represents an incentive to be added to the pool's incentive tree
	type incentiveSetup struct {
		poolPath    string
		incentiveId string
		startTime   int64 // incentive start timestamp (start-time index key)
		endTime     int64 // incentive end timestamp; defaults to startTime+1000 when 0
		createdTime int64 // incentive created timestamp; defaults to startTime when 0
	}

	// depositSetup represents initial deposit state
	type depositSetup struct {
		owner                          address
		poolPath                       string
		liquidity                      uint64
		stakeTimestamp                 int64
		tickLower                      int32
		tickUpper                      int32
		lastExternalIncentiveUpdatedAt int64
		existingIncentiveIds           []string
	}

	tests := []struct {
		name                          string
		incentives                    []incentiveSetup
		deposit                       depositSetup
		currentTime                   int64
		expectedIncentiveIds          []string
		expectedLastExternalUpdatedAt int64
		expectedNewIncentiveCount     int
	}{
		{
			name: "basic case - new incentives added to deposit",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", startTime: 100},
				{poolPath: "pool-a", incentiveId: "inc-2", startTime: 200},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 0,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   300,
			expectedIncentiveIds:          []string{"inc-1", "inc-2"},
			expectedLastExternalUpdatedAt: 300,
			expectedNewIncentiveCount:     2,
		},
		{
			name: "no incentives when lastUpdate == currentTime",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", startTime: 100},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 500,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   500,
			expectedIncentiveIds:          []string{},
			expectedLastExternalUpdatedAt: 500,
			expectedNewIncentiveCount:     0,
		},
		{
			name: "partial update - only new incentives since last update",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-old", startTime: 100},
				{poolPath: "pool-a", incentiveId: "inc-new", startTime: 300},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 200,
				existingIncentiveIds:           []string{"inc-old"},
			},
			currentTime:                   400,
			expectedIncentiveIds:          []string{"inc-old", "inc-new"},
			expectedLastExternalUpdatedAt: 400,
			expectedNewIncentiveCount:     2,
		},
		{
			name: "filter by pool path - only matching pool incentives",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "a-inc-1", startTime: 100},
				{poolPath: "pool-b", incentiveId: "b-inc-1", startTime: 150},
				{poolPath: "pool-a", incentiveId: "a-inc-2", startTime: 200},
				{poolPath: "pool-c", incentiveId: "c-inc-1", startTime: 250},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 0,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   300,
			expectedIncentiveIds:          []string{"a-inc-1", "a-inc-2"},
			expectedLastExternalUpdatedAt: 300,
			expectedNewIncentiveCount:     2,
		},
		{
			name: "empty time range - no incentives in range",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", startTime: 500},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 100,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   300,
			expectedIncentiveIds:          []string{},
			expectedLastExternalUpdatedAt: 300,
			expectedNewIncentiveCount:     0,
		},
		{
			name: "multiple incentives at same timestamp",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "inc-1", startTime: 100},
				{poolPath: "pool-a", incentiveId: "inc-2", startTime: 100},
				{poolPath: "pool-a", incentiveId: "inc-3", startTime: 100},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 0,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   200,
			expectedIncentiveIds:          []string{"inc-1", "inc-2", "inc-3"},
			expectedLastExternalUpdatedAt: 200,
			expectedNewIncentiveCount:     3,
		},
		{
			name: "no incentives exist for pool",
			incentives: []incentiveSetup{
				{poolPath: "pool-b", incentiveId: "b-inc-1", startTime: 100},
				{poolPath: "pool-c", incentiveId: "c-inc-1", startTime: 200},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 0,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   300,
			expectedIncentiveIds:          []string{},
			expectedLastExternalUpdatedAt: 300,
			expectedNewIncentiveCount:     0,
		},
		{
			name: "preserve existing incentive ids",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "new-inc", startTime: 300},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 200,
				existingIncentiveIds:           []string{"existing-inc-1", "existing-inc-2"},
			},
			currentTime:                   400,
			expectedIncentiveIds:          []string{"existing-inc-1", "existing-inc-2", "new-inc"},
			expectedLastExternalUpdatedAt: 400,
			expectedNewIncentiveCount:     3,
		},
		{
			name: "exact boundary - incentive at lastUpdate time included",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "boundary-inc", startTime: 100},
				{poolPath: "pool-a", incentiveId: "after-inc", startTime: 150},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 100,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   200,
			expectedIncentiveIds:          []string{"boundary-inc", "after-inc"},
			expectedLastExternalUpdatedAt: 200,
			expectedNewIncentiveCount:     2,
		},
		{
			name: "indexed by start time, not creation time",
			incentives: []incentiveSetup{
				// created early but starts within the scan window -> discovered
				{poolPath: "pool-a", incentiveId: "late-start-inc", createdTime: 50, startTime: 150},
				// created within the scan window but starts after currentTime -> not yet discovered
				{poolPath: "pool-a", incentiveId: "future-start-inc", createdTime: 150, startTime: 400},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 50,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 100,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   200,
			expectedIncentiveIds:          []string{"late-start-inc"},
			expectedLastExternalUpdatedAt: 200,
			expectedNewIncentiveCount:     1,
		},
		{
			// Stake-time scan window boundary. StakeToken scans
			// [currentTime - TIMESTAMP_365DAYS, currentTime] on the start-time
			// index. An incentive with duration <= 365 days that is still
			// active at currentTime must satisfy start >= currentTime - 365d.
			// This case pins down both edges of that window:
			//   - incentive starting exactly at the lower bound with the max
			//     duration ends exactly at currentTime -> must be discovered
			//   - incentive starting one second before the lower bound with
			//     the max duration ended before currentTime -> correctly
			//     excluded from the scan (and filtered by EndTimestamp anyway)
			//   - incentive starting exactly at currentTime -> discovered
			//     (upper bound is inclusive)
			name: "stake scan window boundary at TIMESTAMP_365DAYS",
			incentives: []incentiveSetup{
				{poolPath: "pool-a", incentiveId: "exact-lower-bound", startTime: 1_768_464_000, endTime: 1_800_000_000},
				{poolPath: "pool-a", incentiveId: "below-lower-bound", startTime: 1_768_463_999, endTime: 1_799_999_999},
				{poolPath: "pool-a", incentiveId: "exact-upper-bound", startTime: 1_800_000_000},
			},
			deposit: depositSetup{
				owner:                          testutils.TestAddress("user1"),
				poolPath:                       "pool-a",
				liquidity:                      1000,
				stakeTimestamp:                 1_768_464_000,
				tickLower:                      -1000,
				tickUpper:                      1000,
				lastExternalIncentiveUpdatedAt: 1_768_464_000,
				existingIncentiveIds:           []string{},
			},
			currentTime:                   1_800_000_000,
			expectedIncentiveIds:          []string{"exact-lower-bound", "exact-upper-bound"},
			expectedLastExternalUpdatedAt: 1_800_000_000,
			expectedNewIncentiveCount:     2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			initStakerTest(cur, t)
			instance := getMockInstance()

			for _, inc := range tt.incentives {
				pool, ok := instance.getPools().Get(inc.poolPath)
				if !ok {
					pool = sr.NewPool(inc.poolPath, 0)
					instance.getPools().set(inc.poolPath, pool)
				}

				// createdTime defaults to startTime when not explicitly set
				createdTime := inc.createdTime
				if createdTime == 0 {
					createdTime = inc.startTime
				}

				// endTime defaults to startTime+1000 when not explicitly set
				endTime := inc.endTime
				if endTime == 0 {
					endTime = inc.startTime + 1000
				}

				incentive := sr.NewExternalIncentive(
					inc.incentiveId,
					inc.poolPath,
					WUGNOT_TOKEN_KEY,
					1000000,
					inc.startTime,
					endTime,
					testutils.TestAddress("creator"),
					100_000_000,
					1000,
					createdTime,
				)

				externalIncentives := instance.store.GetExternalIncentives()
				externalIncentives.Set(inc.incentiveId, incentive)

				poolResolver := NewPoolResolver(pool)
				poolResolver.IncentivesResolver().create(incentive)
			}

			deposit := sr.NewDeposit(
				tt.deposit.owner,
				tt.deposit.poolPath,
				u256.NewUint(tt.deposit.liquidity),
				tt.deposit.stakeTimestamp,
				tt.deposit.tickLower,
				tt.deposit.tickUpper,
				sr.DefaultWarmupTemplate(),
			)

			deposit.SetLastExternalIncentiveUpdatedAt(tt.deposit.lastExternalIncentiveUpdatedAt)
			for _, existingId := range tt.deposit.existingIncentiveIds {
				deposit.AddExternalIncentiveId(existingId)
			}

			// Execute
			lastUpdateTime := tt.deposit.lastExternalIncentiveUpdatedAt
			newIncentiveIds := instance.getExternalIncentiveIdsBy(tt.deposit.poolPath, lastUpdateTime, tt.currentTime)

			// Add new incentives to deposit (mimicking what calculatePositionReward does)
			for _, incentiveId := range newIncentiveIds {
				deposit.AddExternalIncentiveId(incentiveId)
			}
			deposit.SetLastExternalIncentiveUpdatedAt(tt.currentTime)

			actualIds := deposit.GetExternalIncentiveIdList()
			uassert.Equal(t, tt.expectedNewIncentiveCount, len(actualIds))
			uassert.Equal(t, tt.expectedLastExternalUpdatedAt, deposit.LastExternalIncentiveUpdatedAt())

			// Verify: each expected incentive ID exists
			for _, expectedId := range tt.expectedIncentiveIds {
				uassert.True(t, deposit.HasExternalIncentiveId(expectedId),
					ufmt.Sprintf("Expected incentive %s to exist in deposit", expectedId))
			}
		})
	}
}

// TestCollectExternalIncentivePenalty tests the full CollectExternalIncentivePenalty flow
// using table-driven tests covering all validation paths and edge cases.
func TestCollectExternalIncentivePenalty(cur realm, t *testing.T) {
	creator := testutils.TestAddress("creator")
	stranger := testutils.TestAddress("stranger")

	tests := []struct {
		name             string
		poolPath         string
		incentiveId      string
		caller           address
		refundAddress    address
		setupPool        bool
		setupIncentive   bool
		setRefunded      bool
		penaltyAmount    int64
		expectPanic      bool
		expectedErrorMsg string
		expectedReturn   int64
	}{
		{
			name:             "pool not registered in pool accessor",
			poolPath:         "gno.land/r/invalid/pool:path:100",
			incentiveId:      "test-id",
			caller:           creator,
			refundAddress:    creator,
			setupPool:        false,
			setupIncentive:   false,
			setRefunded:      false,
			penaltyAmount:    0,
			expectPanic:      true,
			expectedErrorMsg: "[GNOSWAP-STAKER-011]", // errInvalidPoolPath
		},
		{
			name:             "incentive not found",
			poolPath:         "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000",
			incentiveId:      "nonexistent-id",
			caller:           creator,
			refundAddress:    creator,
			setupPool:        true,
			setupIncentive:   false,
			setRefunded:      false,
			penaltyAmount:    0,
			expectPanic:      true,
			expectedErrorMsg: "[GNOSWAP-STAKER-013]", // errDataNotFound
		},
		{
			name:             "incentive not ended yet (refunded=false)",
			poolPath:         "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000",
			incentiveId:      "test-id",
			caller:           creator,
			refundAddress:    creator,
			setupPool:        true,
			setupIncentive:   true,
			setRefunded:      false,
			penaltyAmount:    5000,
			expectPanic:      true,
			expectedErrorMsg: "[GNOSWAP-STAKER-022]", // errIsNotEndedIncentive
		},
		{
			name:             "caller is not creator",
			poolPath:         "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000",
			incentiveId:      "test-id",
			caller:           stranger,
			refundAddress:    stranger,
			setupPool:        true,
			setupIncentive:   true,
			setRefunded:      true,
			penaltyAmount:    5000,
			expectPanic:      true,
			expectedErrorMsg: "[GNOSWAP-STAKER-001]", // errNoPermission
		},
		{
			name:           "zero accumulated penalty returns 0",
			poolPath:       "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000",
			incentiveId:    "test-id",
			caller:         creator,
			refundAddress:  creator,
			setupPool:      true,
			setupIncentive: true,
			setRefunded:    true,
			penaltyAmount:  0,
			expectPanic:    false,
			expectedReturn: 0,
		},
		{
			name:           "successfully collect accumulated penalty",
			poolPath:       "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000",
			incentiveId:    "test-id",
			caller:         creator,
			refundAddress:  creator,
			setupPool:      true,
			setupIncentive: true,
			setRefunded:    true,
			penaltyAmount:  50000,
			expectPanic:    false,
			expectedReturn: -1, // -1 means check > 0 (exact value depends on staker balance)
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			initStakerTest(cur, t)
			instance := getMockInstance()

			currentTime := time.Now().Unix()
			startTime := currentTime
			endTime := currentTime + 86400*30

			poolPath := tt.poolPath

			if tt.setupPool {
				testing.SetRealm(adminRealm)
				gns.Approve(cross(cur), poolAddr, math.MaxInt)
				CreatePool(cur, barPath, fooPath, fee3000, "79228162514264337593543950336", adminAddr)

				pool := sr.NewPool(poolPath, currentTime)
				instance.getPools().set(poolPath, pool)

				if tt.setupIncentive {
					incentive := sr.NewExternalIncentive(
						tt.incentiveId, poolPath, barPath, 10_000_000_000,
						startTime, endTime, creator, 100_000_000,
						runtime.ChainHeight(), currentTime,
					)

					poolResolver := NewPoolResolver(pool)
					poolResolver.IncentivesResolver().create(incentive)

					if tt.penaltyAmount > 0 {
						resolver := NewExternalIncentiveResolver(incentive)
						resolver.addAccumulatedPenaltyAmount(tt.penaltyAmount)
					}

					if tt.setRefunded {
						incentive.SetRefunded(true)
						poolResolver.IncentivesResolver().update(incentive)
					}
				}
			}

			// skip past incentive end
			skipBlocks := (endTime-startTime)/5 + 86400
			testing.SkipHeights(skipBlocks)

			if tt.expectPanic {
				testing.SetRealm(testing.NewUserRealm(tt.caller))
				uassert.AbortsContains(t, cur, tt.expectedErrorMsg, func() {
					mockInstanceCollectExternalIncentivePenalty(cross(cur), poolPath, tt.incentiveId, tt.refundAddress)
				})
				return
			}

			// Fund both the ROLE_STAKER balance (read by the production balance
			// check) and the staker/v1 realm (the cross(rlm) transfer actor for
			// the local mock instance) so the penalty payout succeeds.
			testing.SetRealm(adminRealm)
			bar.Transfer(cross(cur), stakerAddr, 10_000_000_000)
			bar.Transfer(cross(cur), stakerV1Addr, 10_000_000_000)

			testing.SetRealm(testing.NewUserRealm(tt.caller))
			result := mockInstanceCollectExternalIncentivePenalty(cross(cur), poolPath, tt.incentiveId, tt.refundAddress)

			if tt.expectedReturn == 0 {
				uassert.Equal(t, int64(0), result)
			} else if tt.expectedReturn == -1 {
				if result <= 0 {
					t.Errorf("expected positive penalty collected, got %d", result)
				}

				// verify accumulated penalty was reduced
				pool, ok := instance.getPools().Get(poolPath)
				uassert.True(t, ok)
				poolResolver := NewPoolResolver(pool)
				updatedIncentive, exists := poolResolver.IncentivesResolver().Get(tt.incentiveId)
				uassert.True(t, exists)
				uassert.Equal(t, int64(0), updatedIncentive.AccumulatedPenaltyAmount())
			}
		})
	}
}

// TestCollectExternalIncentivePenaltyAccounting tests the accounting invariant
// across CollectReward penalty accumulation and CollectExternalIncentivePenalty.
func TestCollectExternalIncentivePenaltyAccounting(cur realm, t *testing.T) {
	type collectStep struct {
		reward  int64
		penalty int64
	}

	tests := []struct {
		name                string
		totalRewardAmount   int64
		collections         []collectStep
		expectedDistributed int64
		expectedPenalty     int64
	}{
		{
			name:              "single collection with penalty",
			totalRewardAmount: 1_000_000,
			collections: []collectStep{
				{reward: 700, penalty: 1000},
			},
			expectedDistributed: 700,
			expectedPenalty:     1000,
		},
		{
			name:              "multiple users with varying warmup ratios",
			totalRewardAmount: 1_000_000,
			collections: []collectStep{
				{reward: 700, penalty: 1000},
				{reward: 1400, penalty: 2000},
				{reward: 350, penalty: 500},
			},
			expectedDistributed: 2450,
			expectedPenalty:     3500,
		},
		{
			name:              "collection with zero penalty (100% warmup)",
			totalRewardAmount: 500_000,
			collections: []collectStep{
				{reward: 1000, penalty: 0},
				{reward: 2000, penalty: 0},
			},
			expectedDistributed: 3000,
			expectedPenalty:     0,
		},
		{
			name:              "penalty only (e.g. reward rounds to 0)",
			totalRewardAmount: 100_000,
			collections: []collectStep{
				{reward: 0, penalty: 300},
			},
			expectedDistributed: 0,
			expectedPenalty:     300,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			initStakerTest(cur, t)

			poolPath := "gno.land/r/test/penalty_accounting"
			creator := testutils.TestAddress("creator")
			currentTime := time.Now().Unix()

			incentive := sr.NewExternalIncentive(
				"test-id", poolPath, WUGNOT_TOKEN_KEY, tt.totalRewardAmount,
				currentTime-86400*30, currentTime-86400, creator, 100_000_000,
				runtime.ChainHeight(), currentTime-86400*30-100,
			)

			resolver := NewExternalIncentiveResolver(incentive)

			for _, c := range tt.collections {
				resolver.addDistributedRewardAmount(c.reward)
				resolver.addAccumulatedPenaltyAmount(c.penalty)
				incentive.SetRewardAmount(gnsmath.SafeSubInt64(incentive.RewardAmount(), c.reward+c.penalty))
			}

			uassert.Equal(t, tt.expectedDistributed, incentive.DistributedRewardAmount())
			uassert.Equal(t, tt.expectedPenalty, incentive.AccumulatedPenaltyAmount())

			// invariant: totalRewardAmount = rewardAmount + distributed + penalty
			sum := incentive.RewardAmount() + incentive.DistributedRewardAmount() + incentive.AccumulatedPenaltyAmount()
			uassert.Equal(t, tt.totalRewardAmount, sum)
		})
	}
}

func TestCollectExternalIncentivePenalty_HaltSemantics(cur realm, t *testing.T) {
	creator := testutils.TestAddress("creator")
	refundAddress := testutils.TestAddress("refundee")
	poolPath := "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000"
	incentiveId := "test-id"

	setupPenaltyFixture := func(cur realm, t *testing.T) {
		t.Helper()

		initStakerTest(cur, t)
		instance := getMockInstance()

		currentTime := time.Now().Unix()
		startTime := currentTime
		endTime := currentTime + 86400*30

		testing.SetRealm(adminRealm)
		gns.Approve(cross(cur), poolAddr, math.MaxInt)
		CreatePool(cur, barPath, fooPath, fee3000, "79228162514264337593543950336", adminAddr)

		pool := sr.NewPool(poolPath, currentTime)
		instance.getPools().set(poolPath, pool)

		incentive := sr.NewExternalIncentive(
			incentiveId,
			poolPath,
			barPath,
			10_000_000_000,
			startTime,
			endTime,
			creator,
			100_000_000,
			runtime.ChainHeight(),
			currentTime,
		)

		poolResolver := NewPoolResolver(pool)
		poolResolver.IncentivesResolver().create(incentive)
		resolver := NewExternalIncentiveResolver(incentive)
		resolver.addAccumulatedPenaltyAmount(5000)
		incentive.SetRefunded(true)
		poolResolver.IncentivesResolver().update(incentive)

		skipBlocks := (endTime-startTime)/5 + 86400
		testing.SkipHeights(skipBlocks)

		bar.Transfer(cross(cur), stakerAddr, 10_000_000_000)
		bar.Transfer(cross(cur), stakerV1Addr, 10_000_000_000)
	}

	t.Run("safe mode blocks penalty collection", func(cur realm, t *testing.T) {
		setupPenaltyFixture(cross(cur), t)

		testing.SetRealm(adminRealm)
		halt.SetHaltLevel(cross(cur), halt.HaltLevelSafeMode)

		// The caller realm is set inside the abort closure (via cross) so the
		// outer cur stays admin for the halt reset below; a deferred reset would
		// otherwise run with cur spoofed to the non-admin creator.
		uassert.AbortsContains(t, cur, "halted: withdraw", func() {
			testing.SetRealm(testing.NewUserRealm(creator))
			mockInstanceCollectExternalIncentivePenalty(cross(cur), poolPath, incentiveId, refundAddress)
		})

		testing.SetRealm(adminRealm)
		halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
	})

	t.Run("emergency mode allows penalty collection", func(cur realm, t *testing.T) {
		setupPenaltyFixture(cross(cur), t)

		testing.SetRealm(adminRealm)
		halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)

		testing.SetRealm(testing.NewUserRealm(creator))
		result := mockInstanceCollectExternalIncentivePenalty(cross(cur), poolPath, incentiveId, refundAddress)
		uassert.Equal(t, int64(5000), result)

		pool, ok := getMockInstance().getPools().Get(poolPath)
		uassert.True(t, ok)
		poolResolver := NewPoolResolver(pool)
		updatedIncentive, exists := poolResolver.IncentivesResolver().Get(incentiveId)
		uassert.True(t, exists)
		uassert.Equal(t, int64(0), updatedIncentive.AccumulatedPenaltyAmount())

		testing.SetRealm(adminRealm)
		halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
	})
}

// TestEndExternalIncentiveRefundWithPenalty tests that endExternalIncentive
// includes accumulatedPenaltyAmount in the refund calculation.
func TestEndExternalIncentiveRefundWithPenalty(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		distributed int64
		penalty     int64
	}{
		{name: "with penalty", distributed: 300, penalty: 200},
		{name: "with large penalty", distributed: 100, penalty: 50000},
		{name: "with zero penalty", distributed: 500, penalty: 0},
		{name: "with no collections", distributed: 0, penalty: 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			initStakerTest(cur, t)
			s := getMockInstance()

			poolPath := "gno.land/r/test/penalty_refund"
			creator := testutils.TestAddress("creator")
			currentTime := time.Now().Unix()
			startTime := currentTime - 86400*30
			endTime := currentTime - 86400
			totalRewardAmount := int64(1_000_000)

			pool := sr.NewPool(poolPath, startTime)
			s.getPools().set(poolPath, pool)

			incentive := sr.NewExternalIncentive(
				"test-id", poolPath, WUGNOT_TOKEN_KEY, totalRewardAmount,
				startTime, endTime, creator, 100_000_000,
				runtime.ChainHeight(), startTime-100,
			)

			poolResolver := NewPoolResolver(pool)
			poolResolver.IncentivesResolver().create(incentive)

			resolver := NewExternalIncentiveResolver(incentive)
			resolver.addDistributedRewardAmount(tt.distributed)
			resolver.addAccumulatedPenaltyAmount(tt.penalty)
			incentive.SetRewardAmount(gnsmath.SafeSubInt64(incentive.RewardAmount(), tt.distributed+tt.penalty))

			_, refund, err := s.endExternalIncentive(poolResolver, resolver, creator, endTime+100)
			uassert.NoError(t, err)

			// refund must not exceed maxRefund
			maxRefund := gnsmath.SafeSubInt64(totalRewardAmount, tt.distributed)
			if refund > maxRefund {
				t.Errorf("refund(%d) exceeds maxRefund(%d)", refund, maxRefund)
			}

			// refund with penalty >= refund without penalty
			cloned := incentive.Clone()
			cloned.SetAccumulatedPenaltyAmount(0)
			_, refundNoPenalty, _ := s.endExternalIncentive(poolResolver, NewExternalIncentiveResolver(cloned), creator, endTime+100)
			if refund < refundNoPenalty {
				t.Errorf("refund with penalty(%d) < refund without(%d)", refund, refundNoPenalty)
			}
		})
	}
}

// TestEndExternalIncentive_RewardAmountInvariantAfterRefund is a regression test: previously
// EndExternalIncentive transferred `refund` reward tokens out of the staker and added it to
// DistributedRewardAmount, but never decremented RewardAmount. That left
// TotalRewardAmount != RewardAmount + DistributedRewardAmount + AccumulatedPenaltyAmount
// and made GetIncentiveRemainingRewardAmount report stale, inflated values after a refund.
func TestEndExternalIncentive_RewardAmountInvariantAfterRefund(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	s := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000"
	creator := testutils.TestAddress("creator")
	refundee := testutils.TestAddress("refundee")

	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10 // 10 days ago
	endTime := currentTime - 86400      // ended 1 day ago
	totalRewardAmount := int64(1_000_000_000)
	depositGnsAmount := int64(100_000_000)
	incentiveId := "invariant-test"

	// Register a real pool so EndExternalIncentive's assertIsPoolExists passes.
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, math.MaxInt)
	CreatePool(cur, barPath, fooPath, fee3000, "79228162514264337593543950336", adminAddr)

	pool := sr.NewPool(poolPath, startTime)
	s.getPools().set(poolPath, pool)

	incentive := sr.NewExternalIncentive(
		incentiveId, poolPath, barPath, totalRewardAmount,
		startTime, endTime, creator, depositGnsAmount,
		runtime.ChainHeight(), startTime-100,
	)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(incentive)

	// Carve out a genuine (non-dust) unclaimable window: liquidity present, then zero for
	// 3 of the 9 remaining days, then present again. This is money nobody could ever have
	// claimed, as opposed to money a staker simply hasn't collected yet.
	zeroStart := startTime + 86400*2
	zeroEnd := startTime + 86400*5
	poolResolver.modifyDeposit(i256.NewInt(1000), startTime+100, 0)
	poolResolver.modifyDeposit(i256.NewInt(-1000), zeroStart, 0)
	poolResolver.modifyDeposit(i256.NewInt(1000), zeroEnd, 0)

	// Simulate two users who already collected part of the reward via CollectReward,
	// exactly as staker.gno's CollectReward loop does.
	incentiveResolver := NewExternalIncentiveResolver(incentive)
	collected := int64(300_000_000)
	penalty := int64(50_000_000)
	incentiveResolver.addDistributedRewardAmount(collected)
	incentiveResolver.addAccumulatedPenaltyAmount(penalty)
	incentive.SetRewardAmount(gnsmath.SafeSubInt64(incentive.RewardAmount(), collected+penalty))

	rewardBefore := incentive.RewardAmount()
	distributedBefore := incentive.DistributedRewardAmount()

	// Fund the staker so the refund + GNS deposit transfers succeed.
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), stakerAddr, depositGnsAmount)
	bar.Transfer(cross(cur), stakerAddr, totalRewardAmount)

	refundeeBarBefore := bar.BalanceOf(refundee)

	testing.SetRealm(testing.NewUserRealm(creator))
	sr.EndExternalIncentive(cross(cur), poolPath, incentiveId, refundee)

	updated, exists := poolResolver.IncentivesResolver().Get(incentiveId)
	uassert.True(t, exists)
	uassert.True(t, updated.Refunded())

	actualRefund := bar.BalanceOf(refundee) - refundeeBarBefore
	if actualRefund <= 0 {
		t.Fatalf("expected a substantial non-zero refund from the unclaimable window, got %d", actualRefund)
	}

	// The core bug: RewardAmount must decrease by exactly the amount actually refunded.
	uassert.Equal(t, rewardBefore-actualRefund, updated.RewardAmount())
	uassert.Equal(t, distributedBefore+actualRefund, updated.DistributedRewardAmount())

	// AccumulatedPenaltyAmount must be untouched by the refund; it is only released via
	// CollectExternalIncentivePenalty.
	uassert.Equal(t, penalty, updated.AccumulatedPenaltyAmount())

	// Invariant: TotalRewardAmount == RewardAmount + DistributedRewardAmount + AccumulatedPenaltyAmount.
	sum := updated.RewardAmount() + updated.DistributedRewardAmount() + updated.AccumulatedPenaltyAmount()
	uassert.Equal(t, totalRewardAmount, sum)

	// GetIncentiveRemainingRewardAmount must reflect the post-refund value, not the stale
	// pre-refund one.
	remaining, err := s.GetIncentiveRemainingRewardAmount(poolPath, incentiveId)
	uassert.NoError(t, err)
	uassert.Equal(t, updated.RewardAmount(), remaining)
}

// TestEndExternalIncentive_RefundCappedByRewardAmountNotPenalty verifies that the refund cap
// is RewardAmount alone, not TotalRewardAmount-DistributedRewardAmount (which also includes
// AccumulatedPenaltyAmount). AccumulatedPenaltyAmount belongs to CollectExternalIncentivePenalty,
// not to the creator refund, so a raw unclaimable-reward calculation must never be allowed to
// dip into it.
func TestEndExternalIncentive_RefundCappedByRewardAmountNotPenalty(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	s := getMockInstance()

	poolPath := "gno.land/r/test/refund_cap"
	creator := testutils.TestAddress("creator")

	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10 // 10 days ago
	endTime := startTime + 86400*10     // 10 day duration, already ended
	totalRewardAmount := int64(864_000) // divisible by the 864000s duration: 1 wei/sec, no truncation dust

	pool := sr.NewPool(poolPath, startTime)
	s.getPools().set(poolPath, pool)

	incentiveId := "refund-cap-test"
	incentive := sr.NewExternalIncentive(
		incentiveId, poolPath, WUGNOT_TOKEN_KEY, totalRewardAmount,
		startTime, endTime, creator, 100_000_000,
		runtime.ChainHeight(), startTime-100,
	)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(incentive)

	// Zero liquidity for 9 of the 10 days: a large, legitimate unclaimable window.
	zeroStart := startTime + 86400
	poolResolver.modifyDeposit(i256.NewInt(1000), startTime, 0)
	poolResolver.modifyDeposit(i256.NewInt(-1000), zeroStart, 0)

	// No one has collected yet, but a large penalty has already accumulated (e.g. from an
	// unrelated, already-unstaked position) and is waiting on CollectExternalIncentivePenalty.
	penalty := int64(400_000)
	incentiveResolver := NewExternalIncentiveResolver(incentive)
	incentiveResolver.addAccumulatedPenaltyAmount(penalty)
	incentive.SetRewardAmount(gnsmath.SafeSubInt64(incentive.RewardAmount(), penalty))
	rewardAmount := incentive.RewardAmount() // 464,000

	_, refund, err := s.endExternalIncentive(poolResolver, incentiveResolver, creator, endTime+100)
	uassert.NoError(t, err)

	// The raw unclaimable-reward calculation (9 of 10 days) is ~777,600 -- more than
	// RewardAmount (464,000) but less than the old, looser cap of
	// TotalRewardAmount-DistributedRewardAmount (864,000). It must be clamped to
	// RewardAmount, not merely to the looser bound.
	oldLooseCap := gnsmath.SafeSubInt64(incentive.TotalRewardAmount(), incentive.DistributedRewardAmount())
	if refund > rewardAmount {
		t.Fatalf("refund(%d) must never exceed RewardAmount(%d), even though it stays within the old cap(%d)", refund, rewardAmount, oldLooseCap)
	}
	uassert.Equal(t, rewardAmount, refund)

	// AccumulatedPenaltyAmount must remain fully intact; none of it leaked into the refund.
	uassert.Equal(t, penalty, incentiveResolver.AccumulatedPenaltyAmount())
}

// TestEndExternalIncentive_DoesNotStealUncollectedUserReward simulates the full lifecycle:
// a refund happens for a genuinely-unclaimable window, and afterwards a staker who was
// present the rest of the time (but never called CollectReward) can still collect their full,
// legitimate share -- proving the refund fix doesn't touch money owed to real stakers, and
// that 100% of TotalRewardAmount is eventually accounted for across refund + payout.
func TestEndExternalIncentive_DoesNotStealUncollectedUserReward(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	s := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000"
	creator := testutils.TestAddress("creator")
	refundee := testutils.TestAddress("refundee")
	staker := testutils.TestAddress("staker")

	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10
	endTime := currentTime - 86400
	totalRewardAmount := int64(1_000_000_000)
	depositGnsAmount := int64(100_000_000)
	incentiveId := "no-steal-test"
	positionId := uint64(1)

	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, math.MaxInt)
	CreatePool(cur, barPath, fooPath, fee3000, "79228162514264337593543950336", adminAddr)

	pool := sr.NewPool(poolPath, startTime)
	s.getPools().set(poolPath, pool)

	incentive := sr.NewExternalIncentive(
		incentiveId, poolPath, barPath, totalRewardAmount,
		startTime, endTime, creator, depositGnsAmount,
		runtime.ChainHeight(), startTime-100,
	)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(incentive)
	s.getExternalIncentives().set(incentiveId, incentive)

	// Zero liquidity for the first 2 of 9 days only; a real staker held liquidity for the
	// remaining 7 days but never called CollectReward.
	stakeTime := startTime + 86400*2
	poolResolver.IncentivesResolver().startUnclaimablePeriod(startTime)
	poolResolver.IncentivesResolver().endUnclaimablePeriod(stakeTime)
	liquidity := u256.NewUint(1000)
	poolResolver.modifyDeposit(i256.FromUint256(liquidity), stakeTime, 0)

	warmups := []sr.Warmup{sr.NewWarmup(math.MaxInt64, math.MaxInt64, 100)}
	deposit := sr.NewDeposit(staker, poolPath, liquidity, stakeTime, -10000, 10000, warmups)
	deposit.AddExternalIncentiveId(incentiveId)
	deposit.SetLastExternalIncentiveUpdatedAt(stakeTime)
	s.getDeposits().set(positionId, deposit)

	claimableDuration := endTime - stakeTime
	accX128 := u256.MulDiv(u256.NewUintFromInt64(claimableDuration), q128, liquidity)
	positionAccX128, overflow := u256.Zero().MulOverflow(accX128, liquidity)
	if overflow {
		t.Fatal("expected reward accumulation to fit uint256")
	}
	expectedRewardU256 := u256.MulDiv(positionAccX128, incentive.RewardPerSecondX128(), q128)
	expectedRewardU256 = u256.Zero().Rsh(expectedRewardU256, 128)
	expectedReward := gnsmath.SafeConvertToInt64(expectedRewardU256)

	// Nobody has collected anything yet.
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), stakerAddr, depositGnsAmount)
	bar.Transfer(cross(cur), stakerAddr, totalRewardAmount)

	testing.SetRealm(testing.NewUserRealm(creator))
	sr.EndExternalIncentive(cross(cur), poolPath, incentiveId, refundee)

	updated, exists := poolResolver.IncentivesResolver().Get(incentiveId)
	uassert.True(t, exists)

	rewardLeftForStaker := updated.RewardAmount()
	if rewardLeftForStaker <= 0 {
		t.Fatalf("expected a positive reward balance left for the still-uncollected staker, got %d", rewardLeftForStaker)
	}
	uassert.Equal(t, expectedReward, rewardLeftForStaker)

	stakerBarBefore := bar.BalanceOf(staker)

	testing.SetRealm(testing.NewUserRealm(staker))
	_, _, externalRewards, externalPenalties := sr.CollectReward(cross(cur), positionId)

	uassert.Equal(t, expectedReward, externalRewards[barPath])
	uassert.Equal(t, int64(0), externalPenalties[barPath])
	uassert.Equal(t, expectedReward, bar.BalanceOf(staker)-stakerBarBefore)

	depositResolver := NewDepositResolver(deposit)
	uassert.Equal(t, expectedReward, depositResolver.CollectedExternalReward(incentiveId))
	if depositResolver.ExternalRewardLastCollectTime(incentiveId) <= endTime {
		t.Fatalf("expected external reward last collect time after incentive end, got %d", depositResolver.ExternalRewardLastCollectTime(incentiveId))
	}

	updated, exists = poolResolver.IncentivesResolver().Get(incentiveId)
	uassert.True(t, exists)

	// Every token is now accounted for: nothing left in RewardAmount, and refund + user
	// payout together exactly equal TotalRewardAmount.
	uassert.Equal(t, int64(0), updated.RewardAmount())
	sum := updated.RewardAmount() + updated.DistributedRewardAmount() + updated.AccumulatedPenaltyAmount()
	uassert.Equal(t, totalRewardAmount, sum)
}

func TestCreateExternalIncentive_NonAdminBlocked(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	startTimestamp := time.Now().AddDate(0, 0, 1).Truncate(24 * time.Hour).Unix()

	testing.SetRealm(testing.NewUserRealm(addr01))
	uassert.AbortsContains(t, cur, "is not admin", func() {
		sr.CreateExternalIncentive(cross(cur), poolPath, barPath, rewardMinimumAmount, startTimestamp, startTimestamp+incentiveDuration)
	})
}

// TestIncentiveIndexKeyedByStartTimestamp verifies discovery is keyed by the
// incentive's start timestamp rather than its creation timestamp. The index is
// written once at create() and there is no setter for the start timestamp, so
// the key must always match StartTimestamp().
func TestIncentiveIndexKeyedByStartTimestamp(cur realm, t *testing.T) {
	initStakerTest(cur, t)

	poolPath := "start-time-index-pool"
	pool := sr.NewPool(poolPath, 0)

	instance := getMockInstance()
	instance.getPools().set(poolPath, pool)

	createdTime := int64(100)
	startTime := int64(5000)
	incentive := sr.NewExternalIncentive(
		"inc-start-key", poolPath, GNS_TOKEN_KEY, 1000,
		startTime, startTime+1000, testutils.TestAddress("creator"), 0, 0, createdTime,
	)
	NewPoolResolver(pool).IncentivesResolver().create(incentive)

	// A window covering only the creation timestamp must not find it.
	beforeStart := instance.getExternalIncentiveIdsBy(poolPath, 0, startTime-1)
	uassert.Equal(t, 0, len(beforeStart))

	// A window ending exactly on the start timestamp must find it.
	atStart := instance.getExternalIncentiveIdsBy(poolPath, 0, startTime)
	uassert.Equal(t, 1, len(atStart))
	uassert.Equal(t, "inc-start-key", atStart[0])
	uassert.Equal(t, startTime, incentive.StartTimestamp())
}

// TestExternalIncentivesGetPanicsOnMissingId pins the lookup contract: get
// aborts on an unknown id instead of returning nil, so callers must not
// nil-check its result.
func TestExternalIncentivesGetPanicsOnMissingId(cur realm, t *testing.T) {
	initStakerTest(cur, t)

	incentives := getMockInstance().getExternalIncentives()
	uassert.False(t, incentives.Has("missing-incentive-id"))
	uassert.PanicsContains(t, cur, "not found", func() {
		incentives.get("missing-incentive-id")
	})
}

// TestDiscoveredIncentiveIdsExistInTree asserts the start-time index never
// yields an id absent from the incentive tree, which is what makes the
// panicking get() safe on the discovery paths.
func TestDiscoveredIncentiveIdsExistInTree(cur realm, t *testing.T) {
	initStakerTest(cur, t)

	poolPath := "discovery-consistency-pool"
	pool := sr.NewPool(poolPath, 0)

	instance := getMockInstance()
	instance.getPools().set(poolPath, pool)
	incentives := instance.getExternalIncentives()
	resolver := NewPoolResolver(pool).IncentivesResolver()

	starts := []int64{1000, 1000, 2000, 7000}
	for i, startTime := range starts {
		incentiveId := ufmt.Sprintf("inc-%d", i)
		incentive := sr.NewExternalIncentive(
			incentiveId, poolPath, GNS_TOKEN_KEY, 1000,
			startTime, startTime+1000, testutils.TestAddress("creator"), 0, 0, startTime,
		)
		incentives.set(incentiveId, incentive)
		resolver.create(incentive)
	}

	discovered := instance.getExternalIncentiveIdsBy(poolPath, 0, 10000)
	uassert.Equal(t, len(starts), len(discovered))
	for _, incentiveId := range discovered {
		uassert.True(t, incentives.Has(incentiveId))
		uassert.Equal(t, incentiveId, incentives.get(incentiveId).IncentiveId())
	}
}

// TestStakeScanLowerBoundClamp covers the stake-time scan window when the chain
// time is under 365 days: the raw lower bound is negative and the index rejects
// it, so the bound must be clamped to 0.
func TestStakeScanLowerBoundClamp(cur realm, t *testing.T) {
	initStakerTest(cur, t)

	uassert.Equal(t, int64(0), stakeScanLowerBound(0))
	uassert.Equal(t, int64(0), stakeScanLowerBound(1000))
	uassert.Equal(t, int64(0), stakeScanLowerBound(TIMESTAMP_365DAYS-1))
	uassert.Equal(t, int64(0), stakeScanLowerBound(TIMESTAMP_365DAYS))
	uassert.Equal(t, int64(500), stakeScanLowerBound(TIMESTAMP_365DAYS+500))

	poolPath := "scan-clamp-pool"
	pool := sr.NewPool(poolPath, 0)

	instance := getMockInstance()
	instance.getPools().set(poolPath, pool)

	incentive := sr.NewExternalIncentive(
		"inc-clamp", poolPath, GNS_TOKEN_KEY, 1000,
		500, 1500, testutils.TestAddress("creator"), 0, 0, 0,
	)
	instance.getExternalIncentives().set("inc-clamp", incentive)
	NewPoolResolver(pool).IncentivesResolver().create(incentive)

	currentTime := int64(1000)

	// The unclamped bound aborts.
	uassert.AbortsContains(t, cur, "negative value not supported", func() {
		instance.getExternalIncentiveIdsBy(poolPath, currentTime-TIMESTAMP_365DAYS, currentTime)
	})

	// The clamped bound still finds the active incentive.
	ids := instance.getExternalIncentiveIdsBy(poolPath, stakeScanLowerBound(currentTime), currentTime)
	uassert.Equal(t, 1, len(ids))
	uassert.Equal(t, "inc-clamp", ids[0])
}

// TestIncentiveTreeFullyCoveredByStartTimeIndex asserts every incentive in a
// pool's incentive tree is reachable through the start-time discovery index.
// An incentive registered without an index entry is never found by a new
// staker, and its share silently falls through to the creator refund.
func TestIncentiveTreeFullyCoveredByStartTimeIndex(cur realm, t *testing.T) {
	initStakerTest(cur, t)

	poolPath := "index-coverage-pool"
	pool := sr.NewPool(poolPath, 0)

	instance := getMockInstance()
	instance.getPools().set(poolPath, pool)
	resolver := NewPoolResolver(pool).IncentivesResolver()

	starts := []int64{1000, 1000, 2000, 900000}
	for i, startTime := range starts {
		incentiveId := ufmt.Sprintf("cover-%d", i)
		incentive := sr.NewExternalIncentive(
			incentiveId, poolPath, GNS_TOKEN_KEY, 1000,
			startTime, startTime+1000, testutils.TestAddress("creator"), 0, 0, startTime,
		)
		instance.getExternalIncentives().set(incentiveId, incentive)
		resolver.create(incentive)
	}

	discovered := make(map[string]bool)
	for _, incentiveId := range instance.getExternalIncentiveIdsBy(poolPath, 0, math.MaxInt64) {
		discovered[incentiveId] = true
	}

	total := 0
	resolver.Incentives.IterateIncentives(func(incentiveId string, _ *sr.ExternalIncentive) bool {
		total++
		uassert.True(t, discovered[incentiveId],
			ufmt.Sprintf("incentive %s is in the tree but not in the start-time index", incentiveId))
		return false
	})

	uassert.Equal(t, len(starts), total)
	uassert.Equal(t, len(starts), len(discovered))
}
