package dca_order

import (
	"std"
)

// GetOrder returns an order by ID
func GetOrder(orderID int64) *Order {
	order, exists := getOrder(orderID)
	if !exists {
		return nil
	}
	// Return a copy to prevent external modification
	return &Order{
		ID:                 order.ID,
		Owner:              order.Owner,
		PoolPath:           order.PoolPath,
		TokenIn:            order.TokenIn,
		TokenOut:           order.TokenOut,
		ZeroForOne:         order.ZeroForOne,
		AmountPerExecution: order.AmountPerExecution,
		TotalExecutions:    order.TotalExecutions,
		Interval:           order.Interval,
		CreatedAt:          order.CreatedAt,
	}
}

// GetOrdersByUser returns all orders for a user
func GetOrdersByUser(user std.Address) []*Order {
	orderIDs := getOrderIDsByUser(user)
	orders := make([]*Order, 0, len(orderIDs))

	for _, id := range orderIDs {
		order := GetOrder(id)
		if order != nil {
			orders = append(orders, order)
		}
	}

	return orders
}

// GetOrderGroup returns an order group by key
func GetOrderGroup(groupKey string) *OrderGroup {
	group, exists := getOrderGroup(groupKey)
	if !exists {
		return nil
	}
	return group
}

// GetOrderGroupByParams returns an order group by parameters
func GetOrderGroupByParams(poolPath string, zeroForOne bool, interval int64) *OrderGroup {
	key := makeGroupKey(poolPath, zeroForOne, interval)
	return GetOrderGroup(key)
}

// GetOrderState returns the state of an order
func GetOrderState(orderID int64) *OrderState {
	order, exists := getOrder(orderID)
	if !exists {
		return nil
	}

	groupKey := makeGroupKey(order.PoolPath, order.ZeroForOne, order.Interval)
	group, exists := getOrderGroup(groupKey)
	if !exists {
		return nil
	}

	state, exists := getOrderState(group, orderID)
	if !exists {
		return nil
	}

	// Return a copy
	return &OrderState{
		OrderID:             state.OrderID,
		DepositedAmount:     state.DepositedAmount,
		ClaimedAmount:       state.ClaimedAmount,
		AccumulatedOut:      state.AccumulatedOut,
		OutAmountDebtX128:   state.OutAmountDebtX128.Clone(),
		ClaimedTimestamp:    state.ClaimedTimestamp,
		LastUpdateTimestamp: state.LastUpdateTimestamp,
	}
}

// GetClaimable returns the claimable output amount for an order
func GetClaimable(orderID int64) int64 {
	order, exists := getOrder(orderID)
	if !exists {
		return 0
	}

	groupKey := makeGroupKey(order.PoolPath, order.ZeroForOne, order.Interval)
	group, exists := getOrderGroup(groupKey)
	if !exists {
		return 0
	}

	state, exists := getOrderState(group, orderID)
	if !exists {
		return 0
	}

	return calculateClaimable(group, state)
}

// GetTotalClaimableByUser returns total claimable amounts for a user by token
func GetTotalClaimableByUser(user std.Address) map[string]int64 {
	orderIDs := getOrderIDsByUser(user)
	claimableByToken := make(map[string]int64)

	for _, orderID := range orderIDs {
		order, exists := getOrder(orderID)
		if !exists {
			continue
		}

		groupKey := makeGroupKey(order.PoolPath, order.ZeroForOne, order.Interval)
		group, exists := getOrderGroup(groupKey)
		if !exists {
			continue
		}

		state, exists := getOrderState(group, orderID)
		if !exists {
			continue
		}

		claimable := calculateClaimable(group, state)
		if claimable > 0 {
			prev, _ := claimableByToken[order.TokenOut]
			claimableByToken[order.TokenOut] = prev + claimable
		}
	}

	return claimableByToken
}

// GetAdmin returns the admin address
func GetAdmin() std.Address {
	return getAdmin()
}

// GetExecutableGroups returns group keys that are ready for execution
func GetExecutableGroups() []string {
	var now int64 = 0 // TODO: get current time
	keys := make([]string, 0)

	iterateOrderGroups(func(key string, group *OrderGroup) bool {
		if group.DepositedAmount == 0 {
			return false
		}

		if group.AccumulatedTimestamp > 0 && now < group.AccumulatedTimestamp+group.Interval {
			return false
		}

		keys = append(keys, key)
		return false
	})

	return keys
}
