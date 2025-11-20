package pool_initializer

import (
	pool "gno.land/r/gnoswap/pool"
	v1 "gno.land/r/gnoswap/pool/v1"
)

// TryRegister attempts to register a pool implementation from a package
// outside the authorized domain path. The version manager should reject
// this call with a domain-path violation error.
func TryRegister(cur realm) {
	pool.RegisterInitializer(cross, func(store pool.IPoolStore) pool.IPool {
		return v1.NewPoolV1(store)
	})
}
