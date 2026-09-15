package common

import (
	"gno.land/r/gnoswap/access/v1"
)

// RegisterInitializer registers the versioned common implementation initializer
// and activates the implementation returned by it.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - initializer: callback invoked with discriminator 0 and the propagated
//     implementation realm, returning the version's ICommon implementation
func RegisterInitializer(cur realm, initializer func(_ int, rlm realm) ICommon) {
	initializerFunc := func(_ int, rlm realm, _ any) any {
		access.AssertIsRlmCurrent(0, rlm)

		return initializer(0, rlm)
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

// UpgradeImpl changes the active common implementation package and refreshes
// the cached implementation.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - packagePath: fully qualified package path of the replacement implementation
func UpgradeImpl(cur realm, packagePath string) {
	prev := cur.Previous()
	access.AssertIsAdminOrGovernance(prev.Address())

	err := versionManager.ChangeImplementation(0, cur, packagePath)
	if err != nil {
		panic(err)
	}

	err = updateImplementation()
	if err != nil {
		panic(err)
	}
}

// GetImplementationPackagePath returns the package path of the currently
// selected common implementation.
//
// Returns:
//   - packagePath: fully qualified current implementation package path
func GetImplementationPackagePath() string {
	return versionManager.GetCurrentPackagePath()
}
