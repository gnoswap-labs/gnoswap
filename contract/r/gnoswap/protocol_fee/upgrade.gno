package protocol_fee

import (
	"gno.land/r/gnoswap/access"
)

// RegisterInitializer registers a new pool implementation version.
// This function is called by each version (v1, v2, etc.) during initialization
// to register their implementation with the proxy system.
//
// The initializer function creates a new instance of the implementation
// using the provided protocolFeeStore interface. It receives a realm value
// that resolves to the protocol_fee proxy realm — the only address with
// write permission on the shared KV store — so any per-version store
// bootstrapping performed inside the initializer passes the proxy's
// authorization check.
//
// Security: Only contracts within the domain path can register initializers.
// Each package path can only register once to prevent duplicate registrations.
func RegisterInitializer(cur realm, initializer func(_ int, rlm realm, protocolFeeStore IProtocolFeeStore) IProtocolFee) {
	// `cur` captured here is the protocol_fee crossing frame. The wrapping
	// closure forwards it to the v1 initializer so any store writes the
	// initializer performs run under the proxy's identity rather than the
	// version package's, which would fail the kvStore ACL.
	initializerFunc := func(_ int, rlm realm, domainStore any) any {
		if !rlm.IsCurrent() {
			return errSpoofedRealm
		}

		currentProtocolFeeStore, ok := domainStore.(IProtocolFeeStore)
		if !ok {
			panic("domainStore is not an IProtocolFeeStore")
		}

		return initializer(0, rlm, currentProtocolFeeStore)
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

// UpgradeImpl switches the active protocol fee implementation to a different version.
// This function allows seamless upgrades from one version to another without
// data migration or downtime.
//
// Security: Only admin or governance can perform upgrades.
// The new implementation must have been previously registered via RegisterInitializer.
func UpgradeImpl(cur realm, packagePath string) {
	// Ensure only admin or governance can perform upgrades
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
