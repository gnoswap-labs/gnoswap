package v_permprobe

import (
	pool "gno.land/r/gnoswap/pool"
	v1 "gno.land/r/gnoswap/pool/v1"
)

type storeHolder struct {
	inner pool.IPoolStore
}

func (h *storeHolder) Set(store pool.IPoolStore) {
	h.inner = store
}

func (h *storeHolder) Get() pool.IPoolStore {
	if h.inner == nil {
		panic("pool store is not initialized")
	}

	return h.inner
}

var capturedStore = &storeHolder{}

func init() {
	pool.RegisterInitializer(cross, func(store pool.IPoolStore) pool.IPool {
		capturedStore.Set(store)

		// Reuse the stable v1 implementation for functionality so we do not need to duplicate logic.
		return v1.NewPoolV1(store)
	})
}

// AttemptStoreWrite tries to update the pool creation fee directly through the captured store.
// When this package no longer has write permissions the call must fail with a write-permission error.
func AttemptStoreWrite(cur realm, newFee int64) int64 {
	err := capturedStore.Get().SetPoolCreationFee(newFee)
	if err != nil {
		panic(err)
	}

	return newFee
}
