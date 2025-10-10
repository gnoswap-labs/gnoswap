package loader

import (
	poolproxy "gno.land/r/gnoswap/dependency/pool"
	"gno.land/r/gnoswap/v1/pool/impl"
)

// init is only executed when loaded into genesis or when the contract is deployed.
// It registers the v1 pool implementation with the proxy.
func init() {
	poolproxy.UpdateImpl(cross, poolproxy.UpdateRequest{
		Pool:         impl.GetInstance(),
		AllowedImpls: []string{"gno.land/r/gnoswap/v1/pool/impl"},
	})
}
