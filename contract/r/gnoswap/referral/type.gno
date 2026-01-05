package referral

var zeroAddress = address("")

// Event types for referral actions.
const (
	EventTypeRegister = "RegisterReferral"
)

// ReferralKeeper defines the interface for managing referral relationships.
type ReferralKeeper interface {
	// register creates or updates a referral relationship between addresses.
	// Setting refAddr to zero address removes the referral.
	register(addr, refAddr address) error

	// has returns true if a referral exists for the given address.
	has(addr address) bool

	// get retrieves the referral address for a given address.
	get(addr address) (address, error)

	// isEmpty returns true if no referrals exist in the system.
	isEmpty() bool
}
