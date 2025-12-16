package v1

import (
	"chain/runtime"
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/onbloc/json"

	sr "gno.land/r/gnoswap/staker"
)

func newTestStakerV1(t *testing.T) *stakerV1 {
	t.Helper()

	return &stakerV1{
		store:            newMockStakerStore(),
		poolAccessor:     newMockPoolAccessor(),
		emissionAccessor: newMockEmissionAccessor(),
		nftAccessor:      newMockNFTAccessor(),
	}
}

func TestApiGetRewardTokensByPoolPath_NoPool(t *testing.T) {
	staker := newTestStakerV1(t)

	result := staker.ApiGetRewardTokensByPoolPath("non-existent")

	uassert.Equal(t, "", result)
}

func TestApiGetRewardTokensByPoolPath_WithInternalAndExternal(t *testing.T) {
	staker := newTestStakerV1(t)
	poolPath := "gno.land/r/mock/pool"
	externalToken := "gno.land/r/mock/reward"
	now := time.Now().Unix()

	pools := staker.getPools()
	pool := sr.NewPool(poolPath, now)

	incentive := sr.NewExternalIncentive(
		"1",
		poolPath,
		externalToken,
		1000,
		now-10,
		now+1000,
		"",
		0,
		runtime.ChainHeight(),
		now,
		false,
	)
	pool.Incentives().SetIncentive(incentive.IncentiveId(), incentive)

	pools.set(poolPath, pool)
	staker.updatePools(pools)

	poolTier := staker.getPoolTier()
	poolTier.membership.Set(poolPath, uint64(1))
	poolTier.counts[1] = 1
	poolTier.tierRatio = sr.TierRatio{Tier1: 100}
	staker.updatePoolTier(poolTier)

	resp := staker.ApiGetRewardTokensByPoolPath(poolPath)
	root := json.Must(json.Unmarshal([]byte(resp)))

	responseNode, err := root.GetKey("response")
	uassert.Nil(t, err)

	items := responseNode.MustArray()
	uassert.Equal(t, 1, len(items))

	tokenNode, err := items[0].GetKey("tokens")
	uassert.Nil(t, err)

	tokens := tokenNode.MustArray()
	uassert.Equal(t, 2, len(tokens))

	tokenSet := map[string]bool{}
	for _, token := range tokens {
		tokenSet[token.MustString()] = true
	}

	uassert.True(t, tokenSet[GNS_PATH])
	uassert.True(t, tokenSet[externalToken])
}

// Test ApiExternalIncentive Active field
func TestApiExternalIncentive_ActiveField(t *testing.T) {
	now := time.Now().Unix()
	creator := testutils.TestAddress("creator")

	tests := []struct {
		name           string
		startTimestamp int64
		endTimestamp   int64
		expectedActive bool
	}{
		{
			name:           "active incentive (now is within range)",
			startTimestamp: now - 100,
			endTimestamp:   now + 100,
			expectedActive: true,
		},
		{
			name:           "not yet started",
			startTimestamp: now + 100,
			endTimestamp:   now + 200,
			expectedActive: false,
		},
		{
			name:           "already ended",
			startTimestamp: now - 200,
			endTimestamp:   now - 100,
			expectedActive: false,
		},
		{
			name:           "starts exactly now",
			startTimestamp: now,
			endTimestamp:   now + 100,
			expectedActive: true,
		},
		{
			name:           "ends exactly now",
			startTimestamp: now - 100,
			endTimestamp:   now,
			expectedActive: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			incentive := sr.NewExternalIncentive(
				"test-incentive",
				"test-pool",
				GNS_PATH,
				1000,
				tt.startTimestamp,
				tt.endTimestamp,
				creator,
				100,
				runtime.ChainHeight(),
				now,
				false,
			)

			apiIncentive := newApiExternalIncentive(incentive)

			if apiIncentive.Active != tt.expectedActive {
				t.Errorf("expected Active=%v, got Active=%v", tt.expectedActive, apiIncentive.Active)
			}

			// Also verify JSON output contains correct active value
			jsonNode := apiIncentive.JSON()
			activeNode, err := jsonNode.GetKey("active")
			if err != nil {
				t.Fatalf("failed to get active key from JSON: %v", err)
			}

			jsonActive := activeNode.MustBool()
			if jsonActive != tt.expectedActive {
				t.Errorf("JSON active: expected %v, got %v", tt.expectedActive, jsonActive)
			}
		})
	}
}

// Test buildApiRewards
func TestBuildApiRewards_InternalOnly(t *testing.T) {
	staker := newTestStakerV1(t)
	now := time.Now().Unix()

	warmups := []sr.Warmup{
		{WarmupRatio: 100, NextWarmupTime: now + 86400},
	}

	deposit := sr.NewDeposit(
		testutils.TestAddress("owner"),
		"test-pool",
		u256.NewUint(1000),
		now,
		int32(-100),
		int32(100),
		warmups,
	)

	reward := Reward{
		Internal:        1000,
		InternalPenalty: 100,
		External:        map[string]int64{},
		ExternalPenalty: map[string]int64{},
	}

	rewards := staker.buildApiRewards(deposit, reward)

	uassert.Equal(t, 1, len(rewards))
	uassert.Equal(t, "INTERNAL", rewards[0].IncentiveType)
	uassert.Equal(t, int64(1000), rewards[0].RewardTokenAmount)
	uassert.Equal(t, GNS_PATH, rewards[0].RewardTokenPath)
}

func TestBuildApiRewards_ExternalOnly(t *testing.T) {
	staker := newTestStakerV1(t)
	now := time.Now().Unix()
	poolPath := "test-pool"
	externalToken := "gno.land/r/external/token"

	// Create pool with external incentive
	pool := sr.NewPool(poolPath, now)
	incentive := sr.NewExternalIncentive(
		"ext-incentive-1",
		poolPath,
		externalToken,
		10000,
		now-100,
		now+1000,
		testutils.TestAddress("refundee"),
		100,
		runtime.ChainHeight(),
		now,
		false,
	)
	pool.Incentives().SetIncentive(incentive.IncentiveId(), incentive)

	pools := staker.getPools()
	pools.set(poolPath, pool)
	staker.updatePools(pools)

	// Register external incentive
	staker.store.GetExternalIncentives().Set(incentive.IncentiveId(), incentive)

	warmups := []sr.Warmup{
		{WarmupRatio: 100, NextWarmupTime: now + 86400},
	}

	deposit := sr.NewDeposit(
		testutils.TestAddress("owner"),
		poolPath,
		u256.NewUint(1000),
		now,
		int32(-100),
		int32(100),
		warmups,
	)

	reward := Reward{
		Internal:        0,
		InternalPenalty: 0,
		External:        map[string]int64{"ext-incentive-1": 500},
		ExternalPenalty: map[string]int64{"ext-incentive-1": 50},
	}

	rewards := staker.buildApiRewards(deposit, reward)

	uassert.Equal(t, 1, len(rewards))
	uassert.Equal(t, "EXTERNAL", rewards[0].IncentiveType)
	uassert.Equal(t, "ext-incentive-1", rewards[0].IncentiveId)
	uassert.Equal(t, int64(500), rewards[0].RewardTokenAmount)
	uassert.Equal(t, externalToken, rewards[0].RewardTokenPath)
}

func TestBuildApiRewards_EmptyReward(t *testing.T) {
	staker := newTestStakerV1(t)
	now := time.Now().Unix()

	warmups := []sr.Warmup{
		{WarmupRatio: 100, NextWarmupTime: now + 86400},
	}

	deposit := sr.NewDeposit(
		testutils.TestAddress("owner"),
		"test-pool",
		u256.NewUint(1000),
		now,
		int32(-100),
		int32(100),
		warmups,
	)

	reward := Reward{
		Internal:        0,
		InternalPenalty: 0,
		External:        map[string]int64{},
		ExternalPenalty: map[string]int64{},
	}

	rewards := staker.buildApiRewards(deposit, reward)

	uassert.Equal(t, 0, len(rewards))
}

func TestBuildApiRewards_ZeroExternalRewardSkipped(t *testing.T) {
	staker := newTestStakerV1(t)
	now := time.Now().Unix()
	poolPath := "test-pool"

	// Create pool with external incentive
	pool := sr.NewPool(poolPath, now)
	incentive := sr.NewExternalIncentive(
		"ext-incentive-1",
		poolPath,
		"gno.land/r/external/token",
		10000,
		now-100,
		now+1000,
		testutils.TestAddress("refundee"),
		100,
		runtime.ChainHeight(),
		now,
		false,
	)
	pool.Incentives().SetIncentive(incentive.IncentiveId(), incentive)

	pools := staker.getPools()
	pools.set(poolPath, pool)
	staker.updatePools(pools)
	staker.store.GetExternalIncentives().Set(incentive.IncentiveId(), incentive)

	warmups := []sr.Warmup{
		{WarmupRatio: 100, NextWarmupTime: now + 86400},
	}

	deposit := sr.NewDeposit(
		testutils.TestAddress("owner"),
		poolPath,
		u256.NewUint(1000),
		now,
		int32(-100),
		int32(100),
		warmups,
	)

	// External reward is zero
	reward := Reward{
		Internal:        1000,
		InternalPenalty: 100,
		External:        map[string]int64{"ext-incentive-1": 0},
		ExternalPenalty: map[string]int64{},
	}

	rewards := staker.buildApiRewards(deposit, reward)

	// Only internal reward should be present (zero external skipped)
	uassert.Equal(t, 1, len(rewards))
	uassert.Equal(t, "INTERNAL", rewards[0].IncentiveType)
}

func TestBuildApiRewards_MixedInternalAndExternal(t *testing.T) {
	staker := newTestStakerV1(t)
	now := time.Now().Unix()
	poolPath := "test-pool"

	// Create pool with external incentive
	pool := sr.NewPool(poolPath, now)
	incentive := sr.NewExternalIncentive(
		"ext-incentive-1",
		poolPath,
		"gno.land/r/external/token",
		10000,
		now-100,
		now+1000,
		testutils.TestAddress("refundee"),
		100,
		runtime.ChainHeight(),
		now,
		false,
	)
	pool.Incentives().SetIncentive(incentive.IncentiveId(), incentive)

	pools := staker.getPools()
	pools.set(poolPath, pool)
	staker.updatePools(pools)
	staker.store.GetExternalIncentives().Set(incentive.IncentiveId(), incentive)

	warmups := []sr.Warmup{
		{WarmupRatio: 100, NextWarmupTime: now + 86400},
	}

	deposit := sr.NewDeposit(
		testutils.TestAddress("owner"),
		poolPath,
		u256.NewUint(1000),
		now,
		int32(-100),
		int32(100),
		warmups,
	)

	reward := Reward{
		Internal:        2000,
		InternalPenalty: 200,
		External:        map[string]int64{"ext-incentive-1": 500},
		ExternalPenalty: map[string]int64{"ext-incentive-1": 50},
	}

	rewards := staker.buildApiRewards(deposit, reward)

	uassert.Equal(t, 2, len(rewards))

	// Check we have both types
	hasInternal := false
	hasExternal := false
	for _, r := range rewards {
		if r.IncentiveType == "INTERNAL" {
			hasInternal = true
			uassert.Equal(t, int64(2000), r.RewardTokenAmount)
		}
		if r.IncentiveType == "EXTERNAL" {
			hasExternal = true
			uassert.Equal(t, int64(500), r.RewardTokenAmount)
		}
	}
	uassert.True(t, hasInternal)
	uassert.True(t, hasExternal)
}
