package limit_order

const (
	// Execution fee, snapshotted into each order at creation: 50 bps = 0.5%.
	EXECUTION_FEE_BPS uint64 = 50

	// MIN_ORDER_DEADLINE is the minimum order duration in seconds (5 minutes)
	MIN_ORDER_DEADLINE int64 = 300

	// MAX_ORDER_DEADLINE is the maximum order duration in seconds (30 days)
	MAX_ORDER_DEADLINE int64 = 2592000

	// BPS_DENOMINATOR for basis points calculations
	BPS_DENOMINATOR uint64 = 10000

	// Token transfers and cumulative order output fit signed int64.
	MAX_TOKEN_AMOUNT uint64 = 9223372036854775807
	MAX_QUERY_LIMIT  uint64 = 100
)
