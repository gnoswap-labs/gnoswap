package limit_order

// ILimitOrder defines the interface for limit order operations
type ILimitOrder interface {
	// CreateOrder creates a new limit order
	CreateOrder(_ int, rlm realm, poolPath string, inputMint address, outputMint address, makingAmount uint64, takingAmount uint64, slippageBps uint64, feeBps uint64, expiredAt int64, caller address) uint64

	// ExecuteOrder executes a limit order when conditions are met
	ExecuteOrder(_ int, rlm realm, orderId uint64, caller address)

	// CancelOrder cancels an active limit order
	CancelOrder(_ int, rlm realm, orderId uint64, caller address)

	// CleanupExpiredOrders cleans up expired orders
	CleanupExpiredOrders(_ int, rlm realm, maxCount uint64) uint64
}
