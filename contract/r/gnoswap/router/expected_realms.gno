package router

import (
	"gno.land/r/gnoswap/v1/emission"
)

// EmissionI defines the interface for emission operations
type EmissionI struct {
	MintAndDistributeGns func() uint64
}

var emission EmissionI = EmissionI{
	MintAndDistributeGns: emission.MintAndDistributeGns,
}