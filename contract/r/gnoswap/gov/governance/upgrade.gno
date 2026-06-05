package governance

import (
	"gno.land/r/gnoswap/access"
)

// RegisterInitializer registers a version-specific initializer. Each version
// (e.g. v1, v2) calls this function from its init body to plug itself into
// the proxy.
//
// The initializer constructs the version's IGovernance from the supplied
// IGovernanceStore and GovStakerAccessor. It receives a realm value that
// resolves to the governance proxy realm — the only address with write
// permission on the shared KV store — so any per-version store bootstrap
// performed inside the initializer passes the proxy's authorization check.
//
// Security: Only contracts within the domain path can register initializers.
// Each package path can only register once to prevent duplicate registrations.
func RegisterInitializer(cur realm, initializer func(_ int, rlm realm, governanceStore IGovernanceStore, stakerAccessor GovStakerAccessor) IGovernance) {
	// `cur` captured here is the governance crossing frame. The wrapping
	// closure forwards it to the version initializer so any store writes
	// the initializer performs run under the proxy's identity rather than
	// the version package's, which would fail the kvStore ACL.
	initializerFunc := func(_ int, rlm realm, domainStore any) any {
		if !rlm.IsCurrent() {
			panic(ErrSpoofedRealm)
		}

		currentGovernanceStore, ok := domainStore.(IGovernanceStore)
		if !ok {
			panic("domainStore is not an IGovernanceStore")
		}
		return initializer(0, rlm, currentGovernanceStore, newGovStakerAccessor())
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

// UpgradeImpl switches the active governance implementation to a different version.
// This function allows seamless upgrades from one version to another without
// data migration or downtime.
//
// Security: Only admin or governance can perform upgrades.
// The new implementation must have been previously registered via RegisterInitializer.
func UpgradeImpl(cur realm, targetPackagePath string) {
	// Ensure only admin or governance can perform upgrades
	prev := cur.Previous()
	access.AssertIsAdminOrGovernance(prev.Address())

	err := versionManager.ChangeImplementation(0, cur, targetPackagePath)
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
