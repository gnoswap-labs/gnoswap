package referral

import (
	"std"

	"gno.land/p/demo/avl"
)

// keeper implements the `ReferralKeeper` interface using an AVL tree for storage.
type keeper struct {
	store *avl.Tree
}

// check interface implementation at compile time
var _ ReferralKeeper = &keeper{}

// NewKeeper creates and returns a new instance of ReferralKeeper.
// The keeper is initialized with an empty AVL tree for storing referral relationships.
func NewKeeper() ReferralKeeper {
	return &keeper{
		store: avl.NewTree(),
	}
}

// register implements the `register` method of the `ReferralKeeper` interface.
// It sets a new referral relationship between the given address and referral address.
func (k *keeper) register(addr, refAddr std.Address) error {
	return k.setReferral(addr, refAddr, EventTypeRegister)
}

// update implements the `update` method of the `ReferralKeeper` interface.
// It updates the referral address for a given address.
func (k *keeper) update(addr, newRefAddr std.Address) error {
	return k.setReferral(addr, newRefAddr, EventTypeUpdate)
}

// setReferral handles the common logic for registering and updating referrals.
// It validates the addresses and caller, then stores the referral relationship.
//
// Note: The current implementation allows circular references, but since it only manages
// simple reference relationships, cycles are not a significant issue. However, when introducing
// a referral-based reward system in the future or adding business logic where cycles could cause problems,
// it will be necessary to implement validation checks.
//
// TODO: need to discuss what values to emit as event
func (k *keeper) setReferral(addr, refAddr std.Address, eventType string) error {
	if err := isValidCaller(std.PrevRealm().Addr()); err != nil {
		return err
	}

	if err := k.validateAddresses(addr, refAddr); err != nil {
		return err
	}

	if refAddr == zeroAddress {
		std.Emit(
			EventTypeRemove,
			"removedAddress", addr.String(),
		)
		return k.remove(addr)
	}

	k.store.Set(addr.String(), refAddr.String())
	std.Emit(
		eventType,
		"my_address", addr.String(),
		"ref_address", refAddr.String(),
	)

	return nil
}

// validateAddresses checks if the given addresses are valid for referral
func (k *keeper) validateAddresses(addr, refAddr std.Address) error {
	if !addr.IsValid() || (refAddr != zeroAddress && !refAddr.IsValid()) {
		return NewError(ErrInvalidAddress)
	}
	if addr == refAddr {
		return NewError(ErrSelfReferral)
	}
	return nil
}

// remove implements the `remove` method of the `ReferralKeeper` interface.
// It validates the caller and address before removing the referral relationship.
//
// TODO: need to discuss what values to emit as event
func (k *keeper) remove(target std.Address) error {
	if err := isValidCaller(std.PrevRealm().Addr()); err != nil {
		return err
	}

	if !target.IsValid() {
		return NewError(ErrInvalidAddress)
	}

	k.store.Remove(target.String())

	// TODO: update event
	std.Emit(
		EventTypeRemove,
		"removedAddress", target.String(),
	)

	return nil
}

// has implements the `has` method of the `ReferralKeeper` interface.
// It checks if a referral relationship exists for a given address.
func (k *keeper) has(addr std.Address) bool {
	_, exists := k.store.Get(addr.String())
	return exists
}

// get implements the `get` method of the `ReferralKeeper` interface.
// It retrieves the referral address for a given address.
func (k *keeper) get(addr std.Address) (std.Address, error) {
	if !addr.IsValid() {
		return zeroAddress, NewError(ErrInvalidAddress)
	}

	val, ok := k.store.Get(addr.String())
	if !ok {
		return zeroAddress, NewError(ErrNotFound)
	}

	refAddr, ok := val.(string)
	if !ok {
		return zeroAddress, NewError(ErrInvalidAddress)
	}

	return std.Address(refAddr), nil
}
