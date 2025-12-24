package pool

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
)

func TestStoreInitialization(t *testing.T) {
	resetTestState(t)

	uassert.NotEqual(t, nil, kvStore, "kvStore should be initialized")
	domainAddr := kvStore.GetDomainAddress()
	uassert.NotEqual(t, address(""), domainAddr, "domain address should not be empty")
}

func TestStoreSetAndGetPools(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		uassert.False(t, ps.HasPools(), "should not have pools initially")

		pools := avl.NewTree()
		pools.Set("pool1", "data1")

		err := ps.SetPools(pools)
		uassert.NoError(t, err)

		uassert.True(t, ps.HasPools(), "should have pools after setting")

		retrievedPools := ps.GetPools()
		uassert.NotEqual(t, nil, retrievedPools)

		val, exists := retrievedPools.Get("pool1")
		uassert.True(t, exists, "pool1 should exist")
		uassert.Equal(t, "data1", val)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized pools")
		}()

		ps.GetPools()
	})

	t.Run("NilPanic", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when setting nil pools")
		}()

		ps.SetPools(nil)
	})
}

func TestStoreSetAndGetFeeAmountTickSpacing(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		uassert.False(t, ps.HasFeeAmountTickSpacing(), "should not have fee amount tick spacing initially")

		feeMap := map[uint32]int32{
			500:  10,
			3000: 60,
		}

		err := ps.SetFeeAmountTickSpacing(feeMap)
		uassert.NoError(t, err)

		uassert.True(t, ps.HasFeeAmountTickSpacing(), "should have fee amount tick spacing after setting")

		retrieved := ps.GetFeeAmountTickSpacing()
		uassert.NotEqual(t, nil, retrieved)
		uassert.Equal(t, int32(10), retrieved[500])
		uassert.Equal(t, int32(60), retrieved[3000])
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized fee amount tick spacing")
		}()

		ps.GetFeeAmountTickSpacing()
	})

	t.Run("NilPanic", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when setting nil fee amount tick spacing")
		}()

		ps.SetFeeAmountTickSpacing(nil)
	})
}

func TestStoreSetAndGetSlot0FeeProtocol(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		uassert.False(t, ps.HasSlot0FeeProtocol(), "should not have slot0 fee protocol initially")

		err := ps.SetSlot0FeeProtocol(10)
		uassert.NoError(t, err)

		uassert.True(t, ps.HasSlot0FeeProtocol(), "should have slot0 fee protocol after setting")

		retrieved := ps.GetSlot0FeeProtocol()
		uassert.Equal(t, uint8(10), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized slot0 fee protocol")
		}()

		ps.GetSlot0FeeProtocol()
	})
}

func TestStoreSetAndGetPoolCreationFee(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		uassert.False(t, ps.HasPoolCreationFee(), "should not have pool creation fee initially")

		err := ps.SetPoolCreationFee(1000000)
		uassert.NoError(t, err)

		uassert.True(t, ps.HasPoolCreationFee(), "should have pool creation fee after setting")

		retrieved := ps.GetPoolCreationFee()
		uassert.Equal(t, int64(1000000), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized pool creation fee")
		}()

		ps.GetPoolCreationFee()
	})
}

func TestStoreSetAndGetWithdrawalFeeBPS(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		uassert.False(t, ps.HasWithdrawalFeeBPS(), "should not have withdrawal fee BPS initially")

		err := ps.SetWithdrawalFeeBPS(50)
		uassert.NoError(t, err)

		uassert.True(t, ps.HasWithdrawalFeeBPS(), "should have withdrawal fee BPS after setting")

		retrieved := ps.GetWithdrawalFeeBPS()
		uassert.Equal(t, uint64(50), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized withdrawal fee BPS")
		}()

		ps.GetWithdrawalFeeBPS()
	})
}

func TestStoreSetAndGetSwapStartHook(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		uassert.False(t, ps.HasSwapStartHook(), "should not have swap start hook initially")

		hookFunc := func(cur realm, poolPath string, timestamp int64) {}

		err := ps.SetSwapStartHook(hookFunc)
		uassert.NoError(t, err)

		uassert.True(t, ps.HasSwapStartHook(), "should have swap start hook after setting")

		retrieved := ps.GetSwapStartHook()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized swap start hook")
		}()

		ps.GetSwapStartHook()
	})
}

func TestStoreSetAndGetSwapEndHook(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		uassert.False(t, ps.HasSwapEndHook(), "should not have swap end hook initially")

		hookFunc := func(cur realm, poolPath string) error { return nil }

		err := ps.SetSwapEndHook(hookFunc)
		uassert.NoError(t, err)

		uassert.True(t, ps.HasSwapEndHook(), "should have swap end hook after setting")

		retrieved := ps.GetSwapEndHook()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized swap end hook")
		}()

		ps.GetSwapEndHook()
	})
}

func TestStoreSetAndGetTickCrossHook(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		uassert.False(t, ps.HasTickCrossHook(), "should not have tick cross hook initially")

		hookFunc := func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {}

		err := ps.SetTickCrossHook(hookFunc)
		uassert.NoError(t, err)

		uassert.True(t, ps.HasTickCrossHook(), "should have tick cross hook after setting")

		retrieved := ps.GetTickCrossHook()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ps := NewPoolStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized tick cross hook")
		}()

		ps.GetTickCrossHook()
	})
}

func TestStoreMultipleSetAndGet(t *testing.T) {
	resetTestState(t)

	ps := NewPoolStore(kvStore)

	pools := avl.NewTree()
	pools.Set("pool1", "data1")
	err := ps.SetPools(pools)
	uassert.NoError(t, err)

	feeMap := map[uint32]int32{500: 10}
	err = ps.SetFeeAmountTickSpacing(feeMap)
	uassert.NoError(t, err)

	err = ps.SetSlot0FeeProtocol(15)
	uassert.NoError(t, err)

	err = ps.SetPoolCreationFee(5000000)
	uassert.NoError(t, err)

	err = ps.SetWithdrawalFeeBPS(100)
	uassert.NoError(t, err)

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
}

func TestStoreUpdateValues(t *testing.T) {
	tests := []struct {
		name      string
		setupFn   func(IPoolStore)
		updateFn  func(IPoolStore)
		verifyFn  func(*testing.T, IPoolStore)
	}{
		{
			name: "update pool creation fee twice",
			setupFn: func(ps IPoolStore) {
				ps.SetPoolCreationFee(1000)
			},
			updateFn: func(ps IPoolStore) {
				ps.SetPoolCreationFee(2000)
			},
			verifyFn: func(t *testing.T, ps IPoolStore) {
				uassert.Equal(t, int64(2000), ps.GetPoolCreationFee())
			},
		},
		{
			name: "update withdrawal fee BPS from 50 to 100",
			setupFn: func(ps IPoolStore) {
				ps.SetWithdrawalFeeBPS(50)
			},
			updateFn: func(ps IPoolStore) {
				ps.SetWithdrawalFeeBPS(100)
			},
			verifyFn: func(t *testing.T, ps IPoolStore) {
				uassert.Equal(t, uint64(100), ps.GetWithdrawalFeeBPS())
			},
		},
		{
			name: "update withdrawal fee BPS from 0 to 200",
			setupFn: func(ps IPoolStore) {
				ps.SetWithdrawalFeeBPS(0)
			},
			updateFn: func(ps IPoolStore) {
				ps.SetWithdrawalFeeBPS(200)
			},
			verifyFn: func(t *testing.T, ps IPoolStore) {
				uassert.Equal(t, uint64(200), ps.GetWithdrawalFeeBPS())
			},
		},
		{
			name: "update pool creation fee from max to min",
			setupFn: func(ps IPoolStore) {
				ps.SetPoolCreationFee(9223372036854775807) // int64 max
			},
			updateFn: func(ps IPoolStore) {
				ps.SetPoolCreationFee(0)
			},
			verifyFn: func(t *testing.T, ps IPoolStore) {
				uassert.Equal(t, int64(0), ps.GetPoolCreationFee())
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)

			ps := NewPoolStore(kvStore)

			tt.setupFn(ps)
			tt.updateFn(ps)
			tt.verifyFn(t, ps)
		})
	}
}

