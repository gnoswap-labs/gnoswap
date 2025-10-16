package protocol_fee

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
// using the provided protocolFeeStore interface.
//
// The stateInitializer function creates the initial state for this version.
//
// Security: Only contracts within the domain path can register initializers.
// Each package path can only register once to prevent duplicate registrations.
func RegisterInitializer(cur realm, initializer func(protocolFeeStore IProtocolFeeStore) IProtocolFee, stateInitializer func() ProtocolFeeState) {
	// Ensure the caller is within the domain path (e.g., protocol_fee/v1, protocol_fee/v2)
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
	initialized := protocolFeeImpl != nil

	if initialized {
		// If an implementation is already active, add this version as read-only
		// This allows the new version to be registered but not immediately active
		err := kvStore.AddAuthorizedCaller(previousRealm.Address(), store.ReadOnly)
		if err != nil {
			panic(err)
		}
	} else {
		// If no implementation is active yet, make this the active implementation
		protocolFeeStore := NewprotocolFeeStore(kvStore)

		// Initialize state if it doesn't exist
		_, err := kvStore.Get(StoreKeyProtocolFeeState.String())
		if err != nil {
			// State doesn't exist, initialize it
			initialState := stateInitializer()
			protocolFeeStore.SetProtocolFeeState(initialState)
		}

		protocolFeeImpl = initializers[previousPath](protocolFeeStore)

		// Grant write permissions to the active implementation
		err = kvStore.AddAuthorizedCaller(previousRealm.Address(), store.Write)
		if err != nil {
			panic(err)
		}
	}
}

// UpgradeImpl switches the active protocol fee implementation to a different version.
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
	protocolFeeImpl = initializers[packagePath](NewprotocolFeeStore(kvStore))
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
// This ensures that only contracts like protocol_fee/v1, protocol_fee/v2 can register initializers,
// preventing external contracts from registering unauthorized implementations.
func isContainDomainPath() bool {
	previousRealm := runtime.PreviousRealm()
	if previousRealm.IsUser() {
		return false
	}

	prefix := ufmt.Sprintf("%s/", domainPath)

	return strings.HasPrefix(runtime.PreviousRealm().PkgPath(), prefix)
}
