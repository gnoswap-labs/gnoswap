package emission

import (
	"std"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gns"
)

// upgradable pattern
var stakerEmissionChangeCallback func(amount int64)

func init() {
	registerEmissionChangeCallback()
}

// registerEmissionChangeCallback registers the callback function for the emission change.
func registerEmissionChangeCallback() {
	gns.SetEmissionChangeCallback(cross, emissionChangeCallback)
}

// Called when per-block emission is changed from the gns side.
// It does not process non-immediate emission changes, such as halving.
func emissionChangeCallback(amount int64) {
	if stakerEmissionChangeCallback == nil {
		panic("stakerEmissionChangeCallback is nil")
	}

	calculatedAmount := calculateAmount(amount, GetDistributionBpsPct(LIQUIDITY_STAKER))
	stakerEmissionChangeCallback(calculatedAmount)
}

func SetGnsStakerEmissionChangeCallback(cur realm, callback func(amount int64)) {
	caller := std.PreviousRealm().Address()
	access.AssertIsStaker(caller)

	stakerEmissionChangeCallback = callback
}