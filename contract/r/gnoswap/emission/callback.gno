package emission

import (
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/bridge"
	"gno.land/r/gnoswap/v1/gns"
)

// upgradable pattern

var callbackStakerEmissionChange func(amount int64)

func SetCallbackStakerEmissionChange(callback func(amount int64)) {
	crossing()
	if callback == nil {
		panic("callback is nil")
	}
	if callbackStakerEmissionChange != nil {
		panic("callbackStakerEmissionChange already set")
	}
	callbackStakerEmissionChange = callback
}

// Called when per-block emission is changed from the gns side.
// It does not process non-immediate emission changes, such as halving.
func callbackEmissionChange(amount int64) {
	if callbackStakerEmissionChange == nil {
		panic("callbackStakerEmissionChange is nil")
	}
	calculatedAmount := calculateAmount(amount, GetDistributionBpsPct(LIQUIDITY_STAKER))
	callbackStakerEmissionChange(calculatedAmount)
}

func RegisterGnsChangeCallback() {
	crossing()
	assertStakerOnly()
	cross(gns.SetCallbackEmissionChange)(callbackEmissionChange)
}

// registerMintAndDistributeGnsCallback upgrades the version of the function stored in the bridge contract.
func registerMintAndDistributeGnsCallback() {
	// When a contract is deployed, the init function runs immediately, and the caller is always fixed as the admin.
	// Therefore, there is no need to separately check the caller in a function that applies upgrades,
	// but in a test environment, since the admin address cannot be fixed as the default address,
	// we use the admin address registered in the `access` contract instead.
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	cross(bridge.RegisterCallback)(adminAddr, "emission", "MintAndDistributeGns", MintAndDistributeGns)
}

func init() {
	registerMintAndDistributeGnsCallback()
}
