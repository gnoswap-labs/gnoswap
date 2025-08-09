package referral

import "std"

var zeroAddress = std.Address("")

// Event types for referral actions.
const (
	EventTypeRegister = "RegisterReferral"
	EventTypeUpdate   = "UpdateReferral"
	EventTypeRemove   = "RemoveReferral"
)

// ReferralKeeper defines the interface for managing referral relationships.
type ReferralKeeper interface {
	// register creates a new referral relationship between addresses.
	register(addr, refAddr std.Address) error

	// update modifies an existing referral address.
	update(addr, newRefAddr std.Address) error

	// remove deletes a referral relationship.
	remove(addr std.Address) error

	// has returns true if a referral exists for the given address.
	has(addr std.Address) bool

	// get retrieves the referral address for a given address.
	get(addr std.Address) (std.Address, error)

	// isEmpty returns true if no referrals exist in the system.
	isEmpty() bool
}
