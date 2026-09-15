package common

import (
	"gno.land/r/gnoswap/access/v1"
)

// RegisterInitializer registers a versioned common implementation initializer.
// If no implementation is active, the first registered initializer is activated.
// Later registrations are retained but remain inactive until UpgradeImpl selects
// their package path.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - initializer: callback invoked with discriminator 0 and the forwarded
//     current common proxy realm token, returning the version's ICommon implementation.
//     The token is the proxy execution context, not the version package's identity.
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

// UpgradeImpl activates a previously registered common implementation package
// and refreshes the cached implementation. RegisterInitializer activates only
// the first initializer when no implementation is current; call UpgradeImpl to
// activate a later registration.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - packagePath: fully qualified package path of a previously registered version
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
