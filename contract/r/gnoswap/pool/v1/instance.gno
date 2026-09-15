package pool

import (
	"gno.land/r/gnoswap/pool"
)

type poolV1 struct {
	store pool.IPoolStore
}

// NewPoolV1 constructs the version-one pool implementation around shared
// persistent storage.
//
// Parameters:
//   - store: pool-domain storage implementation used by the returned API.
//
// Returns:
//   - implementation: IPool backed by store.
func NewPoolV1(store pool.IPoolStore) pool.IPool {
	return &poolV1{
		store: store,
	}
}
