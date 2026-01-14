package v2

import (
	"gno.land/r/gnoswap/router"
)

type routerV1 struct {
	store router.IRouterStore
}

func NewRouterV1(
	routerStore router.IRouterStore,
) router.IRouter {
	instance := &routerV1{
		store: routerStore,
	}

	return instance
}
