package referral

import (
	"errors"
	"time"

	bptree "gno.land/p/nt/bptree/v0"
)

const (
	// MinTimeBetweenUpdates is minimum duration between operations (24 hours).
	MinTimeBetweenUpdates int64 = 24 * 60 * 60
)

// keeper implements ReferralKeeper using BPTree storage.
// Non-removal registrations and updates use a 24-hour cooldown; removal via
// the contract-address sentinel bypasses that check and preserves the timestamp.
type keeper struct {
	store   *bptree.BPTree // address(string) -> referral address(string)
	lastOps *bptree.BPTree // address(string) -> last operation timestamp(int64)
}

var _ ReferralKeeper = &keeper{}

// NewKeeper creates a new ReferralKeeper instance.
func NewKeeper() ReferralKeeper {
	return &keeper{
		store:   bptree.NewBPTreeN(16),
		lastOps: bptree.NewBPTreeN(16),
	}
}

// register creates, updates, or removes a referral relationship between addresses.
// Setting refAddr to the contract's own address removes the referral without
// changing the last non-removal operation timestamp.
func (k *keeper) register(addr, refAddr address) (address, error) {
	if err := k.validateAddresses(addr, refAddr); err != nil {
		return zeroAddress, err
	}

	addrStr := addr.String()
	refAddrStr := refAddr.String()

	if isRemovalRequest(refAddr) {
		if k.has(addr) {
			_, ok := k.store.Remove(addrStr)
			if !ok {
				return zeroAddress, errors.New(ErrNotFound)
			}
		}

		return zeroAddress, nil
	}

	if err := k.checkRateLimit(addrStr); err != nil {
		return zeroAddress, err
	}

	k.store.Set(addrStr, refAddrStr)
	k.lastOps.Set(addrStr, time.Now().Unix())

	return refAddr, nil
}

// validateAddresses validates that addresses are properly formatted and not self-referencing.
func (k *keeper) validateAddresses(addr, refAddr address) error {
	if !addr.IsValid() || (!isRemovalRequest(refAddr) && !refAddr.IsValid()) {
		return errors.New(ErrInvalidAddress)
	}
	if addr == refAddr {
		return errors.New(ErrSelfReferral)
	}
	return nil
}

// has returns true if a referral exists for the given address.
func (k *keeper) has(addr address) bool {
	exists := k.store.Get(addr.String()) != nil
	return exists
}

// get retrieves the referral address for a given address.
// Returns ErrNotFound if no referral exists.
func (k *keeper) get(addr address) (address, error) {
	if !addr.IsValid() {
		return zeroAddress, errors.New(ErrInvalidAddress)
	}

	val := k.store.Get(addr.String())
	if val == nil {
		return zeroAddress, errors.New(ErrNotFound)
	}

	refAddr, ok := val.(string)
	if !ok {
		return zeroAddress, errors.New(ErrInvalidAddress)
	}

	return address(refAddr), nil
}

// isEmpty returns true if no referrals exist in the store.
func (k *keeper) isEmpty() bool {
	return k.store.Size() == 0
}

// getLastOpTimestamp retrieves the last non-removal registration or update
// timestamp for a given address. Returns ErrNotFound if no such operation exists.
func (k *keeper) getLastOpTimestamp(addr address) (int64, error) {
	if !addr.IsValid() {
		return 0, errors.New(ErrInvalidAddress)
	}

	val := k.lastOps.Get(addr.String())
	if val == nil {
		return 0, errors.New(ErrNotFound)
	}

	ts, ok := val.(int64)
	if !ok {
		return 0, errors.New(ErrInvalidTime)
	}

	return ts, nil
}

// checkRateLimit verifies whether enough time has passed since the last
// non-removal operation. Returns ErrTooManyRequests if the cooldown is exceeded.
func (k *keeper) checkRateLimit(addr string) error {
	now := time.Now().Unix()

	lastOpTimeRaw := k.lastOps.Get(addr)
	if lastOpTimeRaw == nil {
		return nil
	}

	lastOpTime, ok := lastOpTimeRaw.(int64)
	if !ok {
		return errors.New(ErrInvalidTime)
	}

	timeSinceLastOp := now - lastOpTime
	if timeSinceLastOp < MinTimeBetweenUpdates {
		return errors.New(ErrTooManyRequests)
	}

	return nil
}
