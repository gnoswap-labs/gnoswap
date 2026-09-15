package router

import (
	"gno.land/r/gnoswap/router"
)

const (
	defaultSwapFeeBPS = uint64(15) // 0.15%
)

// init registers the v1 router implementation when the package is initialized.
//
// Parameters:
//   - cur: Current realm context supplied by the runtime during package initialization.
func init(cur realm) {
	registerRouterV1(cur)
}

// registerRouterV1 registers the v1 implementation constructor with the router proxy.
//
// Parameters:
//   - cur: initialization realm supplied by the runtime; it is crossed into the router proxy
func registerRouterV1(cur realm) {
	router.RegisterInitializer(cross(cur), func(_ int, rlm realm, routerStore router.IRouterStore) router.IRouter {
		err := initStoreData(0, rlm, routerStore)
		if err != nil {
			panic(err)
		}

		return NewRouterV1(routerStore)
	})
}

// initStoreData initializes the persistent defaults required by router v1.
//
// Parameters:
//   - _: leading callback discriminator; callers pass 0
//   - rlm: propagated current realm context used for authorized store writes
//   - routerStore: router storage implementation whose fee and pending-fee entries are initialized
//
// Returns:
//   - err: nil when defaults are stored; the underlying storage error when initialization fails
func initStoreData(_ int, rlm realm, routerStore router.IRouterStore) error {
	if !routerStore.HasSwapFeeKey() {
		err := routerStore.SetSwapFee(0, rlm, defaultSwapFeeBPS)
		if err != nil {
			return err
		}
	}

	pendingProtocolFees := make(map[string]int64)
	if routerStore.HasPendingProtocolFeesKey() {
		pendingProtocolFees = routerStore.GetPendingProtocolFees()
	}
	if err := routerStore.SetPendingProtocolFees(0, rlm, pendingProtocolFees); err != nil {
		return err
	}

	return nil
}
