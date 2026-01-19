package referral

import "chain/runtime"

var (
	zeroAddress = address("")
	// selfAddress is cached at package initialization to ensure consistent comparison.
	selfAddress address
)

func init() {
	selfAddress = runtime.CurrentRealm().Address()
}

// contractAddress returns the address of the referral contract.
// This is used as a sentinel value for removing referrals.
func contractAddress() address {
	return selfAddress
}

// isRemovalRequest checks if the given address indicates a removal request.
// Removal is indicated by passing the contract's own address as the referral.
func isRemovalRequest(refAddr address) bool {
	return refAddr == selfAddress
}

// ReferralKeeper defines the interface for managing referral relationships.
type ReferralKeeper interface {
	// register creates or updates a referral relationship between addresses.
	// Setting refAddr to the contract's own address removes the referral.
	register(addr, refAddr address) error

	// has returns true if a referral exists for the given address.
	has(addr address) bool

	// get retrieves the referral address for a given address.
	get(addr address) (address, error)

	// isEmpty returns true if no referrals exist in the system.
	isEmpty() bool

	// getLastOpTimestamp returns the last operation timestamp for an address.
	getLastOpTimestamp(addr address) (int64, error)
}
