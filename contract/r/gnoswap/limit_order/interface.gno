package limit_order

// ILimitOrder defines the interface for limit order operations.
type ILimitOrder interface {
	// CreateOrder escrows input and records a new limit order.
	CreateOrder(_ int, rlm realm, poolPath string, inputMint address, outputMint address, makingAmount uint64, takingAmount uint64, slippageBps uint64, expiredAt int64) uint64

	// ExecuteOrder partially or fully fills an order with an exact input amount.
	// It returns the actual input consumed and Router-net output, in decimal form.
	ExecuteOrder(_ int, rlm realm, orderId uint64, amountIn uint64) (string, string)

	// CancelOrder cancels an active order and refunds its remaining input.
	CancelOrder(_ int, rlm realm, orderId uint64)

	// CleanupExpiredOrders expires at most maxCount active orders and refunds remaining input.
	CleanupExpiredOrders(_ int, rlm realm, maxCount uint64) uint64
}
