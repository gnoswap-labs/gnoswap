package emission

import (
	"gno.land/r/gnoswap/v1/access"
	br "gno.land/r/gnoswap/v1/bridge"
	"gno.land/r/gnoswap/v1/gns"
)

// EmissionHandler defines the interface for handling emission changes
type EmissionHandler interface {
	HandleEmissionChange(amount int64)
}

var currentHandler EmissionHandler

// SetEmissionHandler sets the current emission handler
func SetEmissionHandler(handler EmissionHandler) {
	crossing()
	if currentHandler != nil {
		panic("emission handler already set")
	}
	currentHandler = handler
}

// HandleEmissionChange is called when per-block emission is changed from the gns side.
// It does not process non-immediate emission changes, such as halving.
func HandleEmissionChange(amount int64) {
	if currentHandler == nil {
		return
	}
	calculatedAmount := calculateAmount(amount, GetDistributionBpsPct(LIQUIDITY_STAKER))
	currentHandler.HandleEmissionChange(calculatedAmount)
}

func RegisterGnsChangeCallback() {
	crossing()
	assertStakerOnly()
	cross(gns.SetCallbackEmissionChange)(HandleEmissionChange)
}

// registerMintAndDistributeGnsCallback upgrades the version of the function stored in the bridge contract.
func registerMintAndDistributeGnsCallback() {
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	cross(br.RegisterCallback)(adminAddr, "emission", "MintAndDistributeGns", MintAndDistributeGns)
}

func init() {
	registerMintAndDistributeGnsCallback()
}
