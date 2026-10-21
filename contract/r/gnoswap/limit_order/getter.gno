package limit_order

// GetOrder returns a detached scalar snapshot, including cumulative payouts.
func GetOrder(orderID uint64) (OrderView, bool) {
	order, ok := loStore.GetOrder(orderID)
	if !ok {
		return OrderView{}, false
	}
	return order.View(), true
}

// GetOrders returns orders in numeric ID order, strictly after cursor.
// A zero next cursor means this page reaches the end of the current index.
func GetOrders(cursor, limit uint64) ([]OrderView, uint64) {
	assertQueryLimit(limit)
	result := make([]OrderView, 0, int(limit))
	var next uint64
	loStore.GetOrders().Iterate(uint64ToString(cursor), "", func(key string, value any) bool {
		order := value.(LimitOrder)
		if order.ID() <= cursor {
			return false
		}
		if uint64(len(result)) == limit {
			next = result[len(result)-1].ID
			return true
		}
		result = append(result, order.View())
		return false
	})
	return result, next
}

// GetOrdersByOwner includes terminal orders for transaction history. Cursor is
// an order ID, not an array offset. Binary search avoids rescanning old pages.
func GetOrdersByOwner(owner address, cursor, limit uint64) ([]OrderView, uint64) {
	assertQueryLimit(limit)
	ids := loStore.GetOwnerOrders(owner)
	low, high := 0, len(ids)
	for low < high {
		mid := low + (high-low)/2
		if ids[mid] <= cursor {
			low = mid + 1
		} else {
			high = mid
		}
	}
	end := low + int(limit)
	if end > len(ids) {
		end = len(ids)
	}
	result := make([]OrderView, 0, end-low)
	for _, id := range ids[low:end] {
		order, ok := loStore.GetOrder(id)
		if !ok {
			panic(ErrOrderNotFound)
		}
		result = append(result, order.View())
	}
	var next uint64
	if end < len(ids) && len(result) > 0 {
		next = result[len(result)-1].ID
	}
	return result, next
}

func assertQueryLimit(limit uint64) {
	if limit == 0 || limit > MAX_QUERY_LIMIT {
		panic(ErrInvalidQueryLimit)
	}
}
