package pool

// Storage keys for KVStore
const (
	// Global storage keys
	KEY_FEE_AMOUNT_TICK_SPACING = "feeAmountTickSpacing" // AVL tree: fee -> tickSpacing
	KEY_POOLS                   = "pools"                // AVL tree: poolPath -> *Pool
	KEY_SLOT0_FEE_PROTOCOL      = "slot0FeeProtocol"     // uint8
	KEY_POOL_CREATION_FEE       = "poolCreationFee"      // int64
	KEY_WITHDRAWAL_FEE          = "withdrawalFee"        // uint64
)

// Pool-specific key prefixes
const (
	PREFIX_POOL = "pool:"
)

// Helper functions to generate pool-specific keys
func makePoolKey(poolPath string) string {
	return PREFIX_POOL + poolPath
}
