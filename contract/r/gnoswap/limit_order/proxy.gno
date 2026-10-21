package limit_order

// CreateOrder escrows input and records a new limit order.
func CreateOrder(
	cur realm,
	poolPath string,
	inputMint address,
	outputMint address,
	makingAmount uint64,
	takingAmount uint64,
	slippageBps uint64,
	expiredAt int64,
) uint64 {
	return getImplementation().CreateOrder(
		0,
		cur,
		poolPath,
		inputMint,
		outputMint,
		makingAmount,
		takingAmount,
		slippageBps,
		expiredAt,
	)
}

// ExecuteOrder partially or fully fills an order with an exact input amount.
// It returns the actual input consumed and Router-net output, in decimal form.
func ExecuteOrder(cur realm, orderId uint64, amountIn uint64) (string, string) {
	return getImplementation().ExecuteOrder(0, cur, orderId, amountIn)
}

// CancelOrder cancels an active order and refunds its remaining input.
func CancelOrder(cur realm, orderId uint64) {
	getImplementation().CancelOrder(0, cur, orderId)
}

// CleanupExpiredOrders expires at most maxCount active orders and refunds remaining input.
func CleanupExpiredOrders(cur realm, maxCount uint64) uint64 {
	return getImplementation().CleanupExpiredOrders(0, cur, maxCount)
}
