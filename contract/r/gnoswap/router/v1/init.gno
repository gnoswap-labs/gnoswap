package v1

import (
	"gno.land/r/gnoswap/router"
)

const (
	defaultSwapFeeBPS = uint64(15) // 0.15%
)

func init() {
	registerRouterV1()
}

func registerRouterV1() {
	router.RegisterInitializer(cross, func(routerStore router.IRouterStore) router.IRouter {
		err := initStoreData(routerStore)
		if err != nil {
			panic(err)
		}

		return NewRouterV1(routerStore)
	})
}

func initStoreData(routerStore router.IRouterStore) error {
	if !routerStore.HasSwapFeeKey() {
		err := routerStore.SetSwapFee(defaultSwapFeeBPS)
		if err != nil {
			return err
		}
	}

	if !routerStore.HasPendingProtocolFeesKey() {
		err := routerStore.SetPendingProtocolFees(make(map[string]int64))
		if err != nil {
			return err
		}
	}

	return nil
}
