package router

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestStoreInitialization(t *testing.T) {
	resetTestState(t)

	uassert.NotEqual(t, nil, kvStore, "kvStore should be initialized")
	domainAddr := kvStore.GetDomainAddress()
	uassert.NotEqual(t, address(""), domainAddr, "domain address should not be empty")
}

func TestStoreSwapFee(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		rs := NewRouterStore(kvStore)

		uassert.False(t, rs.HasSwapFeeKey(), "should not have swap fee initially")

		err := rs.SetSwapFee(25)
		uassert.NoError(t, err)

		uassert.True(t, rs.HasSwapFeeKey(), "should have swap fee after setting")

		retrieved := rs.GetSwapFee()
		uassert.Equal(t, uint64(25), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		rs := NewRouterStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized swap fee")
		}()

		rs.GetSwapFee()
	})

	t.Run("ZeroValue", func(t *testing.T) {
		resetTestState(t)

		rs := NewRouterStore(kvStore)

		err := rs.SetSwapFee(0)
		uassert.NoError(t, err)

		uassert.True(t, rs.HasSwapFeeKey(), "should have swap fee key even with zero value")

		retrieved := rs.GetSwapFee()
		uassert.Equal(t, uint64(0), retrieved)
	})

	t.Run("MaxValue", func(t *testing.T) {
		resetTestState(t)

		rs := NewRouterStore(kvStore)

		maxUint64 := uint64(18446744073709551615) // 2^64 - 1

		err := rs.SetSwapFee(maxUint64)
		uassert.NoError(t, err)

		retrieved := rs.GetSwapFee()
		uassert.Equal(t, maxUint64, retrieved)
	})
}

func TestStoreUpdateSwapFee(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)

			rs := NewRouterStore(kvStore)

			err := rs.SetSwapFee(tt.initialFee)
			uassert.NoError(t, err)
			uassert.Equal(t, tt.initialFee, rs.GetSwapFee())

			err = rs.SetSwapFee(tt.updatedFee)
			uassert.NoError(t, err)
			uassert.Equal(t, tt.updatedFee, rs.GetSwapFee())
		})
	}
}

