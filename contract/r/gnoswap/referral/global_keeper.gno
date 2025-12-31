package referral

import "chain"

var gReferralKeeper ReferralKeeper

func init() {
	if gReferralKeeper == nil {
		gReferralKeeper = NewKeeper()
	}
}

// GetReferral returns the referral address for the given address.
func GetReferral(addr address) address {
	referral, err := gReferralKeeper.get(addr)
	if err != nil {
		return ""
	}
	return referral
}

// HasReferral returns true if the given address has a referral.
func HasReferral(addr address) bool {
	referral, err := gReferralKeeper.get(addr)
	if err != nil {
		return false
	}
	return referral != zeroAddress
}

// IsEmpty returns true if no referrals exist in the system.
func IsEmpty() bool {
	return gReferralKeeper.isEmpty()
}

// TryRegister attempts to register a new referral.
//
// Parameters:
//   - addr: address to register
//   - referral: referral address string
//
// Returns true on success, false on failure.
func TryRegister(cur realm, addr address, referral string) bool {
	refAddr := address(referral)

	err := gReferralKeeper.register(addr, refAddr)
	if err != nil {
		chain.Emit(
			"ReferralRegistrationFailed",
			"address", addr.String(),
			"error", err.Error(),
		)

		return false
	}

	return true
}
