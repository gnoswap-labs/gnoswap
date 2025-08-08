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

// getKeeper returns global referral keeper instance.
func getKeeper() ReferralKeeper {
	return gReferralKeeper
}

func GetReferral(addr string) string {
	referral, err := gReferralKeeper.get(std.Address(addr))
	if err != nil {
		return ""
	}
	return referral.String()
}

func HasReferral(addr string) bool {
	referral, err := gReferralKeeper.get(std.Address(addr))
	if err != nil {
		return false
	}
	return referral != zeroAddress
}

func IsEmpty() bool {
	return gReferralKeeper.isEmpty()
}

// TryRegister attempts to register new referral.
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
