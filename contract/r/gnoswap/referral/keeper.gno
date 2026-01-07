package referral

import (
	"chain"
	"chain/runtime"
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
	store   *avl.Tree // address(string) -> referral address(string)
	lastOps *avl.Tree // address(string) -> last operation timestamp(int64)
}

var _ ReferralKeeper = &keeper{}

// NewKeeper creates a new ReferralKeeper instance.
func NewKeeper() ReferralKeeper {
	return &keeper{
		store:   avl.NewTree(),
		lastOps: avl.NewTree(),
	}
}

// register creates or updates a referral relationship between addresses.
// Setting refAddr to the contract's own address removes the referral.
// Caller must have valid permissions.
func (k *keeper) register(addr, refAddr address) error {
	return k.setReferral(addr, refAddr, EventTypeRegister)
}

// setReferral handles common logic for registering and updating referrals.
// Setting refAddr to the contract's own address removes the referral.
// Rate limiting applies to prevent abuse.
func (k *keeper) setReferral(addr, refAddr address, eventType string) error {
	caller := runtime.PreviousRealm().Address()
	if err := isValidCaller(caller); err != nil {
		panic("unauthorized caller: " + caller.String())
	}

	if err := k.validateAddresses(addr, refAddr); err != nil {
		return err
	}

	addrStr := addr.String()
	refAddrStr := refAddr.String()

	if isRemovalRequest(refAddr) {
		if k.has(addr) {
			_, ok := k.store.Remove(addrStr)
			if !ok {
				return ErrNotFound
			}

			chain.Emit(
				eventType,
				"prevAddr", caller.String(),
				"address", addrStr,
				"referral", refAddrStr,
			)
		}

		return nil
	}

	if err := k.checkRateLimit(addrStr); err != nil {
		return err
	}

	k.store.Set(addrStr, refAddrStr)
	k.lastOps.Set(addrStr, time.Now().Unix())

	chain.Emit(
		eventType,
		"prevAddr", caller.String(),
		"address", addrStr,
		"referral", refAddrStr,
	)

	return nil
}

// validateAddresses validates that addresses are properly formatted and not self-referencing.
func (k *keeper) validateAddresses(addr, refAddr address) error {
	if !addr.IsValid() || (!isRemovalRequest(refAddr) && !refAddr.IsValid()) {
		return ErrInvalidAddress
	}
	if addr == refAddr {
		return ErrSelfReferral
	}
	return nil
}

// has returns true if a referral exists for the given address.
func (k *keeper) has(addr address) bool {
	_, exists := k.store.Get(addr.String())
	return exists
}

// get retrieves the referral address for a given address.
// Returns ErrNotFound if no referral exists.
func (k *keeper) get(addr address) (address, error) {
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

	return address(refAddr), nil
}

// isEmpty returns true if no referrals exist in the store.
func (k *keeper) isEmpty() bool {
	return k.store.Size() == 0
}

// getLastOpTimestamp retrieves the last operation timestamp for a given address.
// Returns ErrNotFound if no operation exists.
func (k *keeper) getLastOpTimestamp(addr address) (int64, error) {
	if !addr.IsValid() {
		return 0, ErrInvalidAddress
	}

	val, ok := k.lastOps.Get(addr.String())
	if !ok {
		return 0, ErrNotFound
	}

	ts, ok := val.(int64)
	if !ok {
		return 0, ErrInvalidTime
	}

	return ts, nil
}

// checkRateLimit verifies if enough time has passed since the last operation.
// Returns ErrTooManyRequests if rate limit is exceeded.
func (k *keeper) checkRateLimit(addr string) error {
	now := time.Now().Unix()

	lastOpTimeRaw, exists := k.lastOps.Get(addr)
	if !exists {
		return nil
	}

	lastOpTime, ok := lastOpTimeRaw.(int64)
	if !ok {
		return ErrInvalidTime
	}

	timeSinceLastOp := now - lastOpTime
	if timeSinceLastOp < MinTimeBetweenUpdates {
		return ErrTooManyRequests
	}

	return nil
}
