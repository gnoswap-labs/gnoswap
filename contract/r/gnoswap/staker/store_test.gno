package staker

import (
	"chain/runtime"
	"testing"

	bptree "gno.land/p/nt/bptree/v0"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestStoreInitialization(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			tt.verifyFn(t)
		})
	}
}

func TestStore_AuthorizedCallers(cur realm, t *testing.T) {
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
			expectedErrorWithRead:         false,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "",
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
			expectedErrorWithRead:         false,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "",
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
		t.Run(tc.name, func(cur realm, t *testing.T) {
			resetTestState(t)

			ss := NewStakerStore(kvStore)
			initRegisterWritableContract(cur)

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker"))
			if !ss.HasAllowedTokensStoreKey() {
				ss.SetAllowedTokens(0, cur, []string{})
			}

			testing.SetRealm(tc.callerRealm)
			if tc.expectedErrorWithRead {
				uassert.PanicsContains(t, cur, tc.expectedErrorMessageWithRead, func() {
					ss.GetAllowedTokens()
				})
			} else {
				ss.GetAllowedTokens()
			}

			err := ss.SetAllowedTokens(0, cur, []string{"gno.land/r/demo/token1"})
			if tc.expectedErrorWithWrite {
				uassert.ErrorContains(t, err, tc.expectedErrorMessageWithWrite)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestStoreSetAndGetDepositGnsAmount(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get deposit gns amount successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				ss.SetDepositGnsAmount(0, cur, 1000000)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasDepositGnsAmountStoreKey(), "should have deposit gns amount after setting")
				retrieved := ss.GetDepositGnsAmount()
				uassert.Equal(t, int64(1000000), retrieved)
			},
		},
		{
			name: "should not have deposit gns amount initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasDepositGnsAmountStoreKey(), "should not have deposit gns amount initially")
			},
		},
		{
			name: "panic when getting uninitialized deposit gns amount",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetDepositGnsAmount()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized deposit gns amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetMinimumRewardAmount(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get minimum reward amount successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				ss.SetMinimumRewardAmount(0, cur, 100)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasMinimumRewardAmountStoreKey(), "should have minimum reward amount after setting")
				retrieved := ss.GetMinimumRewardAmount()
				uassert.Equal(t, int64(100), retrieved)
			},
		},
		{
			name: "should not have minimum reward amount initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasMinimumRewardAmountStoreKey(), "should not have minimum reward amount initially")
			},
		},
		{
			name: "panic when getting uninitialized minimum reward amount",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetMinimumRewardAmount()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized minimum reward amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetDeposits(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get deposits successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				deposits := bptree.NewBPTreeN(16)
				ss.SetDeposits(0, cur, deposits)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasDepositsStoreKey(), "should have deposits after setting")
				retrieved := ss.GetDeposits()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have deposits initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasDepositsStoreKey(), "should not have deposits initially")
			},
		},
		{
			name: "panic when getting uninitialized deposits",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetDeposits()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized deposits",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetExternalIncentives(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get external incentives successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				incentives := bptree.NewBPTreeN(16)
				ss.SetExternalIncentives(0, cur, incentives)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasExternalIncentivesStoreKey(), "should have external incentives after setting")
				retrieved := ss.GetExternalIncentives()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have external incentives initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasExternalIncentivesStoreKey(), "should not have external incentives initially")
			},
		},
		{
			name: "panic when getting uninitialized external incentives",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetExternalIncentives()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized external incentives",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetTotalEmissionSent(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get total emission sent successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				ss.SetTotalEmissionSent(0, cur, 50000)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasTotalEmissionSentStoreKey(), "should have total emission sent after setting")
				retrieved := ss.GetTotalEmissionSent()
				uassert.Equal(t, int64(50000), retrieved)
			},
		},
		{
			name: "should not have total emission sent initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasTotalEmissionSentStoreKey(), "should not have total emission sent initially")
			},
		},
		{
			name: "panic when getting uninitialized total emission sent",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetTotalEmissionSent()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized total emission sent",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetAllowedTokens(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get allowed tokens successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				tokens := []string{"gno.land/r/demo/token1", "gno.land/r/demo/token2"}
				ss.SetAllowedTokens(0, cur, tokens)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasAllowedTokensStoreKey(), "should have allowed tokens after setting")
				retrieved := ss.GetAllowedTokens()
				uassert.NotEqual(t, nil, retrieved)
				uassert.Equal(t, 2, len(retrieved))
			},
		},
		{
			name: "should not have allowed tokens initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasAllowedTokensStoreKey(), "should not have allowed tokens initially")
			},
		},
		{
			name: "panic when getting uninitialized allowed tokens",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetAllowedTokens()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized allowed tokens",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreAddAndRemoveAllowedToken(cur realm, t *testing.T) {
	resetTestState(t)
	ss := NewStakerStore(kvStore)

	defaultTokens := DefaultAllowedTokens()
	err := ss.SetAllowedTokens(0, cur, defaultTokens)
	uassert.NoError(t, err)

	customToken := "gno.land/r/demo/custom"
	err = ss.AddAllowedToken(0, cur, customToken)
	uassert.NoError(t, err)

	tokens := ss.GetAllowedTokens()
	uassert.Equal(t, 3, len(tokens))
	uassert.Equal(t, customToken, tokens[2])

	// Idempotent add must not duplicate.
	err = ss.AddAllowedToken(0, cur, customToken)
	uassert.NoError(t, err)
	uassert.Equal(t, 3, len(ss.GetAllowedTokens()))

	err = ss.RemoveAllowedToken(0, cur, customToken)
	uassert.NoError(t, err)
	uassert.Equal(t, 2, len(ss.GetAllowedTokens()))

	// Removing a missing token is a no-op.
	err = ss.RemoveAllowedToken(0, cur, customToken)
	uassert.NoError(t, err)
	uassert.Equal(t, 2, len(ss.GetAllowedTokens()))
}

func TestStoreSetAndGetIncentiveCounter(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get incentive counter successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				counter := &Counter{}
				ss.SetIncentiveCounter(0, cur, counter)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasIncentiveCounterStoreKey(), "should have incentive counter after setting")
				retrieved := ss.GetIncentiveCounter()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have incentive counter initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasIncentiveCounterStoreKey(), "should not have incentive counter initially")
			},
		},
		{
			name: "panic when getting uninitialized incentive counter",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetIncentiveCounter()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized incentive counter",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetUnstakingFee(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get unstaking fee successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				ss.SetUnstakingFee(0, cur, 25)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasUnstakingFeeStoreKey(), "should have unstaking fee after setting")
				retrieved := ss.GetUnstakingFee()
				uassert.Equal(t, uint64(25), retrieved)
			},
		},
		{
			name: "should not have unstaking fee initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasUnstakingFeeStoreKey(), "should not have unstaking fee initially")
			},
		},
		{
			name: "panic when getting uninitialized unstaking fee",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetUnstakingFee()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized unstaking fee",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetPools(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pools successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				pools := bptree.NewBPTreeN(16)
				ss.SetPools(0, cur, pools)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolsStoreKey(), "should have pools after setting")
				retrieved := ss.GetPools()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have pools initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolsStoreKey(), "should not have pools initially")
			},
		},
		{
			name: "panic when getting uninitialized pools",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetPools()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pools",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetTokenSpecificMinimumRewards(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get token specific minimum rewards successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				rewards := make(map[string]int64)
				ss.SetTokenSpecificMinimumRewards(0, cur, rewards)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasTokenSpecificMinimumRewardsStoreKey(), "should have token specific minimum rewards after setting")
				retrieved := ss.GetTokenSpecificMinimumRewards()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have token specific minimum rewards initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasTokenSpecificMinimumRewardsStoreKey(), "should not have token specific minimum rewards initially")
			},
		},
		{
			name: "panic when getting uninitialized token specific minimum rewards",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetTokenSpecificMinimumRewards()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized token specific minimum rewards",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierMemberships(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier memberships successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				memberships := bptree.NewBPTreeN(16)
				ss.SetPoolTierMemberships(0, cur, memberships)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierMembershipsStoreKey(), "should have pool tier memberships after setting")
				retrieved := ss.GetPoolTierMemberships()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have pool tier memberships initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierMembershipsStoreKey(), "should not have pool tier memberships initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier memberships",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetPoolTierMemberships()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier memberships",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierRatio(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier ratio successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				ratio := TierRatio{100, 200, 300}
				ss.SetPoolTierRatio(0, cur, ratio)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierRatioStoreKey(), "should have pool tier ratio after setting")
				retrieved := ss.GetPoolTierRatio()
				uassert.Equal(t, uint64(100), retrieved.Tier1)
				uassert.Equal(t, uint64(200), retrieved.Tier2)
				uassert.Equal(t, uint64(300), retrieved.Tier3)
			},
		},
		{
			name: "should not have pool tier ratio initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierRatioStoreKey(), "should not have pool tier ratio initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier ratio",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetPoolTierRatio()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier ratio",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierCounts(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier counts successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				counts := [AllTierCount]uint64{10, 20, 30}
				ss.SetPoolTierCounts(0, cur, counts)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierCountsStoreKey(), "should have pool tier counts after setting")
				retrieved := ss.GetPoolTierCounts()
				uassert.Equal(t, uint64(10), retrieved[0])
				uassert.Equal(t, uint64(20), retrieved[1])
				uassert.Equal(t, uint64(30), retrieved[2])
			},
		},
		{
			name: "should not have pool tier counts initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierCountsStoreKey(), "should not have pool tier counts initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier counts",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetPoolTierCounts()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier counts",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierLastRewardCacheTimestamp(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier last reward cache timestamp successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				ss.SetPoolTierLastRewardCacheTimestamp(0, cur, 1234567890)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierLastRewardCacheTimestampStoreKey(), "should have pool tier last reward cache timestamp after setting")
				retrieved := ss.GetPoolTierLastRewardCacheTimestamp()
				uassert.Equal(t, int64(1234567890), retrieved)
			},
		},
		{
			name: "should not have pool tier last reward cache timestamp initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierLastRewardCacheTimestampStoreKey(), "should not have pool tier last reward cache timestamp initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier last reward cache timestamp",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetPoolTierLastRewardCacheTimestamp()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier last reward cache timestamp",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierCurrentEmission(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier current emission successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				ss.SetPoolTierCurrentEmission(0, cur, 50000)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierCurrentEmissionStoreKey(), "should have pool tier current emission after setting")
				retrieved := ss.GetPoolTierCurrentEmission()
				uassert.Equal(t, int64(50000), retrieved)
			},
		},
		{
			name: "should not have pool tier current emission initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierCurrentEmissionStoreKey(), "should not have pool tier current emission initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier current emission",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetPoolTierCurrentEmission()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier current emission",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierGetEmission(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier get emission successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				emissionFunc := func() int64 { return 1000 }
				ss.SetPoolTierGetEmission(0, cur, emissionFunc)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasPoolTierGetEmissionStoreKey(), "should have pool tier get emission after setting")
				retrieved := ss.GetPoolTierGetEmission()
				uassert.NotEqual(t, nil, retrieved)
				uassert.Equal(t, int64(1000), retrieved())
			},
		},
		{
			name: "should not have pool tier get emission initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierGetEmissionStoreKey(), "should not have pool tier get emission initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier get emission",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetPoolTierGetEmission()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier get emission",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetPoolTierGetHalvingBlocksInRange(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool tier get halving blocks in range successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				halvingFunc := func(start, end int64) ([]int64, []int64) {
					return []int64{100, 200}, []int64{10, 20}
				}
				ss.SetPoolTierGetHalvingBlocksInRange(0, cur, halvingFunc)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
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
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasPoolTierGetHalvingBlocksInRangeStoreKey(), "should not have pool tier get halving blocks in range initially")
			},
		},
		{
			name: "panic when getting uninitialized pool tier get halving blocks in range",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetPoolTierGetHalvingBlocksInRange()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool tier get halving blocks in range",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetWarmupTemplate(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get warmup template successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				warmups := []Warmup{{WarmupRatio: 50, TimeDuration: 100}, {WarmupRatio: 100, TimeDuration: 200}}
				ss.SetWarmupTemplate(0, cur, warmups)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
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
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasWarmupTemplateStoreKey(), "should not have warmup template initially")
			},
		},
		{
			name: "panic when getting uninitialized warmup template",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetWarmupTemplate()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized warmup template",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetCurrentSwapBatch(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get current swap batch successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				batch := &SwapBatchProcessor{}
				ss.SetCurrentSwapBatch(0, cur, batch)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasCurrentSwapBatchStoreKey(), "should have current swap batch after setting")
				retrieved := ss.GetCurrentSwapBatch()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have current swap batch initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasCurrentSwapBatchStoreKey(), "should not have current swap batch initially")
			},
		},
		{
			name: "panic when getting uninitialized current swap batch",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetCurrentSwapBatch()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized current swap batch",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreSetAndGetExternalIncentivesByCreationTime(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ss IStakerStore)
		testFn       func(cur realm, t *testing.T, ss IStakerStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get external incentives by creation time successfully",
			setupFn: func(cur realm, ss IStakerStore) {
				tree := NewUintTree()
				ss.SetExternalIncentivesByCreationTime(0, cur, tree)
			},
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.True(t, ss.HasExternalIncentivesByCreationTimeStoreKey(), "should have external incentives by creation time after setting")
				retrieved := ss.GetExternalIncentivesByCreationTime()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have external incentives by creation time initially",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				uassert.False(t, ss.HasExternalIncentivesByCreationTimeStoreKey(), "should not have external incentives by creation time initially")
			},
		},
		{
			name: "panic when getting uninitialized external incentives by creation time",
			testFn: func(cur realm, t *testing.T, ss IStakerStore) {
				ss.GetExternalIncentivesByCreationTime()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized external incentives by creation time",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ss := NewStakerStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ss)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ss)
		})
	}
}

func TestStoreMultipleSetAndGet(cur realm, t *testing.T) {
	resetTestState(t)

	ss := NewStakerStore(kvStore)

	err := ss.SetDepositGnsAmount(0, cur, 1000000)
	uassert.NoError(t, err)

	err = ss.SetMinimumRewardAmount(0, cur, 100)
	uassert.NoError(t, err)

	deposits := bptree.NewBPTreeN(16)
	err = ss.SetDeposits(0, cur, deposits)
	uassert.NoError(t, err)

	err = ss.SetTotalEmissionSent(0, cur, 50000)
	uassert.NoError(t, err)

	tokens := []string{"token1", "token2"}
	err = ss.SetAllowedTokens(0, cur, tokens)
	uassert.NoError(t, err)

	err = ss.SetUnstakingFee(0, cur, 25)
	uassert.NoError(t, err)

	uassert.True(t, ss.HasDepositGnsAmountStoreKey())
	uassert.True(t, ss.HasMinimumRewardAmountStoreKey())
	uassert.True(t, ss.HasDepositsStoreKey())
	uassert.True(t, ss.HasTotalEmissionSentStoreKey())
	uassert.True(t, ss.HasAllowedTokensStoreKey())
	uassert.True(t, ss.HasUnstakingFeeStoreKey())

	uassert.Equal(t, int64(1000000), ss.GetDepositGnsAmount())
	uassert.Equal(t, int64(100), ss.GetMinimumRewardAmount())
	uassert.Equal(t, int64(50000), ss.GetTotalEmissionSent())
	uassert.Equal(t, uint64(25), ss.GetUnstakingFee())

	retrievedTokens := ss.GetAllowedTokens()
	uassert.Equal(t, 2, len(retrievedTokens))
}
