package staker

import (
	"std"

	en "gno.land/r/gnoswap/v1/emission"
)

// StakerEmissionHandler implements the EmissionHandler interface for staker emission changes
type StakerEmissionHandler struct{}

// HandleEmissionChange implements the EmissionHandler interface
//
// HandleEmissionChange is called by emission when
// - msPerBlock is changed
// - staker emission % is changed
// it does NOT get called in regards of halving(manually handled in cacheReward).
//
// Initially, it is passed to emission in staker.gno#init().
//
// For the parameter `emission`, which is a per-block emission for staker contract,
//   - It first caches the reward until the current block height.
//   - Then, it updates the `currentEmission` of the poolTier,
//     which will be applied for future blocks thereafter.
func (h *StakerEmissionHandler) HandleEmissionChange(amount int64) {
	poolTier.cacheReward(std.ChainHeight(), pools)
	poolTier.currentEmission = uint64(amount)
}

func init() {
	// register handler to emission package
	cross(en.SetEmissionHandler)(&StakerEmissionHandler{})
	cross(en.RegisterGnsChangeCallback)()
}
