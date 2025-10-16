package v1

import (
	"gno.land/r/gnoswap/router"
)

type routerV1 struct {
	store router.IRouterStore
}

// singleton instance for internal use
var routerInstance *routerV1

func NewRouterV1(routerStore router.IRouterStore) router.IRouter {
	instance := &routerV1{
		store: routerStore,
	}

	// Set singleton for internal access
	routerInstance = instance

	return instance
}

// getRouterInstance returns the singleton router instance
// This is used internally by helper functions
func getRouterInstance() *routerV1 {
	if routerInstance == nil {
		panic("router instance not initialized")
	}

	return routerInstance
}
