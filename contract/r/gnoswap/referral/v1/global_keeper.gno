package referral

import (
	"chain"
)

var gReferralKeeper ReferralKeeper

// EventRegisterFailed is emitted when an authorized non-empty write fails.
// Successful non-empty writes emit the RegisterReferral event.
const EventRegisterFailed = "ReferralRegistrationFailed"

func init() {
	if gReferralKeeper == nil {
		gReferralKeeper = NewKeeper()
	}
}

// GetReferral returns the referral address string stored for the given address.
//
// Parameters:
//   - addr: address string whose referral relationship is queried.
//
// Returns:
//   - referral: stored referrer address string, or an empty string when no valid referral is found.
func GetReferral(addr string) string {
	referral, err := gReferralKeeper.get(address(addr))
	if err != nil {
		return ""
	}
	return referral.String()
}

// HasReferral reports whether the given address has a stored referral.
//
// Parameters:
//   - addr: address string whose referral relationship is checked.
//
// Returns:
//   - hasReferral: true when a referral record exists; false when it is absent or invalid.
func HasReferral(addr string) bool {
	_, err := gReferralKeeper.get(address(addr))
	return err == nil
}

// IsEmpty reports whether the referral keeper contains no referral records.
//
// Returns:
//   - empty: true when the keeper store has zero referral records.
func IsEmpty() bool {
	return gReferralKeeper.isEmpty()
}

// GetLastOpTimestamp returns the last non-removal registration or update timestamp for an address.
//
// Parameters:
//   - addr: address string whose last non-removal operation is queried.
//
// Returns:
//   - timestamp: Unix timestamp of the last successful registration or update.
//   - error: nil when a timestamp exists; otherwise an invalid-address or ErrNotFound error.
func GetLastOpTimestamp(addr string) (int64, error) {
	return gReferralKeeper.getLastOpTimestamp(address(addr))
}

// ContractAddress returns the address of the referral contract.
// Use this address as the referral parameter in TryRegister to remove an existing referral.
//
// Returns:
//   - address: referral contract address string, used as the removal sentinel.
func ContractAddress() string {
	return selfAddress.String()
}

// TryRegister attempts to register, update, or remove a referral.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - addr: address whose referral relationship is read or changed.
//   - referral: empty string for a read, ContractAddress() to remove, or a candidate referrer address string.
//
// Returns:
//   - effectiveReferral: stored referrer after the operation or fallback; empty when none is stored.
//
// Empty input is treated as a read and returns the stored referrer without
// authorization, rate-limit checks, or event emission.
// Non-empty input requires an authorized caller.
func TryRegister(cur realm, addr address, referral string) string {
	if referral == "" {
		return GetReferral(addr.String())
	}

	caller := cur.Previous().Address()
	assertValidCaller(caller)

	result, err := gReferralKeeper.register(addr, address(referral))
	if err != nil {
		chain.Emit(
			EventRegisterFailed,
			"address", addr.String(),
			"error", err.Error(),
		)

		return GetReferral(addr.String())
	}

	chain.Emit(
		"RegisterReferral",
		"prevAddr", caller.String(),
		"address", addr.String(),
		"referral", result.String(),
	)

	return result.String()
}
