package router

import (
	"chain/runtime"
	"testing"

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
			verifyFn: func(cur realm, t *testing.T) {
				uassert.NotEqual(t, nil, kvStore, "kvStore should be initialized")
			},
		},
		{
			name: "domain address should not be empty",
			verifyFn: func(cur realm, t *testing.T) {
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
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/router"),
		},
		{
			name:                          "domain implementation has no permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/router/v2"),
			expectedErrorWithRead:         false,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                          "panic with no permission realm",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
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

			rs := NewRouterStore(kvStore)

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
			if !rs.HasSwapFeeKey() {
				rs.SetSwapFee(0, cur, 25)
			}

			testing.SetRealm(tc.callerRealm)
			if tc.expectedErrorWithRead {
				uassert.PanicsContains(t, cur, tc.expectedErrorMessageWithRead, func() {
					rs.GetSwapFee()
				})
			} else {
				rs.GetSwapFee()
			}

			err := rs.SetSwapFee(0, cur, 50)
			if tc.expectedErrorWithWrite {
				uassert.ErrorContains(t, err, tc.expectedErrorMessageWithWrite)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestStoreSwapFee(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, rs IRouterStore)
		testFn       func(cur realm, t *testing.T, rs IRouterStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get swap fee successfully",
			testFn: func(cur realm, t *testing.T, rs IRouterStore) {
				uassert.False(t, rs.HasSwapFeeKey(), "should not have swap fee initially")

				err := rs.SetSwapFee(0, cur, 25)
				uassert.NoError(t, err)

				uassert.True(t, rs.HasSwapFeeKey(), "should have swap fee after setting")

				retrieved := rs.GetSwapFee()
				uassert.Equal(t, uint64(25), retrieved)
			},
		},
		{
			name: "panic when getting uninitialized swap fee",
			testFn: func(cur realm, t *testing.T, rs IRouterStore) {
				rs.GetSwapFee()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized swap fee",
		},
		{
			name: "set and get zero value swap fee",
			testFn: func(cur realm, t *testing.T, rs IRouterStore) {
				err := rs.SetSwapFee(0, cur, 0)
				uassert.NoError(t, err)

				uassert.True(t, rs.HasSwapFeeKey(), "should have swap fee key even with zero value")

				retrieved := rs.GetSwapFee()
				uassert.Equal(t, uint64(0), retrieved)
			},
		},
		{
			name: "set and get max uint64 swap fee",
			testFn: func(cur realm, t *testing.T, rs IRouterStore) {
				maxUint64 := uint64(18446744073709551615) // 2^64 - 1

				err := rs.SetSwapFee(0, cur, maxUint64)
				uassert.NoError(t, err)

				retrieved := rs.GetSwapFee()
				uassert.Equal(t, maxUint64, retrieved)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			rs := NewRouterStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, rs)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, rs)
		})
	}
}

func TestStoreUpdateSwapFee(cur realm, t *testing.T) {
	tests := []struct {
		name       string
		initialFee uint64
		updatedFee uint64
	}{
		{
			name:       "update from 25 to 50",
			initialFee: 25,
			updatedFee: 50,
		},
		{
			name:       "update from 50 to 100",
			initialFee: 50,
			updatedFee: 100,
		},
		{
			name:       "update from 100 to 0",
			initialFee: 100,
			updatedFee: 0,
		},
		{
			name:       "update from 0 to max uint64",
			initialFee: 0,
			updatedFee: 18446744073709551615, // uint64 max
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)

			rs := NewRouterStore(kvStore)

			err := rs.SetSwapFee(0, cur, tt.initialFee)
			uassert.NoError(t, err)
			uassert.Equal(t, tt.initialFee, rs.GetSwapFee())

			err = rs.SetSwapFee(0, cur, tt.updatedFee)
			uassert.NoError(t, err)
			uassert.Equal(t, tt.updatedFee, rs.GetSwapFee())
		})
	}
}
