package position

import (
	"chain/runtime"

	"gno.land/r/gnoswap/access"
)

// RegisterInitializer registers a new position implementation version.
// This function is called by each version (v1, v2, etc.) during initialization
// to register their implementation with the proxy system.
//
// The initializer function creates a new instance of the implementation
// using the provided positionStore interface.
//
// The stateInitializer function creates the initial state for this version.
//
// Security: Only contracts within the domain path can register initializers.
// Each package path can only register once to prevent duplicate registrations.
func RegisterInitializer(cur realm, initializer func(positionStore IPositionStore) IPosition) {
	initializerFunc := func(domainStore any) any {
		currentPositionStore, ok := domainStore.(IPositionStore)
		if !ok {
			panic("domainStore is not an IPositionStore")
		}

		return initializer(currentPositionStore)
	}

	err := versionManager.RegisterInitializer(initializerFunc)
	if err != nil {
		panic(err)
	}

	err = updateImplementation()
	if err != nil {
		panic(err)
	}
}

// UpgradeImpl switches the active position implementation to a different version.
// This function allows seamless upgrades from one version to another without
// data migration or downtime.
//
// Security: Only admin addresses can perform upgrades.
// The new implementation must have been previously registered via RegisterInitializer.
func UpgradeImpl(cur realm, packagePath string) {
	// Ensure only admin can perform upgrades
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdmin(caller)

	err := versionManager.ChangeImplementation(packagePath)
	if err != nil {
		panic(err)
	}

	err = updateImplementation()
	if err != nil {
		panic(err)
	}
}
