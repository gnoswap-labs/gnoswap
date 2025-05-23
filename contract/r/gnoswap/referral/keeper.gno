package referral

import (
	"std"
	"time"

	"gno.land/p/demo/avl"
)

const (
	// MinTimeBetweenUpdates represents minimum duration between operations
	MinTimeBetweenUpdates int64 = 24 * 60 * 60
)

// keeper implements the `ReferralKeeper` interface using an AVL tree for storage.
type keeper struct {
	store   *avl.Tree
	lastOps map[string]int64
}

// check interface implementation at compile time
var _ ReferralKeeper = &keeper{}

// NewKeeper creates and returns a new instance of ReferralKeeper.
// The keeper is initialized with an empty AVL tree for storing referral relationships.
func NewKeeper() ReferralKeeper {
	return &keeper{
		store:   avl.NewTree(),
		lastOps: make(map[string]int64),
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
func (k *keeper) setReferral(addr, refAddr std.Address, eventType string) error {
	if err := isValidCaller(std.PreviousRealm().Address()); err != nil {
		return err
	}

	if err := k.validateAddresses(addr, refAddr); err != nil {
		return err
	}

	addrStr := addr.String()
	refAddrStr := refAddr.String()

	if refAddr == zeroAddress {
		if k.has(addr) {
			// remove only if the address is already registered
			_, ok := k.store.Remove(addrStr)
			if !ok {
				return ErrNotFound
			}
		}
		return nil
	}

	if err := k.checkRateLimit(addrStr); err != nil {
		return err
	}

	k.store.Set(addrStr, refAddrStr)
	k.lastOps[addrStr] = time.Now().Unix()

	std.Emit(
		eventType,
		"myAddress", addrStr,
		"refAddress", refAddrStr,
	)

	return nil
}

// validateAddresses checks if the given addresses are valid for referral
func (k *keeper) validateAddresses(addr, refAddr std.Address) error {
	if !addr.IsValid() || (refAddr != zeroAddress && !refAddr.IsValid()) {
		return ErrInvalidAddress
	}
	if addr == refAddr {
		return ErrSelfReferral
	}
	return nil
}

// remove implements the `remove` method of the `ReferralKeeper` interface.
// It validates the caller and address before removing the referral relationship.
func (k *keeper) remove(target std.Address) error {
	if err := isValidCaller(std.PreviousRealm().Address()); err != nil {
		return err
	}

	if err := k.validateAddresses(target, zeroAddress); err != nil {
		return err
	}

	tgt := target.String()

	if err := k.checkRateLimit(tgt); err != nil {
		return err
	}

	_, ok := k.store.Remove(tgt)
	if !ok {
		return ErrNotFound
	}

	std.Emit(
		EventTypeRemove,
		"removedAddress", tgt,
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
		return zeroAddress, ErrInvalidAddress
	}

	val, ok := k.store.Get(addr.String())
	if !ok {
		return zeroAddress, ErrNotFound
	}

	refAddr, ok := val.(string)
	if !ok {
		return zeroAddress, ErrInvalidAddress
	}

	return std.Address(refAddr), nil
}

func (k *keeper) isEmpty() bool {
	empty := true
	k.store.Iterate("", "", func(key string, value any) bool {
		empty = false
		return true // stop iteration on first item
	})
	return empty
}

// checkRateLimit verifies if enough time has passed since the last operation
func (k *keeper) checkRateLimit(addr string) error {
	now := time.Now().Unix()

	if lastOpTime, exists := k.lastOps[addr]; exists {
		timeSinceLastOp := now - lastOpTime

		if timeSinceLastOp < MinTimeBetweenUpdates {
			return ErrTooManyRequests
		}
	}

	return nil
}
