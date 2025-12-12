package v1

import (
	"chain/runtime"
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
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
	incentivesResolver := poolResolver.IncentivesResolver()
	incentivesResolver.create(testutils.TestAddress("creator"), incentive)

	// Verify incentive exists before archiving
	_, exists := incentivesResolver.Get(incentiveId)
	uassert.True(t, exists)

	// Archive the incentive
	err := instance.archiveEndedExternalIncentive(incentivesResolver, incentive)
	uassert.NoError(t, err)

	archived := incentivesResolver.IsArchived(incentiveId)
	if err == nil {
		uassert.True(t, archived, "incentive should be archived")
	} else {
		uassert.False(t, archived, "incentive should not be archived")
	}
}

// TestEndExternalIncentive_ArchivesImmediately tests that
// EndExternalIncentive archives the incentive immediately,
// even when positions are still staked (have not unstaked yet).
func TestEndExternalIncentive_ArchivesImmediately(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	staker1 := testutils.TestAddress("staker1")
	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10 // 10 days ago
	endTime := currentTime - 1          // ended 1 second ago
	rewardAmount := int64(10_000_000_000)

	// Create pool
	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	// Create incentive
	incentiveId := "test-immediate-archive"
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
	incentivesResolver := poolResolver.IncentivesResolver()
	incentivesResolver.create(creator, incentive)

	// Create a staked position (still staked, not unstaked)
	deposit := sr.NewDeposit(
		staker1,             // owner
		poolPath,            // targetPoolPath
		u256.NewUint(1000),  // liquidity
		startTime+100,       // currentTime (stake time)
		-10000,              // tickLower
		10000,               // tickUpper
		[]sr.Warmup{},       // warmups
	)
	instance.getDeposits().set(1, deposit)

	// Verify incentive is in active tree before ending
	_, exists := incentivesResolver.Get(incentiveId)
	uassert.True(t, exists, "incentive should exist in active tree")
	uassert.False(t, incentivesResolver.IsArchived(incentiveId), "incentive should not be archived yet")

	// End the incentive (position is still staked!)
	incentiveResolver, _ := incentivesResolver.GetIncentiveResolver(incentiveId)
	_, _, err := instance.endExternalIncentive(poolResolver, incentiveResolver, creator, currentTime)
	uassert.NoError(t, err)

	// Mark as refunded and archive (simulating the EndExternalIncentive function)
	incentiveResolver.SetRefunded(true)
	incentivesResolver.update(creator, incentive)
	err = instance.archiveEndedExternalIncentive(incentivesResolver, incentive)
	uassert.NoError(t, err)

	// Verify incentive is archived immediately even though position is still staked
	uassert.True(t, incentivesResolver.IsArchived(incentiveId), "incentive must be archived immediately after EndExternalIncentive")

	// Verify incentive can still be found via Get() (searches both trees)
	archivedIncentive, exists := incentivesResolver.Get(incentiveId)
	uassert.True(t, exists, "archived incentive should still be retrievable via Get()")
	uassert.Equal(t, incentiveId, archivedIncentive.IncentiveId())
}

// TestUnstakeAfterArchived tests that unstaking works
// correctly after an incentive has been archived.
func TestUnstakeAfterArchived(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	staker1 := testutils.TestAddress("staker1")
	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10 // 10 days ago
	endTime := currentTime - 86400      // ended 1 day ago
	rewardAmount := int64(10_000_000_000)

	// Create pool
	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	// Create incentive
	incentiveId := "test-unstake-after-archive"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		rewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		currentTime,
		false,
	)

	// Add incentive to pool
	poolResolver := NewPoolResolver(pool)
	incentivesResolver := poolResolver.IncentivesResolver()
	incentivesResolver.create(creator, incentive)

	// Create a staked position
	positionId := uint64(1)
	deposit := sr.NewDeposit(
		staker1,
		poolPath,
		u256.NewUint(1000),
		startTime+100, // stake time
		-10000,
		10000,
		[]sr.Warmup{},
	)
	instance.getDeposits().set(positionId, deposit)

	// Archive the incentive (simulating EndExternalIncentive)
	incentive.SetRefunded(true)
	incentivesResolver.update(creator, incentive)
	err := instance.archiveEndedExternalIncentive(incentivesResolver, incentive)
	uassert.NoError(t, err)

	// Verify incentive is archived
	uassert.True(t, incentivesResolver.IsArchived(incentiveId), "incentive should be archived")

	// Now try to find the incentive during unstake process
	// This simulates what happens in applyUnStake
	foundIncentive, exists := incentivesResolver.Get(incentiveId)
	uassert.True(t, exists, "Get() should find archived incentive")
	uassert.NotNil(t, foundIncentive, "archived incentive should be retrievable")
	uassert.Equal(t, incentiveId, foundIncentive.IncentiveId())
	uassert.True(t, foundIncentive.Refunded(), "incentive should be marked as refunded")
}

// TestClaimRewardFromArchived tests that reward claiming works
// correctly from an archived incentive.
func TestClaimRewardFromArchived(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	staker1 := testutils.TestAddress("staker1")
	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10 // 10 days ago
	endTime := currentTime - 86400      // ended 1 day ago
	rewardAmount := int64(10_000_000_000)
	rewardPerSecond := rewardAmount / (endTime - startTime)

	// Create pool
	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	// Create incentive
	incentiveId := "test-claim-from-archive"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		rewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		currentTime,
		false,
	)

	// Add incentive to pool
	poolResolver := NewPoolResolver(pool)
	incentivesResolver := poolResolver.IncentivesResolver()
	incentivesResolver.create(creator, incentive)

	// Create a staked position
	positionId := uint64(1)
	stakeTime := startTime + 100
	deposit := sr.NewDeposit(
		staker1,
		poolPath,
		u256.NewUint(1000),
		stakeTime,
		-10000,
		10000,
		[]sr.Warmup{},
	)
	instance.getDeposits().set(positionId, deposit)

	// Archive the incentive
	incentive.SetRefunded(true)
	incentivesResolver.update(creator, incentive)
	err := instance.archiveEndedExternalIncentive(incentivesResolver, incentive)
	uassert.NoError(t, err)

	// Verify archived
	uassert.True(t, incentivesResolver.IsArchived(incentiveId))

	// Get archived incentive for reward calculation
	archivedIncentive, exists := incentivesResolver.Get(incentiveId)
	uassert.True(t, exists, "should find archived incentive")

	// Calculate reward (should work even from archived)
	depositResolver := NewDepositResolver(deposit)
	lastCollectTime := depositResolver.ExternalRewardLastCollectTime(incentiveId)
	uassert.Equal(t, stakeTime, lastCollectTime, "should use stake time for first collection")

	// Reward should be calculated up to endTimestamp (not beyond)
	claimTime := endTime // claim at end time
	duration := claimTime - lastCollectTime
	expectedReward := duration * rewardPerSecond

	// Verify reward can be calculated from archived incentive
	uassert.Equal(t, rewardPerSecond, archivedIncentive.RewardPerSecond())
	calculatedReward := duration * archivedIncentive.RewardPerSecond()
	uassert.Equal(t, expectedReward, calculatedReward, "reward calculation should work from archived incentive")
}

// TestDoubleClaimPrevention tests that the "last collect time"
// mechanism prevents double claiming even with archived incentives.
func TestDoubleClaimPrevention(t *testing.T) {
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
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

// TestMultiplePositionsStillStaked tests that multiple positions are staked,
// incentive should be archived immediately when EndExternalIncentive is called,
// regardless of staked positions.
func TestMultiplePositionsStillStaked(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	staker1 := testutils.TestAddress("staker1")
	staker2 := testutils.TestAddress("staker2")
	staker3 := testutils.TestAddress("staker3")
	currentTime := time.Now().Unix()
	startTime := currentTime - 86400*10
	endTime := currentTime - 1
	rewardAmount := int64(30_000_000_000) // 30B for 3 stakers

	// Create pool
	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	// Create incentive
	incentiveId := "test-multiple-stakers"
	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		rewardAmount,
		startTime,
		endTime,
		creator,
		100_000_000,
		runtime.ChainHeight(),
		currentTime,
		false,
	)

	// Add incentive to pool
	poolResolver := NewPoolResolver(pool)
	incentivesResolver := poolResolver.IncentivesResolver()
	incentivesResolver.create(creator, incentive)

	// Create 3 staked positions
	for i, staker := range []address{staker1, staker2, staker3} {
		positionId := uint64(i + 1)
		deposit := sr.NewDeposit(
			staker,
			poolPath,
			u256.NewUint(1000),
			startTime+100,
			-10000,
			10000,
			[]sr.Warmup{},
		)
		instance.getDeposits().set(positionId, deposit)
	}

	// Verify all 3 positions are staked
	uassert.Equal(t, 3, instance.getDeposits().Size(), "should have 3 staked positions")

	// Verify incentive is NOT archived yet
	uassert.False(t, incentivesResolver.IsArchived(incentiveId), "incentive should not be archived before ending")

	// End the incentive (all 3 positions still staked!)
	incentiveResolver, _ := incentivesResolver.GetIncentiveResolver(incentiveId)
	_, _, err := instance.endExternalIncentive(poolResolver, incentiveResolver, creator, currentTime)
	uassert.NoError(t, err)

	// Mark as refunded and archive
	incentiveResolver.SetRefunded(true)
	incentivesResolver.update(creator, incentive)
	err = instance.archiveEndedExternalIncentive(incentivesResolver, incentive)
	uassert.NoError(t, err)

	// Incentive must be archived immediately, regardless of staked positions
	uassert.True(t, incentivesResolver.IsArchived(incentiveId), "incentive must be archived immediately, regardless of staked positions")

	// Verify all 3 positions can still find the incentive
	for i := uint64(1); i <= 3; i++ {
		foundIncentive, exists := incentivesResolver.Get(incentiveId)
		uassert.True(t, exists, "position should still find archived incentive")
		uassert.NotNil(t, foundIncentive)
	}

	// Simulate one position unstaking (should not try to archive again)
	// This tests the idempotency of archiveIncentive
	// Get the archived incentive (simulating applyUnStake)
	externalIncentive, exists := incentivesResolver.Get(incentiveId)
	uassert.True(t, exists)

	externalIncentiveResolver := NewExternalIncentiveResolver(externalIncentive)

	// Simulate collecting reward
	collectedReward := int64(1000)
	externalIncentiveResolver.addDistributedRewardAmount(collectedReward)

	// Try to archive again (should be idempotent - no error)
	err = instance.archiveEndedExternalIncentive(incentivesResolver, externalIncentive)
	uassert.NoError(t, err, "archiving again should be idempotent")

	// Still archived
	uassert.True(t, incentivesResolver.IsArchived(incentiveId))
}

// TestArchivedNotInGetAllInTimestamps tests that archived incentives
// are NOT included in GetAllInTimestamps, which improves gas efficiency.
func TestArchivedNotInGetAllInTimestamps(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	creator := testutils.TestAddress("creator")
	currentTime := time.Now().Unix()

	// Create pool
	pool := sr.NewPool(poolPath, currentTime)
	instance.getPools().set(poolPath, pool)

	poolResolver := NewPoolResolver(pool)
	incentivesResolver := poolResolver.IncentivesResolver()

	// Create 3 incentives: active, ended (not archived), ended (archived)
	incentives := []struct {
		id          string
		startTime   int64
		endTime     int64
		shouldEnd   bool
		description string
	}{
		{
			id:          "active-incentive",
			startTime:   currentTime,
			endTime:     currentTime + 86400,
			shouldEnd:   false,
			description: "Currently active incentive",
		},
		{
			id:          "ended-not-archived",
			startTime:   currentTime - 86400*10,
			endTime:     currentTime - 1,
			shouldEnd:   false, // Don't end it, keep in active tree
			description: "Ended but not archived",
		},
		{
			id:          "ended-and-archived",
			startTime:   currentTime - 86400*10,
			endTime:     currentTime - 1,
			shouldEnd:   true, // End and archive it
			description: "Ended and archived",
		},
	}

	for _, tc := range incentives {
		incentive := sr.NewExternalIncentive(
			tc.id,
			poolPath,
			WUGNOT_PATH,
			10_000_000_000,
			tc.startTime,
			tc.endTime,
			creator,
			100_000_000,
			runtime.ChainHeight(),
			currentTime,
			false,
		)
		incentivesResolver.create(creator, incentive)

		if tc.shouldEnd {
			incentive.SetRefunded(true)
			incentivesResolver.update(creator, incentive)
			err := instance.archiveEndedExternalIncentive(incentivesResolver, incentive)
			uassert.NoError(t, err)
		}
	}

	// GetAllInTimestamps should return incentives from both active and archived trees
	allIncentives := incentivesResolver.GetAllInTimestamps(currentTime-86400*20, currentTime+86400*2)

	// Should have 3 incentives (active + ended-not-archived + ended-and-archived)
	// After fix, archived incentives are included to prevent user reward loss
	uassert.Equal(t, 3, len(allIncentives), "should return incentives from both active and archived trees")

	// Verify all three are included
	_, hasActive := allIncentives["active-incentive"]
	uassert.True(t, hasActive, "should include active incentive")

	_, hasEndedNotArchived := allIncentives["ended-not-archived"]
	uassert.True(t, hasEndedNotArchived, "should include ended-not-archived")

	_, hasEndedArchived := allIncentives["ended-and-archived"]
	uassert.True(t, hasEndedArchived, "should include archived incentive (to allow users to claim rewards)")
}
