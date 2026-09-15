package referral

const zeroAddress = address("")

// selfAddress is cached at package initialization to ensure consistent comparison.
var selfAddress address

// init caches the referral realm's own address for removal-sentinel checks.
//
// Parameters:
//   - cur: initialization realm supplied by the Gno runtime
func init(cur realm) {
	selfAddress = cur.Address()
}

// contractAddress returns the address of the referral contract.
// This is used as a sentinel value for removing referrals.
//
// Returns:
//   - address: referral contract address used as the removal sentinel
func contractAddress() address {
	return selfAddress
}

// isRemovalRequest checks if the given address indicates a removal request.
// Removal is indicated by passing the contract's own address as the referral.
//
// Parameters:
//   - refAddr: referral address to compare with the contract's own address
//
// Returns:
//   - removal: true when refAddr is the contract-address removal sentinel
func isRemovalRequest(refAddr address) bool {
	return refAddr == selfAddress
}

// ReferralKeeper defines the interface for managing referral relationships.
type ReferralKeeper interface {
	// register creates, updates, or removes a referral relationship between addresses.
	// Setting refAddr to the contract's own address removes the referral.
	//
	// Parameters:
	//   - addr: address whose referral relationship is created, updated, or removed
	//   - refAddr: new referral address, or the contract address to request removal
	//
	// Returns:
	//   - referral: stored referral address; the zero address when removing a referral
	//   - error: nil after the relationship is applied; validation, rate-limit, or
	//     storage error otherwise
	register(addr, refAddr address) (address, error)

	// has returns true if a referral exists for the given address.
	//
	// Parameters:
	//   - addr: address whose referral relationship is queried
	//
	// Returns:
	//   - exists: true when addr has a stored referral relationship
	has(addr address) bool

	// get retrieves the referral address for a given address.
	//
	// Parameters:
	//   - addr: address whose referral address is queried
	//
	// Returns:
	//   - referral: stored referral address
	//   - error: nil when a referral exists; invalid-address, not-found, or
	//     invalid-stored-value error otherwise
	get(addr address) (address, error)

	// isEmpty returns true if no referrals exist in the system.
	//
	// Returns:
	//   - empty: true when the referral store contains no relationships; false otherwise
	isEmpty() bool

	// getLastOpTimestamp returns the last non-removal registration or update timestamp.
	//
	// Parameters:
	//   - addr: address whose last non-removal operation timestamp is queried
	//
	// Returns:
	//   - timestamp: Unix timestamp of the last non-removal registration or update
	//   - error: nil when a timestamp exists; invalid-address, not-found, or
	//     invalid-timestamp error otherwise
	getLastOpTimestamp(addr address) (int64, error)
}
