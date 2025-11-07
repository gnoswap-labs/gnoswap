package fuzz

import (
	"testing"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	pool_v1 "gno.land/r/gnoswap/pool/v1"
	position_v1 "gno.land/r/gnoswap/position/v1"
	router_v1 "gno.land/r/gnoswap/router/v1"

	_ "gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/foo"
)

var (
	adminAddr = access.MustGetAddress(prabc.ROLE_ADMIN.String())

	initializedPool     = false
	initializedPosition = false
	initializedRouter   = false
)

// initStates initializes the states for the fuzz test
func initStates(t *testing.T) {
	initPoolState(t)
	initPositionState(t)
	initRouterState(t)
}

func initPoolState(t *testing.T) {
	t.Helper()
	const mockPoolPath = "gno.land/r/gnoswap/pool/mock"

	if !initializedPool {
		initializedPool = true

		testing.SetRealm(testing.NewCodeRealm(mockPoolPath))
		pool.RegisterInitializer(cross, func(_ pool.IPoolStore) pool.IPool {
			return pool_v1.NewPoolV1(newMockPoolStore())
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pool.UpgradeImpl(cross, mockPoolPath)
}

func initPositionState(t *testing.T) {
	t.Helper()
	const mockPositionPath = "gno.land/r/gnoswap/position/mock"

	if !initializedPosition {
		initializedPosition = true

		testing.SetRealm(testing.NewCodeRealm(mockPositionPath))
		position.RegisterInitializer(cross, func(_ position.IPositionStore) position.IPosition {
			return position_v1.NewPositionV1(newMockPositionStore(), newMockNFTAccessor())
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	position.UpgradeImpl(cross, mockPositionPath)
}

func initRouterState(t *testing.T) {
	t.Helper()
	const mockRouterPath = "gno.land/r/gnoswap/router/mock"

	if !initializedRouter {
		initializedRouter = true

		testing.SetRealm(testing.NewCodeRealm(mockRouterPath))
		router.RegisterInitializer(cross, func(_ router.IRouterStore) router.IRouter {
			return router_v1.NewRouterV1(newMockRouterStore())
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	router.UpgradeImpl(cross, mockRouterPath)
}
