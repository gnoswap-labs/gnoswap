package referral

import (
	"chain"
	"chain/runtime"
)

var gReferralKeeper ReferralKeeper

const EventRegisterFailed = "ReferralRegistrationFailed"

func init() {
	if gReferralKeeper == nil {
		gReferralKeeper = NewKeeper()
	}
}

// GetReferral returns the referral address for the given address.
func GetReferral(addr string) string {
	referral, err := gReferralKeeper.get(address(addr))
	if err != nil {
		return ""
	}
	return referral.String()
}

// HasReferral returns true if the given address has a referral.
func HasReferral(addr string) bool {
	_, err := gReferralKeeper.get(address(addr))
	return err == nil
}

// IsEmpty returns true if no referrals exist in the system.
func IsEmpty() bool {
	return gReferralKeeper.isEmpty()
}

// GetLastOpTimestamp returns the last operation timestamp for the given address.
// Returns ErrNotFound if no operation exists.
func GetLastOpTimestamp(addr string) (int64, error) {
	return gReferralKeeper.getLastOpTimestamp(address(addr))
}

// ContractAddress returns the address of the referral contract.
// Use this address as the referral parameter in TryRegister to remove an existing referral.
func ContractAddress() string {
	return selfAddress.String()
}

// TryRegister attempts to register a new referral.
//
// Parameters:
//   - addr: address to register
//   - referral: referral address string
//
// Returns the effective referrer after applying registration or fallback.
// Empty input is treated as "no new referrer provided" and returns the stored
// referrer without attempting registration.
// Panics if the caller is not authorized for non-empty registration attempts.
func TryRegister(cur realm, addr address, referral string) string {
	if referral == "" {
		return GetReferral(addr.String())
	}

	caller := runtime.PreviousRealm().Address()
	assertValidCaller(caller)

	refAddr := address(referral)
	err := gReferralKeeper.register(addr, refAddr)
	if err != nil {
		chain.Emit(
			EventRegisterFailed,
			"address", addr.String(),
			"error", err.Error(),
		)

		return GetReferral(addr.String())
	}

	result := referral
	if refAddr == contractAddress() {
		result = ""
	}

	chain.Emit(
		"RegisterReferral",
		"prevAddr", caller.String(),
		"address", addr.String(),
		"referral", result,
	)

	return result
}
