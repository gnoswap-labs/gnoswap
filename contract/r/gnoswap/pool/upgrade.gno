package pool

import (
	"chain"
	"chain/runtime"
	"strings"

	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/access"
)

// domainPath is the path of the domain contract.
var domainPath = runtime.CurrentRealm().PkgPath()

// RegisterInitializer registers a new pool implementation version.
// This function is called by each version (v1, v2, etc.) during initialization
// to register their implementation with the proxy system.
//
// The initializer function creates a new instance of the implementation
// using the provided poolStore interface.
//
// Security: Only contracts within the domain path can register initializers.
// Each package path can only register once to prevent duplicate registrations.
func RegisterInitializer(cur realm, initializer func(poolStore IPoolStore) IPool) {
	// Ensure the caller is within the domain path (e.g., pool/v1, pool/v2)
	if !isContainDomainPath() {
		panic("RegisterInitializer can only be called in the domain path")
	}

	previousRealm := runtime.PreviousRealm()

	// Check if this package path has already been registered
	previousPath := previousRealm.PkgPath()
	if _, ok := initializers[previousPath]; ok {
		panic("RegisterInitializer can only be called once")
	}

	// Register the initializer function for this package path
	initializers[previousPath] = initializer
	initialized := poolImpl != nil

	if initialized {
		// If an implementation is already active, add this version as read-only
		// This allows the new version to be registered but not immediately active
		err := kvStore.AddAuthorizedCaller(previousRealm.Address(), store.ReadOnly)
		if err != nil {
			panic(err)
		}
	} else {
		// If no implementation is active yet, make this the active implementation
		poolImpl = initializers[previousPath](NewPoolStore(kvStore))

		// Grant write permissions to the active implementation
		err := kvStore.AddAuthorizedCaller(previousRealm.Address(), store.Write)
		if err != nil {
			panic(err)
		}
	}
}

// UpgradeImpl switches the active pool implementation to a different version.
// This function allows seamless upgrades from one version to another without
// data migration or downtime.
//
// Security: Only admin addresses can perform upgrades.
// The new implementation must have been previously registered via RegisterInitializer.
func UpgradeImpl(cur realm, packagePath string) {
	// Ensure only admin can perform upgrades
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdmin(caller)

	// Verify the target implementation has been registered
	if _, ok := initializers[packagePath]; !ok {
		panic("Initializer not found for package path:" + packagePath)
	}

	// Switch to the new implementation
	poolImpl = initializers[packagePath](NewPoolStore(kvStore))
	packageAddress := chain.PackageAddress(packagePath)

	// Update storage permissions for all registered implementations
	storeAuthorizedCallers, err := kvStore.GetAuthorizedCallers()
	if err != nil {
		panic(err)
	}

	// Set all implementations to read-only except the new active one
	for caller, _ := range storeAuthorizedCallers {
		updatedPermission := store.ReadOnly

		// Only the new active implementation gets write permissions
		isCurrentPackageAddress := caller == packageAddress
		if isCurrentPackageAddress {
			updatedPermission = store.Write
		}

		err := kvStore.UpdateAuthorizedCaller(caller, updatedPermission)
		if err != nil {
			panic(err)
		}
	}
}

// isContainDomainPath checks if the calling contract is within the domain path.
// This ensures that only contracts like pool/v1, pool/v2 can register initializers,
// preventing external contracts from registering unauthorized implementations.
func isContainDomainPath() bool {
	previousRealm := runtime.PreviousRealm()
	if previousRealm.IsUser() {
		return false
	}

	prefix := ufmt.Sprintf("%s/", domainPath)

	return strings.HasPrefix(runtime.PreviousRealm().PkgPath(), prefix)
}
