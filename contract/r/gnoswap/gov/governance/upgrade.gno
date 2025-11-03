package governance

import (
	"chain/runtime"

	"gno.land/r/gnoswap/access"
)

func RegisterInitializer(cur realm, initializer func(governanceStore IGovernanceStore) IGovernance) {
	initializerFunc := func(domainStore any) any {
		currentGovernanceStore, ok := domainStore.(IGovernanceStore)
		if !ok {
			panic("domainStore is not an IGovernanceStore")
		}
		return initializer(currentGovernanceStore)
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

// UpgradeImplementation switches to a new implementation version
func UpgradeImpl(cur realm, targetPackagePath string) {
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
func GetImplementationPackagePath() string {
	return versionManager.GetCurrentPackagePath()
}
