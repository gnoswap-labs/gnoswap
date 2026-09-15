package staker

import (
	"gno.land/r/gnoswap/access"
)

// RegisterInitializer registers an implementation initializer for this realm.
// Each implementation version calls it during initialization. The callback
// receives the current realm context and shared gov/staker store so it can
// construct the versioned implementation.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - initializer: callback invoked with discriminator 0, validated propagated realm context, and IGovStakerStore, returning the implementation
func RegisterInitializer(cur realm, initializer func(_ int, rlm realm, govStakerStore IGovStakerStore) IGovStaker) {
	// `cur` captured here is the gov/staker crossing frame. The wrapping
	// closure forwards it to the v1 initializer so any store writes the
	// initializer performs run under the proxy's identity rather than the
	// version package's, which would fail the kvStore ACL.
	initializerFunc := func(_ int, rlm realm, domainStore any) any {
		access.AssertIsRlmCurrent(0, rlm)

		currentGovStakerStore, ok := domainStore.(IGovStakerStore)
		if !ok {
			panic("domainStore is not an IGovStakerStore")
		}

		return initializer(0, rlm, currentGovStakerStore)
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

// UpgradeImpl upgrades the active implementation to packagePath.
// Only admin or governance can call this function.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - packagePath: package path of the implementation version to activate
func UpgradeImpl(cur realm, packagePath string) {
	// Check admin or governance permission
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

// GetImplementationPackagePath returns the package path of the currently active implementation.
//
// Returns:
//   - packagePath: package path of the active implementation
func GetImplementationPackagePath() string {
	return versionManager.GetCurrentPackagePath()
}
