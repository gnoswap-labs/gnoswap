package governance

import (
	"chain/runtime"

	"gno.land/r/gnoswap/access"
)

func RegisterInitializer(cur realm, initializer func(governanceStore IGovernanceStore, stakerAccessor GovStakerAccessor) IGovernance) {
	initializerFunc := func(domainStore any) any {
		currentGovernanceStore, ok := domainStore.(IGovernanceStore)
		if !ok {
			panic("domainStore is not an IGovernanceStore")
		}
		return initializer(currentGovernanceStore, newGovStakerAccessor())
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

// UpgradeImpl switches the active governance implementation to a different version.
// This function allows seamless upgrades from one version to another without
// data migration or downtime.
//
// Security: Only admin or governance can perform upgrades.
// The new implementation must have been previously registered via RegisterInitializer.
func UpgradeImpl(cur realm, targetPackagePath string) {
	// Ensure only admin or governance can perform upgrades
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	err := versionManager.ChangeImplementation(targetPackagePath)
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
