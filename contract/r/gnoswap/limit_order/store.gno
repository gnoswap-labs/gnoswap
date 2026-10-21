package limit_order

import (
	"errors"
	"strconv"
	"strings"

	"gno.land/p/gnoswap/store/v1"
	bptree "gno.land/p/nt/bptree/v0"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyOrders        StoreKey = "orders"        // All orders
	StoreKeyOrderNextID   StoreKey = "orderNextID"   // Next order ID
	StoreKeyOrdersByOwner StoreKey = "ordersByOwner" // Orders indexed by owner
	StoreKeyLocked        StoreKey = "locked"
)

type limitOrderStore struct {
	kvStore store.KVStore
}

func (s *limitOrderStore) HasOrdersStoreKey() bool {
	return s.kvStore.Has(StoreKeyOrders.String())
}

func (s *limitOrderStore) GetOrders() *bptree.BPTree {
	orders, err := s.kvStore.GetBPTree(StoreKeyOrders.String())
	if err != nil {
		panic(err)
	}

	return orders
}

func (s *limitOrderStore) SetOrders(_ int, rlm realm, orders *bptree.BPTree) error {
	return s.setValue(0, rlm, StoreKeyOrders.String(), orders)
}

func (s *limitOrderStore) HasOrderNextIDStoreKey() bool {
	return s.kvStore.Has(StoreKeyOrderNextID.String())
}

func (s *limitOrderStore) GetOrderNextID() uint64 {
	result, err := s.kvStore.Get(StoreKeyOrderNextID.String())
	if err != nil {
		panic(err)
	}

	nextID, ok := result.(uint64)
	if !ok {
		panic("failed to cast result to uint64")
	}

	return nextID
}

func (s *limitOrderStore) SetOrderNextID(_ int, rlm realm, nextID uint64) error {
	return s.setValue(0, rlm, StoreKeyOrderNextID.String(), nextID)
}

func (s *limitOrderStore) HasOrder(orderId uint64) bool {
	orders := s.GetOrders()
	return orders.Has(uint64ToString(orderId))
}

func (s *limitOrderStore) GetOrder(orderId uint64) (LimitOrder, bool) {
	result := s.GetOrders().Get(uint64ToString(orderId))
	if result == nil {
		return LimitOrder{}, false
	}

	order, ok := result.(LimitOrder)
	if !ok {
		panic("failed to cast result to LimitOrder")
	}

	return order, true
}

func (s *limitOrderStore) SetOrder(_ int, rlm realm, orderId uint64, order LimitOrder) error {
	if !s.HasOrdersStoreKey() {
		return ErrStoreNotInitialized
	}

	orders := s.GetOrders()
	orders.Set(uint64ToString(orderId), order)

	return s.setValue(0, rlm, StoreKeyOrders.String(), orders)
}

func (s *limitOrderStore) HasOrdersByOwnerStoreKey() bool {
	return s.kvStore.Has(StoreKeyOrdersByOwner.String())
}

func (s *limitOrderStore) GetOrdersByOwner() *bptree.BPTree {
	ordersByOwner, err := s.kvStore.GetBPTree(StoreKeyOrdersByOwner.String())
	if err != nil {
		panic(err)
	}

	return ordersByOwner
}

func (s *limitOrderStore) SetOrdersByOwner(_ int, rlm realm, ordersByOwner *bptree.BPTree) error {
	return s.setValue(0, rlm, StoreKeyOrdersByOwner.String(), ordersByOwner)
}

func (s *limitOrderStore) GetOwnerOrders(owner address) []uint64 {
	result := s.GetOrdersByOwner().Get(owner.String())
	if result == nil {
		return []uint64{}
	}

	orderIds, ok := result.([]uint64)
	if !ok {
		panic("failed to cast result to []uint64")
	}

	return orderIds
}

func (s *limitOrderStore) AddOwnerOrder(_ int, rlm realm, owner address, orderId uint64) error {
	ordersByOwner := s.GetOrdersByOwner()

	ownerKey := owner.String()
	var orderIds []uint64

	result := ordersByOwner.Get(ownerKey)
	if result != nil {
		var ok bool
		orderIds, ok = result.([]uint64)
		if !ok {
			panic("failed to cast result to []uint64")
		}
	}

	orderIds = append(orderIds, orderId)
	ordersByOwner.Set(ownerKey, orderIds)

	return s.setValue(0, rlm, StoreKeyOrdersByOwner.String(), ordersByOwner)
}

func (s *limitOrderStore) setValue(_ int, rlm realm, key string, value any) error {
	if !rlm.IsCurrent() {
		return errors.New(store.ErrSpoofedRealm)
	}
	if rlm.Address() != s.kvStore.GetDomainAddress() {
		return errors.New(store.ErrWritePermissionDenied)
	}
	return s.kvStore.Set(0, rlm, key, value)
}

// NewLimitOrderStore creates a new limit order store instance
func NewLimitOrderStore(kvStore store.KVStore) ILimitOrderStore {
	return &limitOrderStore{
		kvStore: kvStore,
	}
}

func uint64ToString(id uint64) string {
	value := strconv.FormatUint(id, 10)
	return strings.Repeat("0", 20-len(value)) + value
}

func (s *limitOrderStore) IsLocked() bool {
	value, err := s.kvStore.Get(StoreKeyLocked.String())
	if err != nil {
		panic(err)
	}
	return value.(bool)
}

func (s *limitOrderStore) SetLocked(_ int, rlm realm, locked bool) error {
	return s.setValue(0, rlm, StoreKeyLocked.String(), locked)
}

// ILimitOrderStore interface for storage operations
type ILimitOrderStore interface {
	IsLocked() bool
	SetLocked(_ int, rlm realm, locked bool) error
	HasOrdersStoreKey() bool
	GetOrders() *bptree.BPTree
	SetOrders(_ int, rlm realm, orders *bptree.BPTree) error

	HasOrderNextIDStoreKey() bool
	GetOrderNextID() uint64
	SetOrderNextID(_ int, rlm realm, nextID uint64) error

	HasOrder(orderId uint64) bool
	GetOrder(orderId uint64) (LimitOrder, bool)
	SetOrder(_ int, rlm realm, orderId uint64, order LimitOrder) error

	HasOrdersByOwnerStoreKey() bool
	GetOrdersByOwner() *bptree.BPTree
	SetOrdersByOwner(_ int, rlm realm, ordersByOwner *bptree.BPTree) error
	GetOwnerOrders(owner address) []uint64
	AddOwnerOrder(_ int, rlm realm, owner address, orderId uint64) error
}
