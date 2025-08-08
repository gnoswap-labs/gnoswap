package referral

import (
	"std"
	"time"

	"gno.land/p/demo/avl"
)

const (
	// MinTimeBetweenUpdates is minimum duration between operations (24 hours).
	MinTimeBetweenUpdates int64 = 24 * 60 * 60
)

// keeper implements ReferralKeeper using AVL tree storage.
type keeper struct {
	store   *avl.Tree
	lastOps map[string]int64
}

var _ ReferralKeeper = &keeper{}

// NewKeeper creates new ReferralKeeper instance.
func NewKeeper() ReferralKeeper {
	return &keeper{
		store:   avl.NewTree(),
		lastOps: make(map[string]int64),
	}
}

// register sets new referral relationship.
func (k *keeper) register(addr, refAddr std.Address) error {
	return k.setReferral(addr, refAddr, EventTypeRegister)
}

// update modifies existing referral address.
func (k *keeper) update(addr, newRefAddr std.Address) error {
	return k.setReferral(addr, newRefAddr, EventTypeUpdate)
}

// setReferral handles common logic for registering and updating referrals.
// Note: Allows circular references - will need cycle validation for future reward systems.
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

// validateAddresses checks if addresses are valid for referral.
func (k *keeper) validateAddresses(addr, refAddr std.Address) error {
	if !addr.IsValid() || (refAddr != zeroAddress && !refAddr.IsValid()) {
		return ErrInvalidAddress
	}
	if addr == refAddr {
		return ErrSelfReferral
	}
	return nil
}

// remove deletes referral relationship.
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

// has checks if referral exists.
func (k *keeper) has(addr std.Address) bool {
	_, exists := k.store.Get(addr.String())
	return exists
}

// get retrieves referral address.
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
