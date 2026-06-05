package v1

import (
	"gno.land/r/gnoswap/router"
)

const (
	defaultSwapFeeBPS = uint64(15) // 0.15%
)

func init(cur realm) {
	registerRouterV1(cur)
}

func registerRouterV1(cur realm) {
	router.RegisterInitializer(cross(cur), func(_ int, rlm realm, routerStore router.IRouterStore) router.IRouter {
		err := initStoreData(0, rlm, routerStore)
		if err != nil {
			panic(err)
		}

		return NewRouterV1(routerStore)
	})
}

func initStoreData(_ int, rlm realm, routerStore router.IRouterStore) error {
	if !routerStore.HasSwapFeeKey() {
		err := routerStore.SetSwapFee(0, rlm, defaultSwapFeeBPS)
		if err != nil {
			return err
		}
	}

	if !routerStore.HasPendingProtocolFeesKey() {
		err := routerStore.SetPendingProtocolFees(0, rlm, make(map[string]int64))
		if err != nil {
			return err
		}
	}

	return nil
}
