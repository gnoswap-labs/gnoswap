package dca_order

import (
	"time"

	"chain/runtime"

	u256 "gno.land/p/gnoswap/uint256"
)

func GetOrder(orderID string) *Order {
	order, exists := getOrder(orderID)
	if !exists {
		return nil
	}
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

func GetOrdersByUser(user address) []*Order {
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

func GetOrderGroup(groupKey string) *OrderGroup {
	group, exists := getOrderGroup(groupKey)
	if !exists {
		return nil
	}
	return group
}

func GetOrderGroupByParams(poolPath string, zeroForOne bool, interval int64) *OrderGroup {
	key := makeGroupID(poolPath, zeroForOne, interval)
	return GetOrderGroup(key)
}

func GetOrderState(orderID string) *OrderState {
	order, exists := getOrder(orderID)
	if !exists {
		return nil
	}

	groupKey := makeGroupID(order.PoolPath, order.ZeroForOne, order.Interval)
	group, exists := getOrderGroup(groupKey)
	if !exists {
		return nil
	}

	state, exists := getOrderState(group, orderID)
	if !exists {
		return nil
	}

	var finalAccumulator *u256.Uint
	if state.FinalAccumulatorX128 != nil {
		finalAccumulator = state.FinalAccumulatorX128.Clone()
	}
	return &OrderState{
		OrderID:              state.OrderID,
		DepositedAmount:      state.DepositedAmount,
		ClaimedAmount:        state.ClaimedAmount,
		AccumulatedOut:       state.AccumulatedOut,
		OutAmountDebtX128:    state.OutAmountDebtX128.Clone(),
		FinalAccumulatorX128: finalAccumulator,
		ClaimedTimestamp:     state.ClaimedTimestamp,
		LastUpdateTimestamp:  state.LastUpdateTimestamp,
	}
}

func GetClaimable(orderID string) int64 {
	order, exists := getOrder(orderID)
	if !exists {
		return 0
	}

	groupKey := makeGroupID(order.PoolPath, order.ZeroForOne, order.Interval)
	group, exists := getOrderGroup(groupKey)
	if !exists {
		return 0
	}

	state, exists := getOrderState(group, orderID)
	if !exists {
		return 0
	}

	return calculateClaimable(group, state, order)
}

func GetTotalClaimableByUser(user address) map[string]int64 {
	orderIDs := getOrderIDsByUser(user)
	claimableByToken := make(map[string]int64)

	for _, orderID := range orderIDs {
		order, exists := getOrder(orderID)
		if !exists {
			continue
		}

		groupKey := makeGroupID(order.PoolPath, order.ZeroForOne, order.Interval)
		group, exists := getOrderGroup(groupKey)
		if !exists {
			continue
		}

		state, exists := getOrderState(group, orderID)
		if !exists {
			continue
		}

		claimable := calculateClaimable(group, state, order)
		if claimable > 0 {
			prev, _ := claimableByToken[order.TokenOut]
			claimableByToken[order.TokenOut] = prev + claimable
		}
	}

	return claimableByToken
}

func GetAdmin() address {
	return getAdmin()
}

func GetDCAOrderAddr() address {
	return runtime.CurrentRealm().Address()
}

func GetExecutableGroups() []string {
	now := time.Now().Unix()
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

func GetProcessMissedIntervals() bool {
	return getProcessMissedIntervals()
}
