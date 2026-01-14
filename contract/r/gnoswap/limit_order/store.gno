package limit_order

import (
	"strconv"

	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/avl"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyOrders      StoreKey = "orders"      // All orders
	StoreKeyOrderNextID StoreKey = "orderNextID" // Next order ID
	StoreKeyOrdersByOwner StoreKey = "ordersByOwner" // Orders indexed by owner
)

type limitOrderStore struct {
	kvStore store.KVStore
}

func (s *limitOrderStore) HasOrdersStoreKey() bool {
	return s.kvStore.Has(StoreKeyOrders.String())
}

func (s *limitOrderStore) GetOrders() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyOrders.String())
	if err != nil {
		panic(err)
	}

	orders, ok := result.(*avl.Tree)
	if !ok {
		panic("failed to cast result to *avl.Tree")
	}

	return orders
}

func (s *limitOrderStore) SetOrders(orders *avl.Tree) error {
	return s.kvStore.Set(StoreKeyOrders.String(), orders)
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

func (s *limitOrderStore) SetOrderNextID(nextID uint64) error {
	return s.kvStore.Set(StoreKeyOrderNextID.String(), nextID)
}

func (s *limitOrderStore) HasOrder(orderId uint64) bool {
	orders := s.GetOrders()
	return orders.Has(uint64ToString(orderId))
}

func (s *limitOrderStore) GetOrder(orderId uint64) (LimitOrder, bool) {
	orders := s.GetOrders()

	result, ok := orders.Get(uint64ToString(orderId))
	if !ok {
		return LimitOrder{}, false
	}

	order, ok := result.(LimitOrder)
	if !ok {
		panic("failed to cast result to LimitOrder")
	}

	return order, true
}

func (s *limitOrderStore) SetOrder(orderId uint64, order LimitOrder) error {
	if !s.HasOrdersStoreKey() {
		return ErrStoreNotInitialized
	}

	orders := s.GetOrders()
	orders.Set(uint64ToString(orderId), order)

	return s.kvStore.Set(StoreKeyOrders.String(), orders)
}

func (s *limitOrderStore) RemoveOrder(orderId uint64) error {
	if !s.HasOrdersStoreKey() {
		return ErrStoreNotInitialized
	}

	orders := s.GetOrders()
	orders.Remove(uint64ToString(orderId))

	return s.kvStore.Set(StoreKeyOrders.String(), orders)
}

func (s *limitOrderStore) HasOrdersByOwnerStoreKey() bool {
	return s.kvStore.Has(StoreKeyOrdersByOwner.String())
}

func (s *limitOrderStore) GetOrdersByOwner() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyOrdersByOwner.String())
	if err != nil {
		panic(err)
	}

	ordersByOwner, ok := result.(*avl.Tree)
	if !ok {
		panic("failed to cast result to *avl.Tree")
	}

	return ordersByOwner
}

func (s *limitOrderStore) SetOrdersByOwner(ordersByOwner *avl.Tree) error {
	return s.kvStore.Set(StoreKeyOrdersByOwner.String(), ordersByOwner)
}

func (s *limitOrderStore) GetOwnerOrders(owner address) []uint64 {
	ordersByOwner := s.GetOrdersByOwner()

	result, ok := ordersByOwner.Get(owner.String())
	if !ok {
		return []uint64{}
	}

	orderIds, ok := result.([]uint64)
	if !ok {
		panic("failed to cast result to []uint64")
	}

	return orderIds
}

func (s *limitOrderStore) AddOwnerOrder(owner address, orderId uint64) error {
	ordersByOwner := s.GetOrdersByOwner()

	ownerKey := owner.String()
	var orderIds []uint64

	result, ok := ordersByOwner.Get(ownerKey)
	if ok {
		orderIds, ok = result.([]uint64)
		if !ok {
			panic("failed to cast result to []uint64")
		}
	}

	orderIds = append(orderIds, orderId)
	ordersByOwner.Set(ownerKey, orderIds)

	return s.kvStore.Set(StoreKeyOrdersByOwner.String(), ordersByOwner)
}

func (s *limitOrderStore) RemoveOwnerOrder(owner address, orderId uint64) error {
	ordersByOwner := s.GetOrdersByOwner()

	ownerKey := owner.String()
	result, ok := ordersByOwner.Get(ownerKey)
	if !ok {
		return nil
	}

	orderIds, ok := result.([]uint64)
	if !ok {
		panic("failed to cast result to []uint64")
	}

	// Find and remove orderId
	newOrderIds := make([]uint64, 0, len(orderIds))
	for _, id := range orderIds {
		if id != orderId {
			newOrderIds = append(newOrderIds, id)
		}
	}

	if len(newOrderIds) == 0 {
		ordersByOwner.Remove(ownerKey)
	} else {
		ordersByOwner.Set(ownerKey, newOrderIds)
	}

	return s.kvStore.Set(StoreKeyOrdersByOwner.String(), ordersByOwner)
}

// NewLimitOrderStore creates a new limit order store instance
func NewLimitOrderStore(kvStore store.KVStore) ILimitOrderStore {
	return &limitOrderStore{
		kvStore: kvStore,
	}
}

func uint64ToString(id uint64) string {
	return strconv.FormatUint(id, 10)
}

// ILimitOrderStore interface for storage operations
type ILimitOrderStore interface {
	HasOrdersStoreKey() bool
	GetOrders() *avl.Tree
	SetOrders(orders *avl.Tree) error

	HasOrderNextIDStoreKey() bool
	GetOrderNextID() uint64
	SetOrderNextID(nextID uint64) error

	HasOrder(orderId uint64) bool
	GetOrder(orderId uint64) (LimitOrder, bool)
	SetOrder(orderId uint64, order LimitOrder) error
	RemoveOrder(orderId uint64) error

	HasOrdersByOwnerStoreKey() bool
	GetOrdersByOwner() *avl.Tree
	SetOrdersByOwner(ordersByOwner *avl.Tree) error
	GetOwnerOrders(owner address) []uint64
	AddOwnerOrder(owner address, orderId uint64) error
	RemoveOwnerOrder(owner address, orderId uint64) error
}
