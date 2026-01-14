package staker

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

func TestStoreInitialization(t *testing.T) {
	tests := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "kvStore should be initialized",
			verifyFn: func(t *testing.T) {
				uassert.NotEqual(t, nil, kvStore, "kvStore should be initialized")
			},
		},
		{
			name: "domain address should not be empty",
			verifyFn: func(t *testing.T) {
				domainAddr := kvStore.GetDomainAddress()
				uassert.NotEqual(t, address(""), domainAddr, "domain address should not be empty")
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			tt.verifyFn(t)
		})
	}
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
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get deposit gns amount successfully",
			setupFn: func(ss IStakerStore) {
				ss.SetDepositGnsAmount(1000000)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasDepositGnsAmountStoreKey(), "should have deposit gns amount after setting")
				retrieved := ss.GetDepositGnsAmount()
				uassert.Equal(t, int64(1000000), retrieved)
			},
		},
		{
			name: "should not have deposit gns amount initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasDepositGnsAmountStoreKey(), "should not have deposit gns amount initially")
			},
		},
		{
			name: "panic when getting uninitialized deposit gns amount",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetDepositGnsAmount()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized deposit gns amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetMinimumRewardAmount(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get minimum reward amount successfully",
			setupFn: func(ss IStakerStore) {
				ss.SetMinimumRewardAmount(100)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasMinimumRewardAmountStoreKey(), "should have minimum reward amount after setting")
				retrieved := ss.GetMinimumRewardAmount()
				uassert.Equal(t, int64(100), retrieved)
			},
		},
		{
			name: "should not have minimum reward amount initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasMinimumRewardAmountStoreKey(), "should not have minimum reward amount initially")
			},
		},
		{
			name: "panic when getting uninitialized minimum reward amount",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetMinimumRewardAmount()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized minimum reward amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetDeposits(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get deposits successfully",
			setupFn: func(ss IStakerStore) {
				deposits := avl.NewTree()
				ss.SetDeposits(deposits)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasDepositsStoreKey(), "should have deposits after setting")
				retrieved := ss.GetDeposits()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have deposits initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasDepositsStoreKey(), "should not have deposits initially")
			},
		},
		{
			name: "panic when getting uninitialized deposits",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetDeposits()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized deposits",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetExternalIncentives(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get external incentives successfully",
			setupFn: func(ss IStakerStore) {
				incentives := avl.NewTree()
				ss.SetExternalIncentives(incentives)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasExternalIncentivesStoreKey(), "should have external incentives after setting")
				retrieved := ss.GetExternalIncentives()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have external incentives initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasExternalIncentivesStoreKey(), "should not have external incentives initially")
			},
		},
		{
			name: "panic when getting uninitialized external incentives",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetExternalIncentives()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized external incentives",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetStakers(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get stakers successfully",
			setupFn: func(ss IStakerStore) {
				stakers := avl.NewTree()
				ss.SetStakers(stakers)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasStakersStoreKey(), "should have stakers after setting")
				retrieved := ss.GetStakers()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have stakers initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasStakersStoreKey(), "should not have stakers initially")
			},
		},
		{
			name: "panic when getting uninitialized stakers",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetStakers()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized stakers",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetTotalEmissionSent(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get total emission sent successfully",
			setupFn: func(ss IStakerStore) {
				ss.SetTotalEmissionSent(50000)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasTotalEmissionSentStoreKey(), "should have total emission sent after setting")
				retrieved := ss.GetTotalEmissionSent()
				uassert.Equal(t, int64(50000), retrieved)
			},
		},
		{
			name: "should not have total emission sent initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasTotalEmissionSentStoreKey(), "should not have total emission sent initially")
			},
		},
		{
			name: "panic when getting uninitialized total emission sent",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetTotalEmissionSent()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized total emission sent",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetAllowedTokens(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get allowed tokens successfully",
			setupFn: func(ss IStakerStore) {
				tokens := []string{"gno.land/r/demo/token1", "gno.land/r/demo/token2"}
				ss.SetAllowedTokens(tokens)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasAllowedTokensStoreKey(), "should have allowed tokens after setting")
				retrieved := ss.GetAllowedTokens()
				uassert.NotEqual(t, nil, retrieved)
				uassert.Equal(t, 2, len(retrieved))
			},
		},
		{
			name: "should not have allowed tokens initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasAllowedTokensStoreKey(), "should not have allowed tokens initially")
			},
		},
		{
			name: "panic when getting uninitialized allowed tokens",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetAllowedTokens()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized allowed tokens",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetIncentiveCounter(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get incentive counter successfully",
			setupFn: func(ss IStakerStore) {
				counter := &Counter{}
				ss.SetIncentiveCounter(counter)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasIncentiveCounterStoreKey(), "should have incentive counter after setting")
				retrieved := ss.GetIncentiveCounter()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have incentive counter initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasIncentiveCounterStoreKey(), "should not have incentive counter initially")
			},
		},
		{
			name: "panic when getting uninitialized incentive counter",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetIncentiveCounter()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized incentive counter",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetUnstakingFee(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get unstaking fee successfully",
			setupFn: func(ss IStakerStore) {
				ss.SetUnstakingFee(25)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasUnstakingFeeStoreKey(), "should have unstaking fee after setting")
				retrieved := ss.GetUnstakingFee()
				uassert.Equal(t, int64(25), retrieved)
			},
		},
		{
			name: "should not have unstaking fee initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasUnstakingFeeStoreKey(), "should not have unstaking fee initially")
			},
		},
		{
			name: "panic when getting uninitialized unstaking fee",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetUnstakingFee()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized unstaking fee",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetPools(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pools successfully",
			setupFn: func(ss IStakerStore) {
				pools := avl.NewTree()
				ss.SetPools(pools)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolsStoreKey(), "should have pools after setting")
				retrieved := ss.GetPools()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have pools initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolsStoreKey(), "should not have pools initially")
			},
		},
		{
			name: "panic when getting uninitialized pools",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetPools()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pools",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetTokenSpecificMinimumRewards(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get token specific minimum rewards successfully",
			setupFn: func(ss IStakerStore) {
				rewards := avl.NewTree()
				ss.SetTokenSpecificMinimumRewards(rewards)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasTokenSpecificMinimumRewardsStoreKey(), "should have token specific minimum rewards after setting")
				retrieved := ss.GetTokenSpecificMinimumRewards()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have token specific minimum rewards initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasTokenSpecificMinimumRewardsStoreKey(), "should not have token specific minimum rewards initially")
			},
		},
		{
			name: "panic when getting uninitialized token specific minimum rewards",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetTokenSpecificMinimumRewards()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized token specific minimum rewards",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierMemberships(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier memberships successfully",
			setupFn: func(ss IStakerStore) {
				memberships := avl.NewTree()
				ss.SetPoolTierMemberships(memberships)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierMembershipsStoreKey(), "should have pool tier memberships after setting")
				retrieved := ss.GetPoolTierMemberships()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have pool tier memberships initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierMembershipsStoreKey(), "should not have pool tier memberships initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier memberships",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetPoolTierMemberships()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier memberships",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierRatio(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier ratio successfully",
			setupFn: func(ss IStakerStore) {
				ratio := TierRatio{100, 200, 300}
				ss.SetPoolTierRatio(ratio)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierRatioStoreKey(), "should have pool tier ratio after setting")
				retrieved := ss.GetPoolTierRatio()
				uassert.Equal(t, uint64(100), retrieved.Tier1)
				uassert.Equal(t, uint64(200), retrieved.Tier2)
				uassert.Equal(t, uint64(300), retrieved.Tier3)
			},
		},
		{
			name: "should not have pool tier ratio initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierRatioStoreKey(), "should not have pool tier ratio initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier ratio",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetPoolTierRatio()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier ratio",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierCounts(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier counts successfully",
			setupFn: func(ss IStakerStore) {
				counts := [AllTierCount]uint64{10, 20, 30}
				ss.SetPoolTierCounts(counts)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierCountsStoreKey(), "should have pool tier counts after setting")
				retrieved := ss.GetPoolTierCounts()
				uassert.Equal(t, uint64(10), retrieved[0])
				uassert.Equal(t, uint64(20), retrieved[1])
				uassert.Equal(t, uint64(30), retrieved[2])
			},
		},
		{
			name: "should not have pool tier counts initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierCountsStoreKey(), "should not have pool tier counts initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier counts",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetPoolTierCounts()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier counts",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierLastRewardCacheTimestamp(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier last reward cache timestamp successfully",
			setupFn: func(ss IStakerStore) {
				ss.SetPoolTierLastRewardCacheTimestamp(1234567890)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierLastRewardCacheTimestampStoreKey(), "should have pool tier last reward cache timestamp after setting")
				retrieved := ss.GetPoolTierLastRewardCacheTimestamp()
				uassert.Equal(t, int64(1234567890), retrieved)
			},
		},
		{
			name: "should not have pool tier last reward cache timestamp initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierLastRewardCacheTimestampStoreKey(), "should not have pool tier last reward cache timestamp initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier last reward cache timestamp",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetPoolTierLastRewardCacheTimestamp()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier last reward cache timestamp",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierLastRewardCacheHeight(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier last reward cache height successfully",
			setupFn: func(ss IStakerStore) {
				ss.SetPoolTierLastRewardCacheHeight(1000)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierLastRewardCacheHeightStoreKey(), "should have pool tier last reward cache height after setting")
				retrieved := ss.GetPoolTierLastRewardCacheHeight()
				uassert.Equal(t, int64(1000), retrieved)
			},
		},
		{
			name: "should not have pool tier last reward cache height initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierLastRewardCacheHeightStoreKey(), "should not have pool tier last reward cache height initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier last reward cache height",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetPoolTierLastRewardCacheHeight()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier last reward cache height",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierCurrentEmission(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier current emission successfully",
			setupFn: func(ss IStakerStore) {
				ss.SetPoolTierCurrentEmission(50000)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierCurrentEmissionStoreKey(), "should have pool tier current emission after setting")
				retrieved := ss.GetPoolTierCurrentEmission()
				uassert.Equal(t, int64(50000), retrieved)
			},
		},
		{
			name: "should not have pool tier current emission initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierCurrentEmissionStoreKey(), "should not have pool tier current emission initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier current emission",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetPoolTierCurrentEmission()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier current emission",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierGetEmission(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier get emission successfully",
			setupFn: func(ss IStakerStore) {
				emissionFunc := func() int64 { return 1000 }
				ss.SetPoolTierGetEmission(emissionFunc)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierGetEmissionStoreKey(), "should have pool tier get emission after setting")
				retrieved := ss.GetPoolTierGetEmission()
				uassert.NotEqual(t, nil, retrieved)
				uassert.Equal(t, int64(1000), retrieved())
			},
		},
		{
			name: "should not have pool tier get emission initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierGetEmissionStoreKey(), "should not have pool tier get emission initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier get emission",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetPoolTierGetEmission()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier get emission",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierGetHalvingBlocksInRange(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier get halving blocks in range successfully",
			setupFn: func(ss IStakerStore) {
				halvingFunc := func(start, end int64) ([]int64, []int64) {
					return []int64{100, 200}, []int64{10, 20}
				}
				ss.SetPoolTierGetHalvingBlocksInRange(halvingFunc)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierGetHalvingBlocksInRangeStoreKey(), "should have pool tier get halving blocks in range after setting")
				retrieved := ss.GetPoolTierGetHalvingBlocksInRange()
				uassert.NotEqual(t, nil, retrieved)

				blocks, heights := retrieved(0, 1000)
				uassert.Equal(t, 2, len(blocks))
				uassert.Equal(t, 2, len(heights))
				uassert.Equal(t, int64(100), blocks[0])
				uassert.Equal(t, int64(10), heights[0])
			},
		},
		{
			name: "should not have pool tier get halving blocks in range initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierGetHalvingBlocksInRangeStoreKey(), "should not have pool tier get halving blocks in range initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier get halving blocks in range",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetPoolTierGetHalvingBlocksInRange()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier get halving blocks in range",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetWarmupTemplate(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get warmup template successfully",
			setupFn: func(ss IStakerStore) {
				warmups := []Warmup{{WarmupRatio: 50, TimeDuration: 100}, {WarmupRatio: 100, TimeDuration: 200}}
				ss.SetWarmupTemplate(warmups)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasWarmupTemplateStoreKey(), "should have warmup template after setting")
				retrieved := ss.GetWarmupTemplate()
				uassert.NotEqual(t, nil, retrieved)
				uassert.Equal(t, 2, len(retrieved))
				uassert.Equal(t, uint64(50), retrieved[0].WarmupRatio)
				uassert.Equal(t, int64(100), retrieved[0].TimeDuration)
			},
		},
		{
			name: "should not have warmup template initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasWarmupTemplateStoreKey(), "should not have warmup template initially")
			},
		},
		{
			name: "panic when getting uninitialized warmup template",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetWarmupTemplate()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized warmup template",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetCurrentSwapBatch(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get current swap batch successfully",
			setupFn: func(ss IStakerStore) {
				batch := &SwapBatchProcessor{}
				ss.SetCurrentSwapBatch(batch)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasCurrentSwapBatchStoreKey(), "should have current swap batch after setting")
				retrieved := ss.GetCurrentSwapBatch()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have current swap batch initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasCurrentSwapBatchStoreKey(), "should not have current swap batch initially")
			},
		},
		{
			name: "panic when getting uninitialized current swap batch",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetCurrentSwapBatch()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized current swap batch",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
}

func TestStoreSetAndGetExternalIncentivesByCreationTime(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IStakerStore)
		testFn       func(*testing.T, IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get external incentives by creation time successfully",
			setupFn: func(ss IStakerStore) {
				tree := NewUintTree()
				ss.SetExternalIncentivesByCreationTime(tree)
			},
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasExternalIncentivesByCreationTimeStoreKey(), "should have external incentives by creation time after setting")
				retrieved := ss.GetExternalIncentivesByCreationTime()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have external incentives by creation time initially",
			testFn: func(t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasExternalIncentivesByCreationTimeStoreKey(), "should not have external incentives by creation time initially")
			},
		},
		{
			name: "panic when getting uninitialized external incentives by creation time",
			testFn: func(t *testing.T, ss IStakerStore) {
				ss.GetExternalIncentivesByCreationTime()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized external incentives by creation time",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ss)
		})
	}
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
