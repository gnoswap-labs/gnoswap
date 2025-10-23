package governance

// import (
// 	"strings"

// 	"gno.land/p/gnoswap/version_manager"
// )

import (
	"chain/runtime"

	"gno.land/r/gnoswap/access"
)

// UpgradeImpl upgrades the governance implementation to a new version.
// This function can only be called by the admin and ensures the new
// implementation is from the governance domain.
//
// Parameters:
//   - targetPath: The package path of the new implementation version
//
// Example:
//
//	UpgradeImpl("gno.land/r/gnoswap/gov/governance/v2")
// func UpgradeImpl(targetPath string) {
// 	// Check admin privileges
// 	caller := std.GetOrigCaller()
// 	if !isAdmin(caller) {
// 		panic("only admin can upgrade implementation")
// 	}

// 	// Validate target package is from governance domain
// 	if !strings.HasPrefix(targetPath, "gno.land/r/gnoswap/gov/governance/") {
// 		panic("can only upgrade to governance domain packages: " + targetPath)
// 	}

// 	// Perform upgrade
// 	UpgradeImplementation(targetPath)
// }

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
func UpgradeImpl(targetPackagePath string) {
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
