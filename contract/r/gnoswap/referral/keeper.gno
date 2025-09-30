package referral

import (
	"std"
	"time"

	"gno.land/p/nt/avl"
)

const (
	// MinTimeBetweenUpdates is minimum duration between operations (24 hours).
	MinTimeBetweenUpdates int64 = 24 * 60 * 60
)

// keeper implements ReferralKeeper using AVL tree storage.
// It includes rate limiting to prevent abuse.
type keeper struct {
	store   *avl.Tree
	lastOps map[string]int64
}

var _ ReferralKeeper = &keeper{}

// NewKeeper creates a new ReferralKeeper instance.
func NewKeeper() ReferralKeeper {
	return &keeper{
		store:   avl.NewTree(),
		lastOps: make(map[string]int64),
	}
}

// register creates a new referral relationship between addresses.
// Caller must have valid permissions.
func (k *keeper) register(addr, refAddr std.Address) error {
	return k.setReferral(addr, refAddr, EventTypeRegister)
}

// update modifies an existing referral address.
// Caller must have valid permissions.
func (k *keeper) update(addr, newRefAddr std.Address) error {
	return k.setReferral(addr, newRefAddr, EventTypeUpdate)
}

// setReferral handles common logic for registering and updating referrals.
// Setting refAddr to zero address removes the referral.
// Rate limiting applies to prevent abuse.
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

// validateAddresses validates that addresses are properly formatted and not self-referencing.
func (k *keeper) validateAddresses(addr, refAddr std.Address) error {
	if !addr.IsValid() || (refAddr != zeroAddress && !refAddr.IsValid()) {
		return ErrInvalidAddress
	}
	if addr == refAddr {
		return ErrSelfReferral
	}
	return nil
}

// remove deletes a referral relationship.
// Caller must have valid permissions and rate limiting applies.
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

// has returns true if a referral exists for the given address.
func (k *keeper) has(addr std.Address) bool {
	_, exists := k.store.Get(addr.String())
	return exists
}

// get retrieves the referral address for a given address.
// Returns ErrNotFound if no referral exists.
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

// isEmpty returns true if no referrals exist in the store.
func (k *keeper) isEmpty() bool {
	empty := true
	k.store.Iterate("", "", func(key string, value any) bool {
		empty = false
		return true // stop iteration on first item
	})
	return empty
}

// checkRateLimit verifies if enough time has passed since the last operation.
// Returns ErrTooManyRequests if rate limit is exceeded.
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
