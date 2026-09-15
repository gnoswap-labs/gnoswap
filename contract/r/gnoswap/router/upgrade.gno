package router

import (
	"gno.land/r/gnoswap/access/v1"
)

// RegisterInitializer registers a new router implementation version.
// Each implementation package calls it during initialization before it can be selected.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - initializer: callback that receives the propagated realm context and router store, then constructs the IRouter implementation
func RegisterInitializer(cur realm, initializer func(_ int, rlm realm, routerStore IRouterStore) IRouter) {
	initializerFunc := func(_ int, rlm realm, domainStore any) any {
		access.AssertIsRlmCurrent(0, rlm)

		currentRouterStore, ok := domainStore.(IRouterStore)
		if !ok {
			panic("domainStore is not an IRouterStore")
		}

		return initializer(0, rlm, currentRouterStore)
	}

	err := versionManager.RegisterInitializer(0, cur, initializerFunc)
	if err != nil {
		panic(err)
	}

	err = updateImplementation()
	if err != nil {
		panic(err)
	}
}

// UpgradeImpl switches the active router implementation to a different registered version.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - packagePath: package path of the previously registered implementation to activate
func UpgradeImpl(cur realm, packagePath string) {
	// Ensure only admin or governance can perform upgrades
	caller := cur.Previous().Address()
	access.AssertIsAdminOrGovernance(caller)

	err := versionManager.ChangeImplementation(0, cur, packagePath)
	if err != nil {
		panic(err)
	}

	err = updateImplementation()
	if err != nil {
		panic(err)
	}
}

// GetImplementationPackagePath returns the package path of the currently active implementation.
//
// Returns:
//   - packagePath: package path of the active implementation
func GetImplementationPackagePath() string {
	return versionManager.GetCurrentPackagePath()
}
