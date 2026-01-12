package dca_order

import (
	"strconv"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/access"
)

const keySeparator = "*"

var (
	orders       *avl.Tree // orderID(string) -> *Order
	orderCounter int64

	orderGroups *avl.Tree // groupID -> *OrderGroup

	ordersByUser  *avl.Tree // userAddr -> *avl.Tree[orderID -> bool]
	ordersByGroup *avl.Tree // groupID -> *avl.Tree[orderID -> bool]

	processMissedIntervals bool

	admin address
)

func init() {
	orders = avl.NewTree()
	orderGroups = avl.NewTree()
	ordersByUser = avl.NewTree()
	ordersByGroup = avl.NewTree()

	orderCounter = 0

	// Set admin (should be updated via governance)
	admin = access.MustGetAddress(prbac.ROLE_ADMIN.String())

	processMissedIntervals = true
}

func makeGroupID(poolPath string, zeroForOne bool, interval int64) string {
	zeroForOneStr := "0"
	if zeroForOne {
		zeroForOneStr = "1"
	}

	intervalStr := strconv.FormatInt(interval, 10)

	return poolPath + keySeparator + zeroForOneStr + keySeparator + intervalStr
}

func nextOrderID(poolPath string, zeroForOne bool, interval int64) string {
	groupID := makeGroupID(poolPath, zeroForOne, interval)
	orderCounter++
	return groupID + keySeparator + makeOrderIDKey(orderCounter)
}

func makeOrderIDKey(orderID int64) string {
	return strconv.FormatInt(orderID, 10)
}

func makeTimestampKey(timestamp int64) string {
	return strconv.FormatInt(timestamp, 10)
}

func getOrder(orderID string) (*Order, bool) {
	value, exists := orders.Get(orderID)
	if !exists {
		return nil, false
	}
	return value.(*Order), true
}

func setOrder(order *Order) {
	orders.Set(order.ID, order)
}

func deleteOrder(orderID string) {
	orders.Remove(orderID)
}

func getOrderGroup(groupID string) (*OrderGroup, bool) {
	value, exists := orderGroups.Get(groupID)
	if !exists {
		return nil, false
	}

	return value.(*OrderGroup), true
}

func setOrderGroup(group *OrderGroup) {
	orderGroups.Set(group.ID, group)
}

func getOrCreateOrderGroup(poolPath string, zeroForOne bool, interval int64) *OrderGroup {
	id := makeGroupID(poolPath, zeroForOne, interval)
	group, exists := getOrderGroup(id)
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

func getOrderState(group *OrderGroup, orderID string) (*OrderState, bool) {
	value, exists := group.OrderStates.Get(orderID)
	if !exists {
		return nil, false
	}

	return value.(*OrderState), true
}

func setOrderState(group *OrderGroup, state *OrderState) {
	group.OrderStates.Set(state.OrderID, state)
}

func deleteOrderState(group *OrderGroup, orderID string) {
	group.OrderStates.Remove(orderID)
}

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

// removeOrderChangesForOrder removes all OrderChanges for a specific orderID
func removeOrderChangesForOrder(group *OrderGroup, orderID string) {
	keysToUpdate := make([]string, 0)

	// Collect all keys that have changes for this orderID
	group.ReservedOrderChanges.Iterate("", "", func(key string, value interface{}) bool {
		changes := value.([]*OrderChange)
		for _, change := range changes {
			if change.OrderID == orderID {
				keysToUpdate = append(keysToUpdate, key)
				break
			}
		}
		return false
	})

	// Update each key by removing the orderID's changes
	for _, key := range keysToUpdate {
		value, exists := group.ReservedOrderChanges.Get(key)
		if !exists {
			continue
		}

		changes := value.([]*OrderChange)
		newChanges := make([]*OrderChange, 0, len(changes))
		for _, change := range changes {
			if change.OrderID != orderID {
				newChanges = append(newChanges, change)
			}
		}

		if len(newChanges) == 0 {
			group.ReservedOrderChanges.Remove(key)
		} else {
			group.ReservedOrderChanges.Set(key, newChanges)
		}
	}
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

func addOrderToUserIndex(user address, orderID string) {
	userKey := user.String()

	var userOrders *avl.Tree

	value, exists := ordersByUser.Get(userKey)

	if exists {
		userOrders = value.(*avl.Tree)
	} else {
		userOrders = avl.NewTree()
	}

	userOrders.Set(orderID, true)
	ordersByUser.Set(userKey, userOrders)
}

func removeOrderFromUserIndex(user address, orderID string) {
	userKey := user.String()

	value, exists := ordersByUser.Get(userKey)
	if !exists {
		return
	}

	userOrders := value.(*avl.Tree)

	userOrders.Remove(orderID)
	ordersByUser.Set(userKey, userOrders)
}

func getOrderIDsByUser(user address) []string {
	userKey := user.String()

	value, exists := ordersByUser.Get(userKey)
	if !exists {
		return []string{}
	}

	userOrders := value.(*avl.Tree)
	ids := make([]string, 0, userOrders.Size())

	userOrders.Iterate("", "", func(id string, _ interface{}) bool {
		ids = append(ids, id)
		return false
	})

	return ids
}

func addOrderToGroupIndex(groupID string, orderID string) {
	var groupOrders *avl.Tree

	value, exists := ordersByGroup.Get(groupID)
	if exists {
		groupOrders = value.(*avl.Tree)
	} else {
		groupOrders = avl.NewTree()
	}

	groupOrders.Set(orderID, true)
	ordersByGroup.Set(groupID, groupOrders)
}

func removeOrderFromGroupIndex(groupID string, orderID string) {
	value, exists := ordersByGroup.Get(groupID)
	if !exists {
		return
	}

	groupOrders := value.(*avl.Tree)
	groupOrders.Remove(orderID)
	ordersByGroup.Set(groupID, groupOrders)
}

func getAdmin() address {
	return admin
}

func setAdmin(newAdmin address) {
	admin = newAdmin
}

func getProcessMissedIntervals() bool {
	return processMissedIntervals
}

func setProcessMissedIntervals(value bool) {
	processMissedIntervals = value
}
