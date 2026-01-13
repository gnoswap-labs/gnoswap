package staker

import (
	"chain/runtime"

	"gno.land/r/gnoswap/access"
)

// RegisterInitializer registers an implementation
// This function is called by each implementation version during init
func RegisterInitializer(cur realm, initializer func(govStakerStore IGovStakerStore) IGovStaker) {
	initializerFunc := func(domainStore any) any {
		currentGovStakerStore, ok := domainStore.(IGovStakerStore)
		if !ok {
			panic("domainStore is not an IGovStakerStore")
		}

		return initializer(currentGovStakerStore)
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

// UpgradeImpl upgrades the implementation to a new version
// Only admin can call this function
func UpgradeImpl(cur realm, packagePath string) {
	// Check admin permission
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
