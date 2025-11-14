package governance

import (
	"chain"
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

	prevPackagePath := versionManager.GetCurrentPackagePath()

	err := versionManager.ChangeImplementation(targetPackagePath)
	if err != nil {
		panic(err)
	}

	err = updateImplementation()
	if err != nil {
		panic(err)
	}

	chain.Emit(
		"UpgradeGovernanceContract",
		"previousPackagePath", prevPackagePath,
		"newPackagePath", targetPackagePath,
	)
}

// GetImplementationPackagePath returns the package path of the currently active implementation.
func GetImplementationPackagePath() string {
	return versionManager.GetCurrentPackagePath()
}
