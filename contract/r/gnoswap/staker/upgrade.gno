package staker

import (
	"chain/runtime"

	"gno.land/r/gnoswap/access"
)

// RegisterInitializer registers a new staker implementation version.
// This function is called by each version (v1, v2, etc.) during initialization
// to register their implementation with the proxy system.
//
// The initializer function creates a new instance of the implementation
// using the provided stakerStore interface.
//
// Security: Only contracts within the domain path can register initializers.
// Each package path can only register once to prevent duplicate registrations.
func RegisterInitializer(cur realm, initializer func(stakerStore IStakerStore, poolAccessor PoolAccessor, emissionAccessor EmissionAccessor, nftAccessor NFTAccessor) IStaker) {
	initializerFunc := func(domainStore any) any {
		currentStakerStore, ok := domainStore.(IStakerStore)
		if !ok {
			panic("domainStore is not an IStakerStore")
		}

		return initializer(currentStakerStore, newPoolAccessor(), newEmissionAccessor(), newNFTAccessor())
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

// UpgradeImpl switches the active staker implementation to a different version.
// This function allows seamless upgrades from one version to another without
// data migration or downtime.
//
// Security: Only admin or governance can perform upgrades.
// The new implementation must have been previously registered via RegisterInitializer.
func UpgradeImpl(cur realm, packagePath string) {
	// Ensure only admin or governance can perform upgrades
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	err := versionManager.ChangeImplementation(packagePath)
	if err != nil {
		panic(err)
	}

	err = updateImplementation()
	if err != nil {
		panic(err)
	}
}

// GetImplementationPackagePath returns the package path of the currently active implementation.
func GetImplementationPackagePath() string {
	return versionManager.GetCurrentPackagePath()
}
