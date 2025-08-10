package referral

import (
	"std"
)

// Referral manages referral relationships between addresses.
type Referral struct {
	keeper ReferralKeeper
}

// NewReferral creates a new Referral instance.
func NewReferral() *Referral {
	if gReferralKeeper == nil {
		gReferralKeeper = NewKeeper()
	}
	return &Referral{
		keeper: gReferralKeeper,
	}
}

// Register creates a new referral relationship.
//
// Parameters:
//   - addr: address to register
//   - refAddr: referral address
func (r *Referral) Register(addr, refAddr std.Address) error {
	return r.keeper.register(addr, refAddr)
}

// Update modifies an existing referral relationship.
//
// Parameters:
//   - addr: address to update
//   - newAddr: new referral address
func (r *Referral) Update(addr, newAddr std.Address) error {
	return r.keeper.update(addr, newAddr)
}

// Remove deletes a referral relationship.
//
// Parameters:
//   - addr: address to remove
func (r *Referral) Remove(addr std.Address) error {
	return r.keeper.remove(addr)
}

// Has returns true if a referral exists for the given address.
func (r *Referral) Has(addr std.Address) bool {
	return r.keeper.has(addr)
}

// Get retrieves the referral address for the given address.
func (r *Referral) Get(addr std.Address) (std.Address, error) {
	return r.keeper.get(addr)
}
