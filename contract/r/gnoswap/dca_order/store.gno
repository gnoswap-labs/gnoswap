package dca_order

import (
	"std"
	"strconv"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

var (
	// Orders storage
	orders       *avl.Tree // orderID(string) -> *Order
	orderCounter int64

	// Order groups storage
	orderGroups *avl.Tree // groupKey -> *OrderGroup

	// Indices
	ordersByUser  *avl.Tree // userAddr -> *avl.Tree[orderID -> struct{}]
	ordersByGroup *avl.Tree // groupKey -> *avl.Tree[orderID -> struct{}]

	// Admin address
	admin std.Address
)

func init() {
	orders = avl.NewTree()
	orderGroups = avl.NewTree()
	ordersByUser = avl.NewTree()
	ordersByGroup = avl.NewTree()

	orderCounter = 0

	// Set admin (should be updated via governance)
	admin = std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5")
}

// ============================================
// Key Generation
// ============================================

func makeGroupKey(poolPath string, zeroForOne bool, interval int64) string {
	zeroForOneStr := "0"
	if zeroForOne {
		zeroForOneStr = "1"
	}
	return ufmt.Sprintf("%s:%s:%d", poolPath, zeroForOneStr, interval)
}

func makeOrderIDKey(orderID int64) string {
	return strconv.FormatInt(orderID, 10)
}

func makeTimestampKey(timestamp int64) string {
	return strconv.FormatInt(timestamp, 10)
}

// ============================================
// Order Storage
// ============================================

func getOrder(orderID int64) (*Order, bool) {
	key := makeOrderIDKey(orderID)
	value, exists := orders.Get(key)
	if !exists {
		return nil, false
	}
	return value.(*Order), true
}

func setOrder(order *Order) {
	key := makeOrderIDKey(order.ID)
	orders.Set(key, order)
}

func deleteOrder(orderID int64) {
	key := makeOrderIDKey(orderID)
	orders.Remove(key)
}

func nextOrderID() int64 {
	orderCounter++
	return orderCounter
}

// ============================================
// OrderGroup Storage
// ============================================

func getOrderGroup(groupKey string) (*OrderGroup, bool) {
	value, exists := orderGroups.Get(groupKey)
	if !exists {
		return nil, false
	}
	return value.(*OrderGroup), true
}

func setOrderGroup(group *OrderGroup) {
	orderGroups.Set(group.Key, group)
}

func getOrCreateOrderGroup(poolPath string, zeroForOne bool, interval int64) *OrderGroup {
	key := makeGroupKey(poolPath, zeroForOne, interval)
	group, exists := getOrderGroup(key)
	if !exists {
		group = NewOrderGroup(poolPath, zeroForOne, interval)
		setOrderGroup(group)
	}
	return group
}

func iterateOrderGroups(fn func(key string, group *OrderGroup) bool) {
	orderGroups.Iterate("", "", func(key string, value interface{}) bool {
		return fn(key, value.(*OrderGroup))
	})
}

// ============================================
// OrderState within Group
// ============================================

func getOrderState(group *OrderGroup, orderID int64) (*OrderState, bool) {
	key := makeOrderIDKey(orderID)
	value, exists := group.OrderStates.Get(key)
	if !exists {
		return nil, false
	}
	return value.(*OrderState), true
}

func setOrderState(group *OrderGroup, state *OrderState) {
	key := makeOrderIDKey(state.OrderID)
	group.OrderStates.Set(key, state)
}

func deleteOrderState(group *OrderGroup, orderID int64) {
	key := makeOrderIDKey(orderID)
	group.OrderStates.Remove(key)
}

// ============================================
// OrderChange (Reserved Changes)
// ============================================

func addOrderChange(group *OrderGroup, timestamp int64, change *OrderChange) {
	key := makeTimestampKey(timestamp)

	var changes []*OrderChange
	value, exists := group.ReservedOrderChanges.Get(key)
	if exists {
		changes = value.([]*OrderChange)
	} else {
		changes = make([]*OrderChange, 0)
	}

	changes = append(changes, change)
	group.ReservedOrderChanges.Set(key, changes)
}

func getOrderChanges(group *OrderGroup, timestamp int64) []*OrderChange {
	key := makeTimestampKey(timestamp)
	value, exists := group.ReservedOrderChanges.Get(key)
	if !exists {
		return nil
	}
	return value.([]*OrderChange)
}

func removeOrderChanges(group *OrderGroup, timestamp int64) {
	key := makeTimestampKey(timestamp)
	group.ReservedOrderChanges.Remove(key)
}

// iterateOrderChangesUntil iterates through order changes up to a given timestamp
func iterateOrderChangesUntil(group *OrderGroup, untilTimestamp int64, fn func(timestamp int64, changes []*OrderChange) bool) {
	group.ReservedOrderChanges.Iterate("", "", func(key string, value interface{}) bool {
		timestamp, _ := strconv.ParseInt(key, 10, 64)
		if timestamp > untilTimestamp {
			return true // stop iteration
		}
		return fn(timestamp, value.([]*OrderChange))
	})
}

// ============================================
// Index Management
// ============================================

func addOrderToUserIndex(user std.Address, orderID int64) {
	userKey := user.String()
	orderKey := makeOrderIDKey(orderID)

	var userOrders *avl.Tree
	value, exists := ordersByUser.Get(userKey)
	if exists {
		userOrders = value.(*avl.Tree)
	} else {
		userOrders = avl.NewTree()
	}

	userOrders.Set(orderKey, struct{}{})
	ordersByUser.Set(userKey, userOrders)
}

func removeOrderFromUserIndex(user std.Address, orderID int64) {
	userKey := user.String()
	orderKey := makeOrderIDKey(orderID)

	value, exists := ordersByUser.Get(userKey)
	if !exists {
		return
	}

	userOrders := value.(*avl.Tree)
	userOrders.Remove(orderKey)
	ordersByUser.Set(userKey, userOrders)
}

func getOrderIDsByUser(user std.Address) []int64 {
	userKey := user.String()
	value, exists := ordersByUser.Get(userKey)
	if !exists {
		return []int64{}
	}

	userOrders := value.(*avl.Tree)
	ids := make([]int64, 0, userOrders.Size())

	userOrders.Iterate("", "", func(key string, _ interface{}) bool {
		id, _ := strconv.ParseInt(key, 10, 64)
		ids = append(ids, id)
		return false
	})

	return ids
}

func addOrderToGroupIndex(groupKey string, orderID int64) {
	orderKey := makeOrderIDKey(orderID)

	var groupOrders *avl.Tree
	value, exists := ordersByGroup.Get(groupKey)
	if exists {
		groupOrders = value.(*avl.Tree)
	} else {
		groupOrders = avl.NewTree()
	}

	groupOrders.Set(orderKey, struct{}{})
	ordersByGroup.Set(groupKey, groupOrders)
}

func removeOrderFromGroupIndex(groupKey string, orderID int64) {
	orderKey := makeOrderIDKey(orderID)

	value, exists := ordersByGroup.Get(groupKey)
	if !exists {
		return
	}

	groupOrders := value.(*avl.Tree)
	groupOrders.Remove(orderKey)
	ordersByGroup.Set(groupKey, groupOrders)
}

// ============================================
// Admin
// ============================================

func getAdmin() std.Address {
	return admin
}

func setAdmin(newAdmin std.Address) {
	admin = newAdmin
}
