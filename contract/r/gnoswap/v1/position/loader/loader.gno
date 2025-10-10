package loader

import (
	positionproxy "gno.land/r/gnoswap/dependency/position"
	"gno.land/r/gnoswap/v1/position/impl"
)

// init is only executed when loaded into genesis or when the contract is deployed.
// It registers the v1 position implementation with the proxy.
func init() {
	positionproxy.UpdateImpl(cross, positionproxy.UpdateRequest{
		Position:     impl.GetInstance(),
		AllowedImpls: []string{"gno.land/r/gnoswap/v1/position/impl"},
	})
}
