package version_manager

// VersionManager defines the interface for managing multiple versioned implementations of a domain.
// It switches implementations while retaining domain-owned storage. Each version
// is responsible for compatibility with that state and any required migration.
//
// Design Goals:
//   - Switch registered implementations without redeploying the domain
//   - Maintain a single source of truth for storage across all versions
//   - Enforce security through domain-scoped registration
//   - Retain registered versions for later activation, subject to state compatibility
//
// Implementation Note:
// The actual implementations of each version must satisfy a common domain interface
// defined by the specific domain (e.g., ProtocolFee interface for protocol_fee domain).
type VersionManager interface {
	// RegisterInitializer registers a version's implementation.
	// Must be called by each version package during initialization.
	// First registration becomes the active implementation.
	// Subsequent registrations are retained for later switching.
	//
	// Parameters:
	//   - _: Interrealm-call discriminator; callers pass 0.
	//   - rlm: Propagated current realm context from the domain wrapper; implementations validate the current frame and inspect its previous frame to identify the registering version package.
	//   - initializer: Callback receiving the discriminator, realm context, and domain storage wrapper, and returning that version's implementation instance.
	//
	// Returns:
	//   - error: nil when the version is registered; otherwise an error for a spoofed or unauthorized caller, duplicate registration, or nil initializer.
	RegisterInitializer(_ int, rlm realm, initializer func(_ int, rlm realm, store any) any) error

	// ChangeImplementation switches the active version at runtime.
	// The domain retains its KVStore; the selected initializer must handle state
	// compatibility. The manager does not provide automatic schema migration.
	//
	// Parameters:
	//   - _: Interrealm-call discriminator; callers pass 0.
	//   - rlm: Propagated current realm context from the domain wrapper; implementations validate the current frame before switching.
	//   - packagePath: Full package path of a version previously registered with RegisterInitializer.
	//
	// Returns:
	//   - error: nil when the registered version becomes active; otherwise an error for a spoofed realm or unknown or invalid initializer.
	ChangeImplementation(_ int, rlm realm, packagePath string) error

	// GetDomainPath returns the base domain path (e.g., "gno.land/r/gnoswap/protocol_fee").
	//
	// Returns:
	//   - string: Base package path used to scope this version manager's implementations.
	GetDomainPath() string

	// GetInitializers returns all registered version initializers.
	//
	// Returns:
	//   - map[string]func(_ int, rlm realm, store any) any: Registry mapping each version package path to its initializer callback.
	GetInitializers() map[string]func(_ int, rlm realm, store any) any

	// GetCurrentPackagePath returns the package path of the active implementation.
	//
	// Returns:
	//   - string: Package path of the active implementation, or the empty string before any version is registered.
	GetCurrentPackagePath() string

	// GetCurrentImplementation returns the active version instance.
	// The caller should type-assert this to the domain-specific interface.
	//
	// Returns:
	//   - any: Active version implementation instance, or nil before the first registration.
	GetCurrentImplementation() any
}
