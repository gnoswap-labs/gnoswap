package staker2

// Delegation constants
const (
	MIN_DELEGATION_AMOUNT      = 1_000_000        // 1 GNS minimum delegation
	MIN_DELEGATION_PER_ADDRESS = 10_000_000       // 10 GNS minimum per address (DoS protection)
	MIN_DELEGATION_INCREMENT   = 1_000_000        // 1 GNS minimum increment
	MAX_DELEGATIONS_PER_USER   = 100              // Maximum delegations per user (DoS protection)
	LOCK_PERIOD                = 7 * 24 * 60 * 60 // 7 days in seconds
)

// Epoch constants
const (
	DEFAULT_EPOCH_DURATION = 7200 // ~24 hours worth of blocks
)
