package router

import (
	"std"

	"gno.land/r/gnoswap/v1/emission"
)

// EmissionI defines the interface for emission operations
type EmissionI struct {
	MintAndDistributeGns func() uint64
}

var emission EmissionI = EmissionI{
	MintAndDistributeGns: emission.MintAndDistributeGns,
}

// SetEmissionRealm replaces the emission interface implementation
func SetEmissionRealm(newEmission EmissionI) {
	caller := std.PrevRealm().Addr()
	if !governance.IsPermittedSetter(caller) {
		panic("caller not permitted to set realm implementation")
	}
	emission = newEmission
}
