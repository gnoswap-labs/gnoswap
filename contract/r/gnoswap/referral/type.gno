package referral

var zeroAddress = address("")

// Event types for referral actions.
const (
	EventTypeRegister = "RegisterReferral"
	EventTypeUpdate   = "UpdateReferral"
	EventTypeRemove   = "RemoveReferral"
)

// ReferralKeeper defines the interface for managing referral relationships.
type ReferralKeeper interface {
	// register creates a new referral relationship between addresses.
	register(addr, refAddr address) error

	// update modifies an existing referral address.
	update(addr, newRefAddr address) error

	// remove deletes a referral relationship.
	remove(addr address) error

	// has returns true if a referral exists for the given address.
	has(addr address) bool

	// get retrieves the referral address for a given address.
	get(addr address) (address, error)

	// isEmpty returns true if no referrals exist in the system.
	isEmpty() bool
}
