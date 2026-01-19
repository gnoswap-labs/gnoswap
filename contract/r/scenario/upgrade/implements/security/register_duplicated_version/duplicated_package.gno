package v_dup_probe

import (
	pool "gno.land/r/gnoswap/pool"
	v1 "gno.land/r/gnoswap/pool/v1"
)

// RegisterVersion registers a simple proxy implementation that wraps the v1
// logic. Calling this once should succeed, but a second call from the same
// package path must panic with a duplicate-initializer error.
func RegisterVersion(cur realm) {
	pool.RegisterInitializer(cross, func(store pool.IPoolStore) pool.IPool {
		return v1.NewPoolV1(store)
	})
}
