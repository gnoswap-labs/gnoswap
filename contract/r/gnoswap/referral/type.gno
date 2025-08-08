package referral

import "std"

var zeroAddress = std.Address("")

// Event types for referral actions.
const (
	EventTypeRegister = "RegisterReferral"
	EventTypeUpdate   = "UpdateReferral"
	EventTypeRemove   = "RemoveReferral"
)

// ReferralKeeper manages referral relationships.
type ReferralKeeper interface {
	// register creates new referral relationship.
	register(addr, refAddr std.Address) error

	// update modifies referral address.
	update(addr, newRefAddr std.Address) error

	// remove deletes referral relationship.
	remove(addr std.Address) error

	// has checks if referral exists.
	has(addr std.Address) bool

	// get retrieves referral address.
	get(addr std.Address) (std.Address, error)

	// isEmpty checks if no referrals exist.
	isEmpty() bool
}
