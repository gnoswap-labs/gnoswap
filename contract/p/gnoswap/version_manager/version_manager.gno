// Package version_manager implements a runtime version management system using the Strategy Pattern.
// It enables dynamic switching between different implementation versions of the same domain (e.g., v1, v2, v3)
// while maintaining a unified storage layer. This approach allows for seamless upgrades without migration overhead.
//
// Key Features:
//   - Dynamic implementation registration and switching
//   - Permission-based access control (write/read-only) per implementation
//   - Domain-scoped security (only authorized packages can register)
//   - Zero-downtime upgrades through hot-swapping
//
// Architecture Pattern: Strategy + Plugin Architecture
package version_manager

import (
	"chain"
	"chain/runtime"
	"errors"
	"strings"

	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

// versionManager is the concrete implementation of VersionManager interface.
// It manages multiple versioned implementations of a domain (e.g., protocol_fee/v1, protocol_fee/v2)
// and controls their access permissions to a shared KVStore.
//
// The manager maintains a single active implementation with write access while keeping
// previous versions available in read-only mode for backward compatibility.
type versionManager struct {
	// initializers stores registered initializer functions keyed by package path
	// Each initializer bootstraps a specific version's implementation
	initializers *avl.Tree

	// domainKVStore is the shared storage layer accessible by all versions
	// Access permissions are managed dynamically based on the active implementation
	domainKVStore store.KVStore

	// initializeDomainStoreFn wraps the KVStore into domain-specific storage interface
	// This abstraction decouples the version manager from domain-specific storage implementations
	initializeDomainStoreFn func(kvStore store.KVStore) any

	// domainPath defines the base path for this domain (e.g., "gno.land/r/gnoswap/protocol_fee")
	// Used for security validation to ensure only authorized packages can register
	domainPath string

	// currentPackagePath holds the package path of the active implementation
	// (e.g., "gno.land/r/gnoswap/protocol_fee/v2")
	currentPackagePath string

	// currentImplementation is the active version's instance
	// Only this implementation has write access to domainKVStore
	currentImplementation any
}

// RegisterInitializer registers a new version implementation for the domain.
// This method must be called by each version package (e.g., v1, v2) during initialization.
//
// The registration process:
//  1. Validates the caller is within the authorized domain path
//  2. Stores the initializer function for later version switching
//  3. Handles first-time registration differently from subsequent ones:
//     - First registration: Activates the version with write access
//     - Subsequent registrations: Grants read-only access only
//
// Parameters:
//   - initializer: A function that receives a storage interface and returns an implementation instance
//
// Returns:
//   - error: If caller is unauthorized, already registered, or permission setup fails
//
// Security: Only packages under the domainPath prefix can register (enforced by isContainDomainPath)
func (vm *versionManager) RegisterInitializer(initializer func(store any) any) error {
	// Ensure the caller is within the domain path (e.g., protocol_fee/v1, protocol_fee/v2)
	if !vm.isContainDomainPath() {
		return errors.New("version_manager: caller is not in the domain path")
	}

	previousRealm := runtime.PreviousRealm()
	targetPackagePath := previousRealm.PkgPath()

	// Check if this package path has already been registered
	if vm.initializers.Has(targetPackagePath) {
		return errors.New("version_manager: initializer already registered")
	}

	// Register the initializer function for this package path
	vm.initializers.Set(targetPackagePath, initializer)

	// Determine if this is the first registration (bootstrap case)
	initialized := vm.currentImplementation != nil
	if initialized {
		// Already have an active implementation, add this as read-only
		return vm.domainKVStore.AddAuthorizedCaller(previousRealm.Address(), store.ReadOnly)
	}

	// First registration: activate this version as the current implementation
	vm.currentPackagePath = targetPackagePath
	vm.currentImplementation = initializer(vm.initializeDomainStoreFn(vm.domainKVStore))

	// Grant write access to the first (current) implementation
	return vm.domainKVStore.AddAuthorizedCaller(previousRealm.Address(), store.Write)
}

// ChangeImplementation performs a hot-swap to a different version implementation.
// This enables zero-downtime upgrades by switching the active implementation at runtime.
//
// The switching process:
//  1. Validates the target version has been registered via RegisterInitializer
//  2. Retrieves and executes the target version's initializer
//  3. Updates storage permissions:
//     - Revokes write access from the previous active version
//     - Grants write access to the new active version
//     - Maintains read-only access for all non-active versions
//
// Parameters:
//   - packagePath: The full package path of the target version (e.g., "gno.land/r/gnoswap/protocol_fee/v2")
//
// Returns:
//   - error: If target version is not registered, initializer is invalid, or permission update fails
//
// Note: This operation is atomic in terms of permission changes - if any permission update fails,
// the error is returned immediately, but previous permission changes are not rolled back.
func (vm *versionManager) ChangeImplementation(packagePath string) error {
	// Verify the target implementation has been registered
	if !vm.initializers.Has(packagePath) {
		return errors.New("version_manager: initializer not found for package path:" + packagePath)
	}

	// Retrieve the registered initializer function
	result, ok := vm.initializers.Get(packagePath)
	if !ok {
		return errors.New("version_manager: initializer not found for package path:" + packagePath)
	}

	// Type-assert to ensure it's the expected function signature
	initializer, ok := result.(func(store any) any)
	if !ok {
		return errors.New("version_manager: initializer is not a function")
	}

	// Activate the new implementation by calling its initializer
	vm.currentImplementation = initializer(vm.initializeDomainStoreFn(vm.domainKVStore))
	packageAddress := chain.PackageAddress(vm.currentPackagePath)

	// Update storage permissions for all registered implementations
	storeAuthorizedCallers, err := vm.domainKVStore.GetAuthorizedCallers()
	if err != nil {
		return err
	}

	// Reconfigure permissions: write access for new active version, read-only for others
	for caller, _ := range storeAuthorizedCallers {
		updatedPermission := store.ReadOnly

		// Grant write access only to the new active implementation
		isCurrentPackageAddress := caller == packageAddress
		if isCurrentPackageAddress {
			updatedPermission = store.Write
		}

		err := vm.domainKVStore.UpdateAuthorizedCaller(caller, updatedPermission)
		if err != nil {
			return err
		}
	}

	return nil
}

// GetDomainPath returns the base domain path for this version manager.
// Example: "gno.land/r/gnoswap/protocol_fee"
func (vm *versionManager) GetDomainPath() string {
	return vm.domainPath
}

// GetInitializers returns the AVL tree containing all registered initializer functions.
// Keys are package paths, values are initializer functions.
// Useful for inspecting which versions are available.
func (vm *versionManager) GetInitializers() *avl.Tree {
	return vm.initializers
}

// GetCurrentPackagePath returns the package path of the currently active implementation.
func (vm *versionManager) GetCurrentPackagePath() string {
	return vm.currentPackagePath
}

// GetCurrentImplementation returns the instance of the currently active version.
// The returned value should be type-asserted to the domain-specific interface.
func (vm *versionManager) GetCurrentImplementation() any {
	return vm.currentImplementation
}

// isContainDomainPath checks if the calling contract is within the authorized domain path.
// This is a critical security check that prevents unauthorized external contracts from
// registering implementations.
//
// Validation rules:
//   - Caller must be a realm (contract), not a user
//   - Caller's package path must start with domainPath + "/"
//
// Example:
//   - domainPath: "gno.land/r/gnoswap/protocol_fee"
//   - Valid callers: "gno.land/r/gnoswap/protocol_fee/v1", "gno.land/r/gnoswap/protocol_fee/v2"
//   - Invalid callers: "gno.land/r/gnoswap/other", "gno.land/r/attacker/malicious"
func (vm *versionManager) isContainDomainPath() bool {
	previousRealm := runtime.PreviousRealm()
	if previousRealm.IsUser() {
		return false
	}

	prefix := ufmt.Sprintf("%s/", vm.domainPath)

	return strings.HasPrefix(runtime.PreviousRealm().PkgPath(), prefix)
}

// NewVersionManager creates a new version manager instance for a specific domain.
// This should be called once per domain during system initialization.
//
// Parameters:
//
//   - domainPath: The base package path for the domain (e.g., "gno.land/r/gnoswap/protocol_fee")
//     Used for access control to ensure only authorized packages can register
//
//   - kvStore: The shared key-value store that all versions will access
//     Permissions to this store are managed dynamically by the version manager
//
//   - initializeDomainStoreFn: A factory function that wraps the KVStore into a domain-specific storage interface
//     This abstraction allows each version to work with a familiar storage API
//     Example: func(kvStore store.KVStore) any { return NewProtocolFeeStore(kvStore) }
//
// Returns:
//   - VersionManager: An initialized version manager ready to accept implementation registrations
//
// Usage Pattern:
//  1. Create version manager in parent domain package
//  2. Each version (v1, v2, v3) calls RegisterInitializer during their init()
//  3. Use ChangeImplementation to switch between versions at runtime
func NewVersionManager(
	domainPath string,
	kvStore store.KVStore,
	initializeDomainStoreFn func(kvStore store.KVStore) any,
) VersionManager {
	return &versionManager{
		domainPath:              domainPath,
		domainKVStore:           kvStore,
		initializeDomainStoreFn: initializeDomainStoreFn,
		initializers:            avl.NewTree(),
		currentPackagePath:      "",
		currentImplementation:   nil,
	}
}
