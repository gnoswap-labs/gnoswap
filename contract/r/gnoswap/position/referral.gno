package position

import (
	"std"

	"gno.land/r/gnoswap/v1/referral"
)

var positionKeeper = newKeeper()

const (
	referralRegistered     = "ReferralRegistered"
	referralRegisterFailed = "ReferralRegisterFailed"
)

type keeper struct {
	referralConfig *referral.Config
}

func newKeeper() *keeper {
	return &keeper{
		referralConfig: referral.NewConfig(),
	}
}

func (k *keeper) Enable() {
	k.referralConfig.Enable()
}

func (k *keeper) Disable() {
	k.referralConfig.Disable()
}

// tryRegisterReferral attempts to register a referral relationship if conditions are met.
// This is a no-op if:
//  - Referral system is disabled
//  - Referrer address is empty
//  - User already has a referrer
func (k *keeper) tryRegisterReferral(user, referral std.Address) {
	// skip if referral is disabled or referrer address is empty
	if !k.referralConfig.IsEnabled() || referral.String() == "" {
		return
	}

	ref := k.referralConfig.Referral()
	if ref.Has(user) {
		return
	}

	emitParams := []string{
		"user", user.String(),
		"referral", referral.String(),
	}

	err := ref.Register(user, referral)
	if err != nil {
		std.Emit(referralRegisterFailed, emitParams...)
		return
	}

	std.Emit(referralRegistered, emitParams...)
}
