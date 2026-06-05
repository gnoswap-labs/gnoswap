// Package version_manager implements a runtime version management system using the Strategy Pattern.
// It enables dynamic switching between different implementation versions of the same domain (e.g., v1, v2, v3)
// while maintaining a unified storage layer. This approach allows for seamless upgrades without migration overhead.
//
// Key Features:
//   - Dynamic implementation registration and switching
//   - Domain-scoped security (only authorized packages can register)
//   - Zero-downtime upgrades through hot-swapping
//
// Architecture Pattern: Strategy + Plugin Architecture
package version_manager

import (
	"chain"
	"errors"
	"strings"

	"gno.land/p/gnoswap/store"
)

// ErrSpoofedRealm is returned when the supplied realm token does not match the
// live crossing frame (rlm.IsCurrent() == false). It signals a stale or
// spoofed token captured in an earlier frame.
var ErrSpoofedRealm = errors.New("rlm does not match the current crossing frame")

// versionManager is the concrete implementation of VersionManager interface.
// It manages multiple versioned implementations of a domain (e.g., protocol_fee/v1, protocol_fee/v2).
//
// Storage Access Model:
// Implementation realms do NOT receive direct storage permissions. Instead, when calls flow
// from the domain proxy to the implementation, the proxy realm (which has write permission
// to the KVStore) is the one that drives the storage. This design prevents external callers
// from directly invoking implementation realms to modify storage.
type versionManager struct {
	// initializers stores registered initializer functions keyed by package path
	// Each initializer bootstraps a specific version's implementation
	initializers map[string]func(_ int, rlm realm, store any) any

	// domainKVStore is the shared storage layer accessible by all versions
	// The domain (proxy) realm is the owner and has write permission
	domainKVStore store.KVStore

	// initializeDomainStoreFn wraps the KVStore into domain-specific storage interface
	// This abstraction decouples the version manager from domain-specific storage implementations
	initializeDomainStoreFn func(_ int, rlm realm, kvStore store.KVStore) any

	// domainPath defines the base path for this domain (e.g., "gno.land/r/gnoswap/protocol_fee")
	// Used for security validation to ensure only authorized packages can register
	domainPath string

	// currentPackagePath holds the package path of the active implementation
	// (e.g., "gno.land/r/gnoswap/protocol_fee/v2")
	currentPackagePath string

	// currentImplementation is the active version's instance
	currentImplementation any
}

// RegisterInitializer registers a new version implementation for the domain.
// This method must be called by each version package (e.g., v1, v2) during initialization.
//
// The registration process:
//  1. Validates the realm token is the live crossing frame (rejects spoofed tokens)
//  2. Validates the caller is within the authorized domain path
//  3. Stores the initializer function for later version switching
//
// Parameters:
//   - rlm: the live realm token threaded in by the caller; rlm.Previous() identifies the
//     version package that is registering. The leading `_ int` is a v2 sentinel that surfaces
//     as a `0` at every call site so the realm-threading is visible to the reader.
//   - initializer: A function that receives a storage interface and returns an implementation instance
//
// Returns:
//   - error: If realm token is spoofed, caller is unauthorized, already registered, or initializer is nil
//
// Security: Only packages under the domainPath prefix can register (enforced by isContainDomainPath).
func (vm *versionManager) RegisterInitializer(_ int, rlm realm, initializer func(_ int, rlm realm, store any) any) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	// Validate initializer is not nil to prevent panic during initialization
	if initializer == nil {
		return errors.New("version_manager: initializer cannot be nil")
	}

	// Ensure the caller is within the domain path (e.g., protocol_fee/v1, protocol_fee/v2).
	// rlm.Previous() corresponds to v1's runtime.PreviousRealm().
	previousRealm := rlm.Previous()
	if previousRealm.IsUser() {
		return errors.New("version_manager: caller cannot be user")
	}

	targetPackagePath := previousRealm.PkgPath()
	if !vm.isContainDomainPath(targetPackagePath) {
		return errors.New("version_manager: caller is not in the domain path")
	}

	// Check if this package path has already been registered
	if _, ok := vm.initializers[targetPackagePath]; ok {
		return errors.New("version_manager: initializer already registered")
	}

	// Register the initializer function for this package path
	vm.initializers[targetPackagePath] = initializer

	chain.Emit(
		"RegisterInitializer",
		"domainPath", vm.domainPath,
		"registeredPackagePath", targetPackagePath,
	)

	// Initialize the current implementation if it hasn't been done yet
	if vm.currentPackagePath == "" || vm.currentImplementation == nil {
		vm.currentPackagePath = targetPackagePath
		vm.currentImplementation = initializer(0, rlm, vm.initializeDomainStoreFn(0, rlm, vm.domainKVStore))

		chain.Emit(
			"InitializeImplementation",
			"domainPath", vm.domainPath,
			"newPackagePath", targetPackagePath,
		)
	}

	return nil
}

// ChangeImplementation performs a hot-swap to a different version implementation.
// This enables zero-downtime upgrades by switching the active implementation at runtime.
//
// The switching process:
//  1. Validates the realm token is the live crossing frame (rejects spoofed tokens)
//  2. Validates the target version has been registered via RegisterInitializer
//  3. Retrieves and executes the target version's initializer
//
// Authorization is the caller realm's responsibility — version_manager only rejects
// spoofed realm tokens. Upgrade ACLs (admin / governance) live in the wrapping /r/ realm
// (see each module's upgrade.gno).
//
// Parameters:
//   - rlm: the live realm token threaded in by the caller. The leading `_ int` is a v2
//     sentinel that surfaces as a `0` at every call site so the realm-threading is visible.
//   - packagePath: The full package path of the target version (e.g., "gno.land/r/gnoswap/protocol_fee/v2")
//
// Returns:
//   - error: If realm token is spoofed, target version is not registered, or initializer is invalid
func (vm *versionManager) ChangeImplementation(_ int, rlm realm, packagePath string) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	// Retrieve the registered initializer function
	initializer, ok := vm.initializers[packagePath]
	if !ok {
		return errors.New("version_manager: initializer not found for package path:" + packagePath)
	}

	if initializer == nil {
		return errors.New("version_manager: initializer is not a function")
	}

	prevPackagePath := vm.currentPackagePath
	vm.currentPackagePath = packagePath
	vm.currentImplementation = initializer(0, rlm, vm.initializeDomainStoreFn(0, rlm, vm.domainKVStore))

	chain.Emit(
		"ChangeImplementation",
		"domainPath", vm.domainPath,
		"previousPackagePath", prevPackagePath,
		"newPackagePath", packagePath,
	)

	return nil
}

// GetDomainPath returns the base domain path for this version manager.
// Example: "gno.land/r/gnoswap/protocol_fee"
func (vm *versionManager) GetDomainPath() string {
	return vm.domainPath
}

// GetInitializers returns the map containing all registered initializer functions.
// Keys are package paths, values are initializer functions.
// Useful for inspecting which versions are available.
func (vm *versionManager) GetInitializers() map[string]func(_ int, rlm realm, store any) any {
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
//   - Package path must start with domainPath + "/"
//
// Example:
//   - domainPath: "gno.land/r/gnoswap/protocol_fee"
//   - Valid callers: "gno.land/r/gnoswap/protocol_fee/v1", "gno.land/r/gnoswap/protocol_fee/v2"
//   - Invalid callers: "gno.land/r/gnoswap/other", "gno.land/r/attacker/malicious"
func (vm *versionManager) isContainDomainPath(targetPackagePath string) bool {
	// `domainPath` is set via the current realm's PkgPath in each contract.
	// Therefore, there is no need for a separate trailing slash check,
	// and the prefix is determined by directly appending `/` for version detection.
	prefix := vm.domainPath + "/"

	return strings.HasPrefix(targetPackagePath, prefix)
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
//     The domain realm (proxy) is the owner and has write permission to this store
//
//   - initializeDomainStoreFn: A factory function that wraps the KVStore into a domain-specific storage interface
//     This abstraction allows each version to work with a familiar storage API
//     Example: func(_ int, rlm realm, kvStore store.KVStore) any { return NewProtocolFeeStore(kvStore) }
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
	initializeDomainStoreFn func(_ int, rlm realm, kvStore store.KVStore) any,
) VersionManager {
	return &versionManager{
		domainPath:              domainPath,
		domainKVStore:           kvStore,
		initializeDomainStoreFn: initializeDomainStoreFn,
		initializers:            make(map[string]func(_ int, rlm realm, store any) any),
		currentPackagePath:      "",
		currentImplementation:   nil,
	}
}
