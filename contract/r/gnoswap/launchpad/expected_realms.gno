package launchpad

import (
	"std"

	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gov/governance"
)

// EmissionI defines the interface for emission realm interactions
type EmissionI struct {
	MintAndDistributeGns func() uint64
}

// en is the emission interface instance
var en EmissionI = EmissionI{
	MintAndDistributeGns: emission.MintAndDistributeGns,
}

// SetEmissionRealm replaces the emission interface implementation
func SetEmissionRealm(newEn EmissionI) {
	caller := std.PrevRealm().Addr()
	if !governance.IsPermittedSetter(caller) {
		panic("caller not permitted to set realm implementation")
	}
	en = newEn
}
