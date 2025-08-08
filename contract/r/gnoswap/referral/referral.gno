package referral

import (
	"std"
)

// Referral manages referral relationships between addresses.
type Referral struct {
	keeper ReferralKeeper
}

// NewReferral creates new Referral instance.
func NewReferral() *Referral {
	if gReferralKeeper == nil {
		gReferralKeeper = NewKeeper()
	}
	return &Referral{
		keeper: gReferralKeeper,
	}
}

// Register creates new referral relationship.
func (r *Referral) Register(addr, refAddr std.Address) error {
	return r.keeper.register(addr, refAddr)
}

// Update modifies existing referral relationship.
func (r *Referral) Update(addr, newAddr std.Address) error {
	return r.keeper.update(addr, newAddr)
}

// Remove deletes referral relationship.
func (r *Referral) Remove(addr std.Address) error {
	return r.keeper.remove(addr)
}

// Has checks if referral exists for address.
func (r *Referral) Has(addr std.Address) bool {
	return r.keeper.has(addr)
}

// Get retrieves referral address.
func (r *Referral) Get(addr std.Address) (std.Address, error) {
	return r.keeper.get(addr)
}
