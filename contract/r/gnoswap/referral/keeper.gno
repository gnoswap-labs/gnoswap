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

// NewKeeper creates an empty ReferralKeeper backed by independent referral and
// last-operation BPTrees.
//
// Returns:
//   - keeper: new referral store with no relationships or operation timestamps
func NewKeeper() ReferralKeeper {
	return &keeper{
		store:   bptree.NewBPTreeN(16),
		lastOps: bptree.NewBPTreeN(16),
	}
}

// register creates, updates, or removes a referral relationship.
// Passing the contract-address removal sentinel as refAddr removes an existing
// relationship without changing its last non-removal operation timestamp.
//
// Parameters:
//   - addr: valid account address whose referral relationship is changed
//   - refAddr: valid referral target address, or the contract-address sentinel to remove the relationship
//
// Returns:
//   - referral: refAddr after a successful create/update, or the zero address after removal or failure
//   - error: nil on a successful operation; non-nil for invalid/self addresses, cooldown violations, or an inconsistent removal
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

// validateAddresses validates addr and refAddr formats and rejects self-referrals.
// The removal sentinel is allowed in refAddr without ordinary address validation.
//
// Parameters:
//   - addr: account address whose relationship is being validated
//   - refAddr: referral target address or the contract-address removal sentinel
//
// Returns:
//   - error: nil for valid, non-self-referential addresses; ErrInvalidAddress or ErrSelfReferral otherwise
func (k *keeper) validateAddresses(addr, refAddr address) error {
	if !addr.IsValid() || (!isRemovalRequest(refAddr) && !refAddr.IsValid()) {
		return errors.New(ErrInvalidAddress)
	}
	if addr == refAddr {
		return errors.New(ErrSelfReferral)
	}
	return nil
}

// has reports whether the store contains a referral entry for addr.
//
// Parameters:
//   - addr: account address whose stored relationship is checked
//
// Returns:
//   - exists: true when an entry is present; false when no entry is stored
func (k *keeper) has(addr address) bool {
	exists := k.store.Get(addr.String()) != nil
	return exists
}

// get retrieves the stored referral address for addr.
//
// Parameters:
//   - addr: valid account address whose referral target is queried
//
// Returns:
//   - refAddr: stored referral address, or the zero address when lookup fails
//   - error: nil on success; ErrInvalidAddress for invalid input or corrupt value, or ErrNotFound when no referral exists
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

// isEmpty reports whether the referral store has no entries.
//
// Returns:
//   - empty: true when no referral relationships are stored; false otherwise
func (k *keeper) isEmpty() bool {
	return k.store.Size() == 0
}

// getLastOpTimestamp retrieves the last non-removal operation time for addr.
// Timestamps are stored as Unix seconds; removing a referral does not clear it.
//
// Parameters:
//   - addr: valid account address whose operation timestamp is queried
//
// Returns:
//   - timestamp: last non-removal operation time in Unix seconds, or 0 when lookup fails
//   - error: nil on success; ErrInvalidAddress for invalid input or ErrNotFound when no timestamp exists, with ErrInvalidTime for corrupt storage
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

// checkRateLimit checks whether addr's next non-removal operation is outside
// the 24-hour cooldown from its stored Unix-second timestamp.
//
// Parameters:
//   - addr: string key identifying the account whose cooldown is checked
//
// Returns:
//   - error: nil when no prior timestamp exists or at least 24 hours have elapsed; ErrTooManyRequests during cooldown or ErrInvalidTime for corrupt storage
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
