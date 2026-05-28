package staker

import (
	"gno.land/r/gnoswap/access"
)

// RegisterInitializer registers an implementation.
// This function is called by each implementation version during init.
//
// The initializer function creates a new instance of the implementation
// using the provided IGovStakerStore. It receives a realm value that
// resolves to the gov/staker proxy realm — the only address with write
// permission on the shared KV store — so any per-version store
// bootstrapping performed inside the initializer passes the proxy's
// authorization check.
func RegisterInitializer(cur realm, initializer func(_ int, rlm realm, govStakerStore IGovStakerStore) IGovStaker) {
	// `cur` captured here is the gov/staker crossing frame. The wrapping
	// closure forwards it to the v1 initializer so any store writes the
	// initializer performs run under the proxy's identity rather than the
	// version package's, which would fail the kvStore ACL.
	initializerFunc := func(_ int, rlm realm, domainStore any) any {
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

// UpgradeImpl upgrades the implementation to a new version
// Only admin or governance can call this function
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
func GetImplementationPackagePath() string {
	return versionManager.GetCurrentPackagePath()
}
