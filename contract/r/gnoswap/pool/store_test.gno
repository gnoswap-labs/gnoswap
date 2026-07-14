package pool

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
		verifyFn func(cur realm, t *testing.T)
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
			tt.verifyFn(cur, t)
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
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
		},
		{
			name:                          "domain implementation has no permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/pool/v2"),
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
			name:                          "position has read permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/position"),
			expectedErrorWithRead:         false,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                          "staker has read permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/staker"),
			expectedErrorWithRead:         false,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "",
			expectedErrorMessageWithWrite: "write permission denied",
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

			ps := NewPoolStore(kvStore)

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool"))
			if !ps.HasPoolCreationFee() {
				ps.SetPoolCreationFee(0, cur, 100)
			}

			testing.SetRealm(tc.callerRealm)
			if tc.expectedErrorWithRead {
				uassert.PanicsContains(t, cur, tc.expectedErrorMessageWithRead, func() {
					ps.GetPoolCreationFee()
				})
			} else {
				ps.GetPoolCreationFee()
			}

			err := ps.SetPoolCreationFee(0, cur, 200)
			if tc.expectedErrorWithWrite {
				uassert.ErrorContains(t, err, tc.expectedErrorMessageWithWrite)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestStoreSetAndGetPools(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ps IPoolStore)
		testFn       func(cur realm, t *testing.T, ps IPoolStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pools successfully",
			setupFn: func(cur realm, ps IPoolStore) {
				pools := bptree.NewBPTreeN(32)
				pools.Set("pool1", "data1")
				ps.SetPools(0, cur, pools)
			},
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.True(t, ps.HasPools(), "should have pools after setting")
				retrievedPools := ps.GetPools()
				uassert.NotEqual(t, nil, retrievedPools)
				val, exists := retrievedPools.Get("pool1")
				uassert.True(t, exists, "pool1 should exist")
				uassert.Equal(t, "data1", val)
			},
		},
		{
			name: "should not have pools initially",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.False(t, ps.HasPools(), "should not have pools initially")
			},
		},
		{
			name: "panic when getting uninitialized pools",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				ps.GetPools()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pools",
		},
		{
			name: "panic when setting nil pools",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				ps.SetPools(0, cur, nil)
			},
			shouldPanic:  true,
			panicMessage: "should panic when setting nil pools",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ps := NewPoolStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ps)
		})
	}
}

func TestStoreSetAndGetFeeAmountTickSpacing(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ps IPoolStore)
		testFn       func(cur realm, t *testing.T, ps IPoolStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get fee amount tick spacing successfully",
			setupFn: func(cur realm, ps IPoolStore) {
				feeMap := map[uint32]int32{
					500:  10,
					3000: 60,
				}
				ps.SetFeeAmountTickSpacing(0, cur, feeMap)
			},
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.True(t, ps.HasFeeAmountTickSpacing(), "should have fee amount tick spacing after setting")
				retrieved := ps.GetFeeAmountTickSpacing()
				uassert.NotEqual(t, nil, retrieved)
				uassert.Equal(t, int32(10), retrieved[500])
				uassert.Equal(t, int32(60), retrieved[3000])
			},
		},
		{
			name: "should not have fee amount tick spacing initially",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.False(t, ps.HasFeeAmountTickSpacing(), "should not have fee amount tick spacing initially")
			},
		},
		{
			name: "panic when getting uninitialized fee amount tick spacing",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				ps.GetFeeAmountTickSpacing()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized fee amount tick spacing",
		},
		{
			name: "panic when setting nil fee amount tick spacing",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				ps.SetFeeAmountTickSpacing(0, cur, nil)
			},
			shouldPanic:  true,
			panicMessage: "should panic when setting nil fee amount tick spacing",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ps := NewPoolStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ps)
		})
	}
}

func TestStoreSetAndGetSlot0FeeProtocol(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ps IPoolStore)
		testFn       func(cur realm, t *testing.T, ps IPoolStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get slot0 fee protocol successfully",
			setupFn: func(cur realm, ps IPoolStore) {
				ps.SetSlot0FeeProtocol(0, cur, 10)
			},
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.True(t, ps.HasSlot0FeeProtocol(), "should have slot0 fee protocol after setting")
				retrieved := ps.GetSlot0FeeProtocol()
				uassert.Equal(t, uint8(10), retrieved)
			},
		},
		{
			name: "should not have slot0 fee protocol initially",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.False(t, ps.HasSlot0FeeProtocol(), "should not have slot0 fee protocol initially")
			},
		},
		{
			name: "panic when getting uninitialized slot0 fee protocol",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				ps.GetSlot0FeeProtocol()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized slot0 fee protocol",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ps := NewPoolStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ps)
		})
	}
}

func TestStoreSetAndGetPoolCreationFee(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ps IPoolStore)
		testFn       func(cur realm, t *testing.T, ps IPoolStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get pool creation fee successfully",
			setupFn: func(cur realm, ps IPoolStore) {
				ps.SetPoolCreationFee(0, cur, 1000000)
			},
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.True(t, ps.HasPoolCreationFee(), "should have pool creation fee after setting")
				retrieved := ps.GetPoolCreationFee()
				uassert.Equal(t, int64(1000000), retrieved)
			},
		},
		{
			name: "should not have pool creation fee initially",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.False(t, ps.HasPoolCreationFee(), "should not have pool creation fee initially")
			},
		},
		{
			name: "panic when getting uninitialized pool creation fee",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				ps.GetPoolCreationFee()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized pool creation fee",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ps := NewPoolStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ps)
		})
	}
}

func TestStoreSetAndGetWithdrawalFeeBPS(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ps IPoolStore)
		testFn       func(cur realm, t *testing.T, ps IPoolStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get withdrawal fee BPS successfully",
			setupFn: func(cur realm, ps IPoolStore) {
				ps.SetWithdrawalFeeBPS(0, cur, 50)
			},
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.True(t, ps.HasWithdrawalFeeBPS(), "should have withdrawal fee BPS after setting")
				retrieved := ps.GetWithdrawalFeeBPS()
				uassert.Equal(t, uint64(50), retrieved)
			},
		},
		{
			name: "should not have withdrawal fee BPS initially",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.False(t, ps.HasWithdrawalFeeBPS(), "should not have withdrawal fee BPS initially")
			},
		},
		{
			name: "panic when getting uninitialized withdrawal fee BPS",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				ps.GetWithdrawalFeeBPS()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized withdrawal fee BPS",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ps := NewPoolStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ps)
		})
	}
}

func TestStoreSetAndGetUnlocked(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ps IPoolStore)
		testFn       func(cur realm, t *testing.T, ps IPoolStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get unlocked successfully",
			setupFn: func(cur realm, ps IPoolStore) {
				ps.SetUnlocked(0, cur, true)
			},
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.True(t, ps.HasUnlocked(), "should have unlocked after setting")
				uassert.True(t, ps.GetUnlocked(), "unlocked should be true")
			},
		},
		{
			name: "set locked successfully",
			setupFn: func(cur realm, ps IPoolStore) {
				ps.SetUnlocked(0, cur, false)
			},
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.True(t, ps.HasUnlocked(), "should have unlocked after setting")
				uassert.False(t, ps.GetUnlocked(), "unlocked should be false")
			},
		},
		{
			name: "should not have unlocked initially",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.False(t, ps.HasUnlocked(), "should not have unlocked initially")
			},
		},
		{
			name: "panic when getting uninitialized unlocked",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				ps.GetUnlocked()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized unlocked",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ps := NewPoolStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ps)
		})
	}
}

func TestStoreSetAndGetSwapStartHook(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ps IPoolStore)
		testFn       func(cur realm, t *testing.T, ps IPoolStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get swap start hook successfully",
			setupFn: func(cur realm, ps IPoolStore) {
				hookFunc := func(cur realm, poolPath string, timestamp int64) {}
				ps.SetSwapStartHook(0, cur, hookFunc)
			},
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.True(t, ps.HasSwapStartHook(), "should have swap start hook after setting")
				retrieved := ps.GetSwapStartHook()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have swap start hook initially",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.False(t, ps.HasSwapStartHook(), "should not have swap start hook initially")
			},
		},
		{
			name: "panic when getting uninitialized swap start hook",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				ps.GetSwapStartHook()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized swap start hook",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ps := NewPoolStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ps)
		})
	}
}

func TestStoreSetAndGetSwapEndHook(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ps IPoolStore)
		testFn       func(cur realm, t *testing.T, ps IPoolStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get swap end hook successfully",
			setupFn: func(cur realm, ps IPoolStore) {
				hookFunc := func(cur realm, poolPath string) error { return nil }
				ps.SetSwapEndHook(0, cur, hookFunc)
			},
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.True(t, ps.HasSwapEndHook(), "should have swap end hook after setting")
				retrieved := ps.GetSwapEndHook()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have swap end hook initially",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.False(t, ps.HasSwapEndHook(), "should not have swap end hook initially")
			},
		},
		{
			name: "panic when getting uninitialized swap end hook",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				ps.GetSwapEndHook()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized swap end hook",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ps := NewPoolStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ps)
		})
	}
}

func TestStoreSetAndGetTickCrossHook(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(cur realm, ps IPoolStore)
		testFn       func(cur realm, t *testing.T, ps IPoolStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get tick cross hook successfully",
			setupFn: func(cur realm, ps IPoolStore) {
				hookFunc := func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {}
				ps.SetTickCrossHook(0, cur, hookFunc)
			},
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.True(t, ps.HasTickCrossHook(), "should have tick cross hook after setting")
				retrieved := ps.GetTickCrossHook()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have tick cross hook initially",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.False(t, ps.HasTickCrossHook(), "should not have tick cross hook initially")
			},
		},
		{
			name: "panic when getting uninitialized tick cross hook",
			testFn: func(cur realm, t *testing.T, ps IPoolStore) {
				ps.GetTickCrossHook()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized tick cross hook",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ps := NewPoolStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(cur, ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(cur, t, ps)
		})
	}
}

func TestStoreMultipleSetAndGet(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func(cur realm, ps IPoolStore)
		verifyFn func(cur realm, t *testing.T, ps IPoolStore)
	}{
		{
			name: "set and get all store values",
			setupFn: func(cur realm, ps IPoolStore) {
				pools := bptree.NewBPTreeN(32)
				pools.Set("pool1", "data1")
				ps.SetPools(0, cur, pools)

				feeMap := map[uint32]int32{500: 10}
				ps.SetFeeAmountTickSpacing(0, cur, feeMap)

				ps.SetSlot0FeeProtocol(0, cur, 15)
				ps.SetPoolCreationFee(0, cur, 5000000)
				ps.SetWithdrawalFeeBPS(0, cur, 100)
			},
			verifyFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.True(t, ps.HasPools())
				uassert.True(t, ps.HasFeeAmountTickSpacing())
				uassert.True(t, ps.HasSlot0FeeProtocol())
				uassert.True(t, ps.HasPoolCreationFee())
				uassert.True(t, ps.HasWithdrawalFeeBPS())

				retrievedPools := ps.GetPools()
				val, _ := retrievedPools.Get("pool1")
				uassert.Equal(t, "data1", val)

				retrievedFeeMap := ps.GetFeeAmountTickSpacing()
				uassert.Equal(t, int32(10), retrievedFeeMap[500])

				uassert.Equal(t, uint8(15), ps.GetSlot0FeeProtocol())
				uassert.Equal(t, int64(5000000), ps.GetPoolCreationFee())
				uassert.Equal(t, uint64(100), ps.GetWithdrawalFeeBPS())
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			ps := NewPoolStore(kvStore)

			tt.setupFn(cur, ps)
			tt.verifyFn(cur, t, ps)
		})
	}
}

func TestStoreUpdateValues(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func(cur realm, ps IPoolStore)
		updateFn func(cur realm, ps IPoolStore)
		verifyFn func(cur realm, t *testing.T, ps IPoolStore)
	}{
		{
			name: "update pool creation fee twice",
			setupFn: func(cur realm, ps IPoolStore) {
				ps.SetPoolCreationFee(0, cur, 1000)
			},
			updateFn: func(cur realm, ps IPoolStore) {
				ps.SetPoolCreationFee(0, cur, 2000)
			},
			verifyFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.Equal(t, int64(2000), ps.GetPoolCreationFee())
			},
		},
		{
			name: "update withdrawal fee BPS from 50 to 100",
			setupFn: func(cur realm, ps IPoolStore) {
				ps.SetWithdrawalFeeBPS(0, cur, 50)
			},
			updateFn: func(cur realm, ps IPoolStore) {
				ps.SetWithdrawalFeeBPS(0, cur, 100)
			},
			verifyFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.Equal(t, uint64(100), ps.GetWithdrawalFeeBPS())
			},
		},
		{
			name: "update withdrawal fee BPS from 0 to 200",
			setupFn: func(cur realm, ps IPoolStore) {
				ps.SetWithdrawalFeeBPS(0, cur, 0)
			},
			updateFn: func(cur realm, ps IPoolStore) {
				ps.SetWithdrawalFeeBPS(0, cur, 200)
			},
			verifyFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.Equal(t, uint64(200), ps.GetWithdrawalFeeBPS())
			},
		},
		{
			name: "update pool creation fee from max to min",
			setupFn: func(cur realm, ps IPoolStore) {
				ps.SetPoolCreationFee(0, cur, 9223372036854775807) // int64 max
			},
			updateFn: func(cur realm, ps IPoolStore) {
				ps.SetPoolCreationFee(0, cur, 0)
			},
			verifyFn: func(cur realm, t *testing.T, ps IPoolStore) {
				uassert.Equal(t, int64(0), ps.GetPoolCreationFee())
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)

			ps := NewPoolStore(kvStore)

			tt.setupFn(cur, ps)
			tt.updateFn(cur, ps)
			tt.verifyFn(cur, t, ps)
		})
	}
}
