package limit_order

// CreateOrder creates a new limit order
func CreateOrder(
	cur realm,
	poolPath string,
	inputMint address,
	outputMint address,
	makingAmount uint64,
	takingAmount uint64,
	slippageBps uint64,
	feeBps uint64,
	expiredAt int64,
	caller address,
) uint64 {
	return getImplementation().CreateOrder(
		poolPath,
		inputMint,
		outputMint,
		makingAmount,
		takingAmount,
		slippageBps,
		feeBps,
		expiredAt,
		caller,
	)
}

// ExecuteOrder executes a limit order when conditions are met
func ExecuteOrder(cur realm, orderId uint64, caller address) {
	getImplementation().ExecuteOrder(orderId, caller)
}

// CancelOrder cancels an active limit order
func CancelOrder(cur realm, orderId uint64, caller address) {
	getImplementation().CancelOrder(orderId, caller)
}

// CleanupExpiredOrders cleans up expired orders
func CleanupExpiredOrders(cur realm, maxCount uint64) uint64 {
	return getImplementation().CleanupExpiredOrders(maxCount)
}
