package limit_order

const (
	// MIN_KEEPER_FEE_BPS is the minimum keeper fee in basis points (0.01% = 1 bps)
	MIN_KEEPER_FEE_BPS uint64 = 10 // 0.1%

	// MAX_KEEPER_FEE_BPS is the maximum keeper fee in basis points
	MAX_KEEPER_FEE_BPS uint64 = 500 // 5%

	// MIN_ORDER_DEADLINE is the minimum order duration in seconds (5 minutes)
	MIN_ORDER_DEADLINE int64 = 300

	// MAX_ORDER_DEADLINE is the maximum order duration in seconds (30 days)
	MAX_ORDER_DEADLINE int64 = 2592000

	// BPS_DENOMINATOR for basis points calculations
	BPS_DENOMINATOR uint64 = 10000
)
