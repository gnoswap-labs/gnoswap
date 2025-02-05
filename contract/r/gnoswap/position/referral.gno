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

// tryRegisterReferral attempts to register a referral relationship if enabled and not already existing.
// This is a non-blocking operation - failures will be logged but won't stop the main flow.
func (k *keeper) tryRegisterReferral(caller std.Address, referralAddr *std.Address) {
	if referralAddr == nil || !k.referralConfig.IsEnabled() {
		return
	}

	ref := k.referralConfig.Referral()
	if ref.Has(caller) {
		return
	}

	err := ref.Register(caller, *referralAddr)
	if err != nil {
		// for logging purposes
		std.Emit(
			referralRegisterFailed,
			"caller", caller.String(),
			"referrer", referralAddr.String(),
		)
		return
	}

	std.Emit(
		referralRegistered,
		"caller", caller.String(),
		"referrer", referralAddr.String(),
	)
}
