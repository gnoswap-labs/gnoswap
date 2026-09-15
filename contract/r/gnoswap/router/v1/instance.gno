package router

import (
	"gno.land/r/gnoswap/router"
)

type routerV1 struct {
	store router.IRouterStore
}

// NewRouterV1 creates a router v1 implementation backed by routerStore.
//
// Parameters:
//   - routerStore: storage implementation used for swap-fee and pending protocol-fee state
//
// Returns:
//   - router: initialized IRouter implementation backed by routerStore
func NewRouterV1(
	routerStore router.IRouterStore,
) router.IRouter {
	instance := &routerV1{
		store: routerStore,
	}

	return instance
}
