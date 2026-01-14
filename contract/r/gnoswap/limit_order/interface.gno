package limit_order

// ILimitOrder defines the interface for limit order operations
type ILimitOrder interface {
	// CreateOrder creates a new limit order
	CreateOrder(
		poolPath string,
		inputMint address,
		outputMint address,
		makingAmount uint64,
		takingAmount uint64,
		slippageBps uint64,
		feeBps uint64,
		expiredAt int64,
		caller address,
	) uint64

	// ExecuteOrder executes a limit order when conditions are met
	ExecuteOrder(orderId uint64, caller address)

	// CancelOrder cancels an active limit order
	CancelOrder(orderId uint64, caller address)

	// CleanupExpiredOrders cleans up expired orders
	CleanupExpiredOrders(maxCount uint64) uint64
}
