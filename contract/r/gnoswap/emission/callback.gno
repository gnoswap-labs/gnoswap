package emission

import (
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gns"

	br "gno.land/r/gnoswap/v1/bridge"
)

// upgradable pattern

var callbackStakerEmissionChange func(amount uint64)

func SetCallbackStakerEmissionChange(callback func(amount uint64)) {
	if callbackStakerEmissionChange != nil {
		panic("callbackStakerEmissionChange already set")
	}
	callbackStakerEmissionChange = callback
}

// Called when per-block emission is changed from the gns side.
// It does not process non-immediate emission changes, such as halving.
func callbackEmissionChange(amount uint64) {
	calculatedAmount := calculateAmount(amount, GetDistributionBpsPct(LIQUIDITY_STAKER))
	callbackStakerEmissionChange(calculatedAmount)
}

func RegisterGnsChangeCallback() {
	assertStakerOnly()
	gns.SetCallbackEmissionChange(callbackEmissionChange)
}

// RegisterMintAndDistributeGnsCallback upgrades the version of the function stored in the bridge contract.
// When an upgrade is needed, you can manually call the function using gnokey.
//
// This function is only callable by admin or governance.
func RegisterMintAndDistributeGnsCallback() {
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	govAddr, _ := access.GetAddress(access.ROLE_GOVERNANCE)
	caller := getPrevAddr()

	if caller == adminAddr || caller == govAddr {
		br.RegisterCallback(caller, "emission", "MintAndDistributeGns", MintAndDistributeGns)
	} else {
		panic("caller is not admin or governance")
	}
}
