package dca_order

import (
	"errors"

	"gno.land/p/gnoswap/store/v1"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// StoreKey defines the keys used for DCA order data in the KV store.
type StoreKey string

// String returns the textual store key.
func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyOrders          StoreKey = "orders"          // EncodeUint64(orderID) -> *Order
	StoreKeyOrdersByOwner   StoreKey = "ordersByOwner"   // owner + "/" + EncodeUint64(orderID) -> orderID
	StoreKeyGroups          StoreKey = "groups"          // groupID -> *Group
	StoreKeyScheduledGroups StoreKey = "scheduledGroups" // EncodeUint64(nextExecutionAt) + groupID -> groupID, groups with rate > 0
	StoreKeyNextOrderID     StoreKey = "nextOrderID"     // uint64
	StoreKeyConfig          StoreKey = "config"          // *Config
	StoreKeyPendingFees     StoreKey = "pendingFees"     // tokenPath -> int64 prepaid fees not yet withdrawn
	StoreKeyExecuting       StoreKey = "executing"       // true while ExecuteGroup is inside its router swap

	// extKeyPrefix namespaces values added by later implementations. The proxy
	// cannot change after deployment, so new state must go through
	// GetExtension/SetExtension instead of new typed accessors.
	extKeyPrefix = "ext:"
)

type dcaOrderStore struct {
	kvStore store.KVStore
}

// NewDCAOrderStore wraps the domain KV store.
func NewDCAOrderStore(kvStore store.KVStore) IDCAOrderStore {
	return &dcaOrderStore{kvStore: kvStore}
}

func (s *dcaOrderStore) getTree(key StoreKey) *bptree.BPTree {
	tree, err := s.kvStore.GetBPTree(key.String())
	if err != nil {
		panic(err)
	}

	if tree == nil {
		panic(ufmt.Sprintf("%s is nil", key.String()))
	}

	return tree
}

func (s *dcaOrderStore) setTree(_ int, rlm realm, key StoreKey, tree *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if tree == nil {
		return ufmt.Errorf("%s is nil", key.String())
	}

	return s.kvStore.Set(0, rlm, key.String(), tree)
}

func (s *dcaOrderStore) HasOrders() bool { return s.kvStore.Has(StoreKeyOrders.String()) }

func (s *dcaOrderStore) GetOrders() *bptree.BPTree { return s.getTree(StoreKeyOrders) }

func (s *dcaOrderStore) SetOrders(_ int, rlm realm, orders *bptree.BPTree) error {
	return s.setTree(0, rlm, StoreKeyOrders, orders)
}

func (s *dcaOrderStore) HasOrdersByOwner() bool {
	return s.kvStore.Has(StoreKeyOrdersByOwner.String())
}

func (s *dcaOrderStore) GetOrdersByOwner() *bptree.BPTree { return s.getTree(StoreKeyOrdersByOwner) }

func (s *dcaOrderStore) SetOrdersByOwner(_ int, rlm realm, ordersByOwner *bptree.BPTree) error {
	return s.setTree(0, rlm, StoreKeyOrdersByOwner, ordersByOwner)
}

func (s *dcaOrderStore) HasGroups() bool { return s.kvStore.Has(StoreKeyGroups.String()) }

func (s *dcaOrderStore) GetGroups() *bptree.BPTree { return s.getTree(StoreKeyGroups) }

func (s *dcaOrderStore) SetGroups(_ int, rlm realm, groups *bptree.BPTree) error {
	return s.setTree(0, rlm, StoreKeyGroups, groups)
}

func (s *dcaOrderStore) HasScheduledGroups() bool {
	return s.kvStore.Has(StoreKeyScheduledGroups.String())
}

func (s *dcaOrderStore) GetScheduledGroups() *bptree.BPTree {
	return s.getTree(StoreKeyScheduledGroups)
}

func (s *dcaOrderStore) SetScheduledGroups(_ int, rlm realm, groups *bptree.BPTree) error {
	return s.setTree(0, rlm, StoreKeyScheduledGroups, groups)
}

func (s *dcaOrderStore) HasPendingFees() bool { return s.kvStore.Has(StoreKeyPendingFees.String()) }

func (s *dcaOrderStore) GetPendingFees() *bptree.BPTree { return s.getTree(StoreKeyPendingFees) }

func (s *dcaOrderStore) SetPendingFees(_ int, rlm realm, fees *bptree.BPTree) error {
	return s.setTree(0, rlm, StoreKeyPendingFees, fees)
}

func (s *dcaOrderStore) HasNextOrderID() bool { return s.kvStore.Has(StoreKeyNextOrderID.String()) }

func (s *dcaOrderStore) GetNextOrderID() uint64 {
	id, err := s.kvStore.GetUint64(StoreKeyNextOrderID.String())
	if err != nil {
		panic(err)
	}

	return id
}

func (s *dcaOrderStore) SetNextOrderID(_ int, rlm realm, id uint64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyNextOrderID.String(), id)
}

func (s *dcaOrderStore) HasConfig() bool { return s.kvStore.Has(StoreKeyConfig.String()) }

func (s *dcaOrderStore) GetConfig() *Config {
	result, err := s.kvStore.Get(StoreKeyConfig.String())
	if err != nil {
		panic(err)
	}

	config, ok := result.(*Config)
	if !ok || config == nil {
		panic(ufmt.Sprintf("failed to cast config: %T", result))
	}

	return config
}

func (s *dcaOrderStore) SetConfig(_ int, rlm realm, config *Config) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if config == nil {
		return errors.New("config is nil")
	}

	return s.kvStore.Set(0, rlm, StoreKeyConfig.String(), config)
}

// IsExecuting reports whether a group execution is inside its swap. The flag
// lives in the proxy store so every implementation version and UpgradeImpl
// observe the same re-entrancy guard.
func (s *dcaOrderStore) IsExecuting() bool {
	if !s.kvStore.Has(StoreKeyExecuting.String()) {
		return false
	}

	executing, err := s.kvStore.GetBool(StoreKeyExecuting.String())
	if err != nil {
		panic(err)
	}

	return executing
}

func (s *dcaOrderStore) SetExecuting(_ int, rlm realm, executing bool) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyExecuting.String(), executing)
}

func (s *dcaOrderStore) HasExtension(key string) bool {
	return s.kvStore.Has(extKeyPrefix + key)
}

func (s *dcaOrderStore) GetExtension(key string) (any, error) {
	return s.kvStore.Get(extKeyPrefix + key)
}

func (s *dcaOrderStore) SetExtension(_ int, rlm realm, key string, value any) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, extKeyPrefix+key, value)
}

func (s *dcaOrderStore) DeleteExtension(_ int, rlm realm, key string) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Delete(0, rlm, extKeyPrefix+key)
}
