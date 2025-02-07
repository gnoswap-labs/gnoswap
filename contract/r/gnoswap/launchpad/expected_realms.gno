package launchpad

import (
	"gno.land/r/gnoswap/v1/emission"
)

// EmissionI defines the interface for emission realm interactions
type EmissionI struct {
	MintAndDistributeGns func() uint64
}

// en is the emission interface instance
var en EmissionI = EmissionI{
	MintAndDistributeGns: emission.MintAndDistributeGns,
}