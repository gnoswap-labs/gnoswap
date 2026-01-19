package protocol_fee

import (
	"chain/runtime"
	"testing"

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
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"),
		},
		{
			name:                          "domain implementation has no permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v2"),
			expectedErrorWithRead:         true,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "read permission denied",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                          "gov/staker has read permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"),
			expectedErrorWithRead:         false,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                          "panic with no permission realm",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
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

			ps := NewProtocolFeeStore(kvStore)
			initRegisterReadableContract()

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			if !ps.HasDevOpsPctStoreKey() {
				ps.SetDevOpsPct(10)
			}

			testing.SetRealm(tc.callerRealm)
			if tc.expectedErrorWithRead {
				uassert.PanicsContains(t, tc.expectedErrorMessageWithRead, func() {
					ps.GetDevOpsPct()
				})
			} else {
				ps.GetDevOpsPct()
			}

			err := ps.SetDevOpsPct(20)
			if tc.expectedErrorWithWrite {
				uassert.ErrorContains(t, err, tc.expectedErrorMessageWithWrite)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestStoreSetAndGetDevOpsPct(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IProtocolFeeStore)
		testFn       func(*testing.T, IProtocolFeeStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get dev ops pct successfully",
			setupFn: func(ps IProtocolFeeStore) {
				ps.SetDevOpsPct(25)
			},
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				uassert.True(t, ps.HasDevOpsPctStoreKey(), "should have dev ops pct after setting")
				retrieved := ps.GetDevOpsPct()
				uassert.Equal(t, int64(25), retrieved)
			},
		},
		{
			name: "should not have dev ops pct initially",
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				uassert.False(t, ps.HasDevOpsPctStoreKey(), "should not have dev ops pct initially")
			},
		},
		{
			name: "panic when getting uninitialized dev ops pct",
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				ps.GetDevOpsPct()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized dev ops pct",
		},
		{
			name: "initialize dev ops pct to zero",
			setupFn: func(ps IProtocolFeeStore) {
				ps.InitializeDevOpsPct()
			},
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				uassert.True(t, ps.HasDevOpsPctStoreKey())
				uassert.Equal(t, int64(0), ps.GetDevOpsPct())
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ps := NewProtocolFeeStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ps)
		})
	}
}

func TestStoreSetAndGetAccuToGovStaker(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IProtocolFeeStore)
		testFn       func(*testing.T, IProtocolFeeStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "initialize and get accu to gov staker",
			setupFn: func(ps IProtocolFeeStore) {
				ps.InitializeAccuToGovStaker()
			},
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				uassert.True(t, ps.HasAccuToGovStakerStoreKey(), "should have accu to gov staker after initializing")
				retrieved := ps.GetAccuToGovStaker()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have accu to gov staker initially",
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				uassert.False(t, ps.HasAccuToGovStakerStoreKey(), "should not have accu to gov staker initially")
			},
		},
		{
			name: "panic when getting uninitialized accu to gov staker",
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				ps.GetAccuToGovStaker()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized accu to gov staker",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ps := NewProtocolFeeStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ps)
		})
	}
}

func TestStoreSetAndGetAccuToGovStakerItem(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
		amount    int64
	}{
		{
			name:      "token1 with 1000",
			tokenPath: "gno.land/r/demo/token1",
			amount:    1000,
		},
		{
			name:      "token2 with 2000",
			tokenPath: "gno.land/r/demo/token2",
			amount:    2000,
		},
		{
			name:      "token3 with zero",
			tokenPath: "gno.land/r/demo/token3",
			amount:    0,
		},
		{
			name:      "token4 with max value",
			tokenPath: "gno.land/r/demo/token4",
			amount:    9223372036854775807, // int64 max
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)

			ps := NewProtocolFeeStore(kvStore)

			err := ps.InitializeAccuToGovStaker()
			uassert.NoError(t, err)

			amount, exists := ps.GetAccuToGovStakerItem(tt.tokenPath)
			uassert.False(t, exists, "token should not exist initially")

			err = ps.SetAccuToGovStakerItem(tt.tokenPath, tt.amount)
			uassert.NoError(t, err)

			amount, exists = ps.GetAccuToGovStakerItem(tt.tokenPath)
			uassert.True(t, exists, "token should exist after setting")
			uassert.Equal(t, tt.amount, amount)
		})
	}
}

func TestStoreSetAndGetAccuToDevOps(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IProtocolFeeStore)
		testFn       func(*testing.T, IProtocolFeeStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "initialize and get accu to dev ops",
			setupFn: func(ps IProtocolFeeStore) {
				ps.InitializeAccuToDevOps()
			},
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				uassert.True(t, ps.HasAccuToDevOpsStoreKey(), "should have accu to dev ops after initializing")
				retrieved := ps.GetAccuToDevOps()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have accu to dev ops initially",
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				uassert.False(t, ps.HasAccuToDevOpsStoreKey(), "should not have accu to dev ops initially")
			},
		},
		{
			name: "panic when getting uninitialized accu to dev ops",
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				ps.GetAccuToDevOps()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized accu to dev ops",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ps := NewProtocolFeeStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ps)
		})
	}
}

func TestStoreSetAndGetAccuToDevOpsItem(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
		amount    int64
	}{
		{
			name:      "token1 with 500",
			tokenPath: "gno.land/r/demo/token1",
			amount:    500,
		},
		{
			name:      "token2 with 1500",
			tokenPath: "gno.land/r/demo/token2",
			amount:    1500,
		},
		{
			name:      "token3 with zero",
			tokenPath: "gno.land/r/demo/token3",
			amount:    0,
		},
		{
			name:      "token4 with negative",
			tokenPath: "gno.land/r/demo/token4",
			amount:    -100,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)

			ps := NewProtocolFeeStore(kvStore)

			err := ps.InitializeAccuToDevOps()
			uassert.NoError(t, err)

			amount, exists := ps.GetAccuToDevOpsItem(tt.tokenPath)
			uassert.False(t, exists, "token should not exist initially")

			err = ps.SetAccuToDevOpsItem(tt.tokenPath, tt.amount)
			uassert.NoError(t, err)

			amount, exists = ps.GetAccuToDevOpsItem(tt.tokenPath)
			uassert.True(t, exists, "token should exist after setting")
			uassert.Equal(t, tt.amount, amount)
		})
	}
}

func TestStoreSetAndGetTokenListWithAmounts(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IProtocolFeeStore)
		testFn       func(*testing.T, IProtocolFeeStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get token list with amounts successfully",
			setupFn: func(ps IProtocolFeeStore) {
				ps.InitializeTokenListWithAmount()
				tokenList := map[string]int64{
					"gno.land/r/demo/token1": 100,
					"gno.land/r/demo/token2": 200,
				}
				ps.SetTokenListWithAmounts(tokenList)
			},
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				uassert.True(t, ps.HasTokenListWithAmountsStoreKey(), "should have token list after initializing")
				retrieved := ps.GetTokenListWithAmounts()
				uassert.NotEqual(t, nil, retrieved)
				uassert.Equal(t, int64(100), retrieved["gno.land/r/demo/token1"])
				uassert.Equal(t, int64(200), retrieved["gno.land/r/demo/token2"])
			},
		},
		{
			name: "should not have token list initially",
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				uassert.False(t, ps.HasTokenListWithAmountsStoreKey(), "should not have token list initially")
			},
		},
		{
			name: "panic when getting uninitialized token list",
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				ps.GetTokenListWithAmounts()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized token list",
		},
		{
			name: "error when setting nil token list",
			testFn: func(t *testing.T, ps IProtocolFeeStore) {
				err := ps.SetTokenListWithAmounts(nil)
				uassert.ErrorContains(t, err, "tokenListWithAmounts is nil")
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ps := NewProtocolFeeStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ps)
		})
	}
}

func TestStoreSetAndGetTokenListWithAmountItem(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
		amount    int64
	}{
		{
			name:      "token1 with 300",
			tokenPath: "gno.land/r/demo/token1",
			amount:    300,
		},
		{
			name:      "token2 with 600",
			tokenPath: "gno.land/r/demo/token2",
			amount:    600,
		},
		{
			name:      "token3 with zero",
			tokenPath: "gno.land/r/demo/token3",
			amount:    0,
		},
		{
			name:      "token4 with large value",
			tokenPath: "gno.land/r/demo/token4",
			amount:    1000000000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)

			ps := NewProtocolFeeStore(kvStore)

			err := ps.InitializeTokenListWithAmount()
			uassert.NoError(t, err)

			amount, exists := ps.GetTokenListWithAmountItem(tt.tokenPath)
			uassert.False(t, exists, "token should not exist initially")

			err = ps.SetTokenListWithAmountItem(tt.tokenPath, tt.amount)
			uassert.NoError(t, err)

			amount, exists = ps.GetTokenListWithAmountItem(tt.tokenPath)
			uassert.True(t, exists, "token should exist after setting")
			uassert.Equal(t, tt.amount, amount)
		})
	}
}

func TestStoreMultipleSetAndGet(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func(IProtocolFeeStore)
		verifyFn func(*testing.T, IProtocolFeeStore)
	}{
		{
			name: "set and get all store values",
			setupFn: func(ps IProtocolFeeStore) {
				ps.InitializeDevOpsPct()
				ps.InitializeAccuToGovStaker()
				ps.InitializeAccuToDevOps()
				ps.InitializeTokenListWithAmount()

				ps.SetDevOpsPct(30)
				ps.SetAccuToGovStakerItem("token1", 1000)
				ps.SetAccuToDevOpsItem("token1", 500)
				ps.SetTokenListWithAmountItem("token1", 1500)
			},
			verifyFn: func(t *testing.T, ps IProtocolFeeStore) {
				uassert.True(t, ps.HasDevOpsPctStoreKey())
				uassert.True(t, ps.HasAccuToGovStakerStoreKey())
				uassert.True(t, ps.HasAccuToDevOpsStoreKey())
				uassert.True(t, ps.HasTokenListWithAmountsStoreKey())

				uassert.Equal(t, int64(30), ps.GetDevOpsPct())

				amount, _ := ps.GetAccuToGovStakerItem("token1")
				uassert.Equal(t, int64(1000), amount)

				amount, _ = ps.GetAccuToDevOpsItem("token1")
				uassert.Equal(t, int64(500), amount)

				amount, _ = ps.GetTokenListWithAmountItem("token1")
				uassert.Equal(t, int64(1500), amount)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ps := NewProtocolFeeStore(kvStore)

			tt.setupFn(ps)
			tt.verifyFn(t, ps)
		})
	}
}
