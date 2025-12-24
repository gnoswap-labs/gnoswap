package staker

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

func TestStoreInitialization(t *testing.T) {
	resetTestState(t)

	uassert.NotEqual(t, nil, kvStore, "kvStore should be initialized")
	domainAddr := kvStore.GetDomainAddress()
	uassert.NotEqual(t, address(""), domainAddr, "domain address should not be empty")
}

func TestStore_AuthorizedCallers(t *testing.T) {
	tests := []struct {
		name                          string
		callerRealm                   runtime.Realm
		expectedErrorWithRead         bool
		expectedErrorWithWrite        bool
		expectedErrorMessageWithRead  string
		expectedErrorMessageWithWrite string
	}{
		{
			name:        "domain address",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/staker"),
		},
		{
			name:                          "domain implementation has no permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/staker/v2"),
			expectedErrorWithRead:         true,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "read permission denied",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                   "pool has read and write permission",
			callerRealm:            testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedErrorWithRead:  false,
			expectedErrorWithWrite: false,
		},
		{
			name:                          "position has read permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/position"),
			expectedErrorWithRead:         false,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                          "router has read permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/router"),
			expectedErrorWithRead:         false,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                          "emission has read permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/emission"),
			expectedErrorWithRead:         false,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                          "panic with no permission realm",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"),
			expectedErrorWithRead:         true,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "read permission denied",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                   "user has permission",
			callerRealm:            testing.NewUserRealm(testutils.TestAddress("bob")),
			expectedErrorWithRead:  false,
			expectedErrorWithWrite: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			resetTestState(t)

			ss := NewStakerStore(kvStore)
			initRegisterReadableContract()

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker"))
			if !ss.HasAllowedTokensStoreKey() {
				ss.SetAllowedTokens([]string{})
			}

			testing.SetRealm(tc.callerRealm)
			if tc.expectedErrorWithRead {
				uassert.PanicsContains(t, tc.expectedErrorMessageWithRead, func() {
					ss.GetAllowedTokens()
				})
			} else {
				ss.GetAllowedTokens()
			}

			err := ss.SetAllowedTokens([]string{"gno.land/r/demo/token1"})
			if tc.expectedErrorWithWrite {
				uassert.ErrorContains(t, err, tc.expectedErrorMessageWithWrite)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestStoreSetAndGetDepositGnsAmount(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasDepositGnsAmountStoreKey(), "should not have deposit gns amount initially")

		err := ss.SetDepositGnsAmount(1000000)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasDepositGnsAmountStoreKey(), "should have deposit gns amount after setting")

		retrieved := ss.GetDepositGnsAmount()
		uassert.Equal(t, int64(1000000), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized deposit gns amount")
		}()

		ss.GetDepositGnsAmount()
	})
}

func TestStoreSetAndGetMinimumRewardAmount(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasMinimumRewardAmountStoreKey(), "should not have minimum reward amount initially")

		err := ss.SetMinimumRewardAmount(100)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasMinimumRewardAmountStoreKey(), "should have minimum reward amount after setting")

		retrieved := ss.GetMinimumRewardAmount()
		uassert.Equal(t, int64(100), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized minimum reward amount")
		}()

		ss.GetMinimumRewardAmount()
	})
}

func TestStoreSetAndGetDeposits(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasDepositsStoreKey(), "should not have deposits initially")

		deposits := avl.NewTree()
		err := ss.SetDeposits(deposits)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasDepositsStoreKey(), "should have deposits after setting")

		retrieved := ss.GetDeposits()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized deposits")
		}()

		ss.GetDeposits()
	})
}

func TestStoreSetAndGetExternalIncentives(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasExternalIncentivesStoreKey(), "should not have external incentives initially")

		incentives := avl.NewTree()
		err := ss.SetExternalIncentives(incentives)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasExternalIncentivesStoreKey(), "should have external incentives after setting")

		retrieved := ss.GetExternalIncentives()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized external incentives")
		}()

		ss.GetExternalIncentives()
	})
}

func TestStoreSetAndGetStakers(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasStakersStoreKey(), "should not have stakers initially")

		stakers := avl.NewTree()
		err := ss.SetStakers(stakers)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasStakersStoreKey(), "should have stakers after setting")

		retrieved := ss.GetStakers()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized stakers")
		}()

		ss.GetStakers()
	})
}

func TestStoreSetAndGetTotalEmissionSent(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasTotalEmissionSentStoreKey(), "should not have total emission sent initially")

		err := ss.SetTotalEmissionSent(50000)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasTotalEmissionSentStoreKey(), "should have total emission sent after setting")

		retrieved := ss.GetTotalEmissionSent()
		uassert.Equal(t, int64(50000), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized total emission sent")
		}()

		ss.GetTotalEmissionSent()
	})
}

func TestStoreSetAndGetAllowedTokens(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasAllowedTokensStoreKey(), "should not have allowed tokens initially")

		tokens := []string{"gno.land/r/demo/token1", "gno.land/r/demo/token2"}
		err := ss.SetAllowedTokens(tokens)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasAllowedTokensStoreKey(), "should have allowed tokens after setting")

		retrieved := ss.GetAllowedTokens()
		uassert.NotEqual(t, nil, retrieved)
		uassert.Equal(t, 2, len(retrieved))
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized allowed tokens")
		}()

		ss.GetAllowedTokens()
	})
}

func TestStoreSetAndGetIncentiveCounter(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasIncentiveCounterStoreKey(), "should not have incentive counter initially")

		counter := &Counter{}
		err := ss.SetIncentiveCounter(counter)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasIncentiveCounterStoreKey(), "should have incentive counter after setting")

		retrieved := ss.GetIncentiveCounter()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized incentive counter")
		}()

		ss.GetIncentiveCounter()
	})
}

func TestStoreSetAndGetUnstakingFee(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasUnstakingFeeStoreKey(), "should not have unstaking fee initially")

		err := ss.SetUnstakingFee(25)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasUnstakingFeeStoreKey(), "should have unstaking fee after setting")

		retrieved := ss.GetUnstakingFee()
		uassert.Equal(t, int64(25), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized unstaking fee")
		}()

		ss.GetUnstakingFee()
	})
}

func TestStoreSetAndGetPools(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasPoolsStoreKey(), "should not have pools initially")

		pools := avl.NewTree()
		err := ss.SetPools(pools)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasPoolsStoreKey(), "should have pools after setting")

		retrieved := ss.GetPools()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized pools")
		}()

		ss.GetPools()
	})
}

func TestStoreSetAndGetTokenSpecificMinimumRewards(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasTokenSpecificMinimumRewardsStoreKey(), "should not have token specific minimum rewards initially")

		rewards := avl.NewTree()
		err := ss.SetTokenSpecificMinimumRewards(rewards)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasTokenSpecificMinimumRewardsStoreKey(), "should have token specific minimum rewards after setting")

		retrieved := ss.GetTokenSpecificMinimumRewards()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized token specific minimum rewards")
		}()

		ss.GetTokenSpecificMinimumRewards()
	})
}

func TestStoreSetAndGetPoolTierMemberships(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasPoolTierMembershipsStoreKey(), "should not have pool tier memberships initially")

		memberships := avl.NewTree()
		err := ss.SetPoolTierMemberships(memberships)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasPoolTierMembershipsStoreKey(), "should have pool tier memberships after setting")

		retrieved := ss.GetPoolTierMemberships()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized pool tier memberships")
		}()

		ss.GetPoolTierMemberships()
	})
}

func TestStoreSetAndGetPoolTierRatio(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasPoolTierRatioStoreKey(), "should not have pool tier ratio initially")

		ratio := TierRatio{100, 200, 300}
		err := ss.SetPoolTierRatio(ratio)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasPoolTierRatioStoreKey(), "should have pool tier ratio after setting")

		retrieved := ss.GetPoolTierRatio()
		uassert.Equal(t, uint64(100), retrieved.Tier1)
		uassert.Equal(t, uint64(200), retrieved.Tier2)
		uassert.Equal(t, uint64(300), retrieved.Tier3)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized pool tier ratio")
		}()

		ss.GetPoolTierRatio()
	})
}

func TestStoreSetAndGetPoolTierCounts(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasPoolTierCountsStoreKey(), "should not have pool tier counts initially")

		counts := [AllTierCount]uint64{10, 20, 30}
		err := ss.SetPoolTierCounts(counts)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasPoolTierCountsStoreKey(), "should have pool tier counts after setting")

		retrieved := ss.GetPoolTierCounts()
		uassert.Equal(t, uint64(10), retrieved[0])
		uassert.Equal(t, uint64(20), retrieved[1])
		uassert.Equal(t, uint64(30), retrieved[2])
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized pool tier counts")
		}()

		ss.GetPoolTierCounts()
	})
}

func TestStoreSetAndGetPoolTierLastRewardCacheTimestamp(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasPoolTierLastRewardCacheTimestampStoreKey(), "should not have pool tier last reward cache timestamp initially")

		err := ss.SetPoolTierLastRewardCacheTimestamp(1234567890)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasPoolTierLastRewardCacheTimestampStoreKey(), "should have pool tier last reward cache timestamp after setting")

		retrieved := ss.GetPoolTierLastRewardCacheTimestamp()
		uassert.Equal(t, int64(1234567890), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized pool tier last reward cache timestamp")
		}()

		ss.GetPoolTierLastRewardCacheTimestamp()
	})
}

func TestStoreSetAndGetPoolTierLastRewardCacheHeight(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasPoolTierLastRewardCacheHeightStoreKey(), "should not have pool tier last reward cache height initially")

		err := ss.SetPoolTierLastRewardCacheHeight(1000)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasPoolTierLastRewardCacheHeightStoreKey(), "should have pool tier last reward cache height after setting")

		retrieved := ss.GetPoolTierLastRewardCacheHeight()
		uassert.Equal(t, int64(1000), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized pool tier last reward cache height")
		}()

		ss.GetPoolTierLastRewardCacheHeight()
	})
}

func TestStoreSetAndGetPoolTierCurrentEmission(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasPoolTierCurrentEmissionStoreKey(), "should not have pool tier current emission initially")

		err := ss.SetPoolTierCurrentEmission(50000)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasPoolTierCurrentEmissionStoreKey(), "should have pool tier current emission after setting")

		retrieved := ss.GetPoolTierCurrentEmission()
		uassert.Equal(t, int64(50000), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized pool tier current emission")
		}()

		ss.GetPoolTierCurrentEmission()
	})
}

func TestStoreSetAndGetPoolTierGetEmission(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasPoolTierGetEmissionStoreKey(), "should not have pool tier get emission initially")

		emissionFunc := func() int64 { return 1000 }
		err := ss.SetPoolTierGetEmission(emissionFunc)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasPoolTierGetEmissionStoreKey(), "should have pool tier get emission after setting")

		retrieved := ss.GetPoolTierGetEmission()
		uassert.NotEqual(t, nil, retrieved)
		uassert.Equal(t, int64(1000), retrieved())
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized pool tier get emission")
		}()

		ss.GetPoolTierGetEmission()
	})
}

func TestStoreSetAndGetPoolTierGetHalvingBlocksInRange(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasPoolTierGetHalvingBlocksInRangeStoreKey(), "should not have pool tier get halving blocks in range initially")

		halvingFunc := func(start, end int64) ([]int64, []int64) {
			return []int64{100, 200}, []int64{10, 20}
		}
		err := ss.SetPoolTierGetHalvingBlocksInRange(halvingFunc)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasPoolTierGetHalvingBlocksInRangeStoreKey(), "should have pool tier get halving blocks in range after setting")

		retrieved := ss.GetPoolTierGetHalvingBlocksInRange()
		uassert.NotEqual(t, nil, retrieved)

		blocks, heights := retrieved(0, 1000)
		uassert.Equal(t, 2, len(blocks))
		uassert.Equal(t, 2, len(heights))
		uassert.Equal(t, int64(100), blocks[0])
		uassert.Equal(t, int64(10), heights[0])
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized pool tier get halving blocks in range")
		}()

		ss.GetPoolTierGetHalvingBlocksInRange()
	})
}

func TestStoreSetAndGetWarmupTemplate(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasWarmupTemplateStoreKey(), "should not have warmup template initially")

		warmups := []Warmup{{WarmupRatio: 50, TimeDuration: 100}, {WarmupRatio: 100, TimeDuration: 200}}
		err := ss.SetWarmupTemplate(warmups)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasWarmupTemplateStoreKey(), "should have warmup template after setting")

		retrieved := ss.GetWarmupTemplate()
		uassert.NotEqual(t, nil, retrieved)
		uassert.Equal(t, 2, len(retrieved))
		uassert.Equal(t, uint64(50), retrieved[0].WarmupRatio)
		uassert.Equal(t, int64(100), retrieved[0].TimeDuration)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized warmup template")
		}()

		ss.GetWarmupTemplate()
	})
}

func TestStoreSetAndGetCurrentSwapBatch(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasCurrentSwapBatchStoreKey(), "should not have current swap batch initially")

		batch := &SwapBatchProcessor{}
		err := ss.SetCurrentSwapBatch(batch)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasCurrentSwapBatchStoreKey(), "should have current swap batch after setting")

		retrieved := ss.GetCurrentSwapBatch()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized current swap batch")
		}()

		ss.GetCurrentSwapBatch()
	})
}

func TestStoreSetAndGetExternalIncentivesByCreationTime(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		uassert.False(t, ss.HasExternalIncentivesByCreationTimeStoreKey(), "should not have external incentives by creation time initially")

		tree := NewUintTree()
		err := ss.SetExternalIncentivesByCreationTime(tree)
		uassert.NoError(t, err)

		uassert.True(t, ss.HasExternalIncentivesByCreationTimeStoreKey(), "should have external incentives by creation time after setting")

		retrieved := ss.GetExternalIncentivesByCreationTime()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ss := NewStakerStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized external incentives by creation time")
		}()

		ss.GetExternalIncentivesByCreationTime()
	})
}

func TestStoreMultipleSetAndGet(t *testing.T) {
	resetTestState(t)

	ss := NewStakerStore(kvStore)

	err := ss.SetDepositGnsAmount(1000000)
	uassert.NoError(t, err)

	err = ss.SetMinimumRewardAmount(100)
	uassert.NoError(t, err)

	deposits := avl.NewTree()
	err = ss.SetDeposits(deposits)
	uassert.NoError(t, err)

	stakers := avl.NewTree()
	err = ss.SetStakers(stakers)
	uassert.NoError(t, err)

	err = ss.SetTotalEmissionSent(50000)
	uassert.NoError(t, err)

	tokens := []string{"token1", "token2"}
	err = ss.SetAllowedTokens(tokens)
	uassert.NoError(t, err)

	err = ss.SetUnstakingFee(25)
	uassert.NoError(t, err)

	uassert.True(t, ss.HasDepositGnsAmountStoreKey())
	uassert.True(t, ss.HasMinimumRewardAmountStoreKey())
	uassert.True(t, ss.HasDepositsStoreKey())
	uassert.True(t, ss.HasStakersStoreKey())
	uassert.True(t, ss.HasTotalEmissionSentStoreKey())
	uassert.True(t, ss.HasAllowedTokensStoreKey())
	uassert.True(t, ss.HasUnstakingFeeStoreKey())

	uassert.Equal(t, int64(1000000), ss.GetDepositGnsAmount())
	uassert.Equal(t, int64(100), ss.GetMinimumRewardAmount())
	uassert.Equal(t, int64(50000), ss.GetTotalEmissionSent())
	uassert.Equal(t, int64(25), ss.GetUnstakingFee())

	retrievedTokens := ss.GetAllowedTokens()
	uassert.Equal(t, 2, len(retrievedTokens))
}
