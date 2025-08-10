package referral

import "std"

var gReferralKeeper ReferralKeeper

const (
	EventReferralInvalid = "ReferralInvalid"
	EventRegisterFailed  = "ReferralRegistrationFailed"
	EventRegisterSuccess = "ReferralRegistrationSuccess"
)

func init() {
	if gReferralKeeper == nil {
		gReferralKeeper = NewKeeper()
	}
}

// getKeeper returns the global referral keeper instance.
func getKeeper() ReferralKeeper {
	return gReferralKeeper
}

// GetReferral returns the referral address for the given address.
func GetReferral(addr string) string {
	referral, err := gReferralKeeper.get(std.Address(addr))
	if err != nil {
		return ""
	}
	return referral.String()
}

// HasReferral returns true if the given address has a referral.
func HasReferral(addr string) bool {
	referral, err := gReferralKeeper.get(std.Address(addr))
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
func TryRegister(cur realm, addr std.Address, referral string) bool {
	refAddr := std.Address(referral)
	err := gReferralKeeper.register(addr, refAddr)
	if err != nil {
		std.Emit(
			EventRegisterFailed,
			"address", addr.String(),
			"error", err.Error(),
		)
		return false
	}

	std.Emit(
		EventRegisterSuccess,
		"address", addr.String(),
		"referral", referral,
	)
	return true
}
