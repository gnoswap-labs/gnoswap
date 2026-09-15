package version_manager

// VersionManager defines the interface for managing multiple versioned implementations of a domain.
// It enables the Strategy Pattern at the package level, allowing runtime switching between
// different versions (v1, v2, v3, etc.) without requiring data migration.
//
// Design Goals:
//   - Enable zero-downtime upgrades through hot-swapping implementations
//   - Maintain a single source of truth for storage across all versions
//   - Enforce security through domain-scoped registration
//   - Support backward compatibility by keeping old versions registered for later activation
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
	// The leading `_ int, rlm realm` is the v2 interrealm-spec marker pattern:
	// the `0` sentinel surfaces at every call site so the realm threading is
	// visible to the reader, and rlm is the live crossing-frame token that
	// the implementation validates via rlm.IsCurrent() and reads via
	// rlm.Previous() to identify the version package.
	RegisterInitializer(_ int, rlm realm, initializer func(_ int, rlm realm, store any) any) error

	// ChangeImplementation switches the active version at runtime.
	// This enables hot-swapping without downtime or data migration while storage
	// ownership stays with the domain KVStore.
	//
	// The leading `_ int, rlm realm` is the v2 interrealm-spec marker pattern;
	// rlm is validated via rlm.IsCurrent() to reject spoofed/stale tokens.
	// Upgrade ACLs live in the wrapping /r/ realm, not here.
	ChangeImplementation(_ int, rlm realm, packagePath string) error

	// GetDomainPath returns the base domain path (e.g., "gno.land/r/gnoswap/protocol_fee")
	GetDomainPath() string

	// GetInitializers returns all registered version initializers
	GetInitializers() map[string]func(_ int, rlm realm, store any) any

	// GetCurrentPackagePath returns the package path of the active implementation
	GetCurrentPackagePath() string

	// GetCurrentImplementation returns the active version instance
	// The caller should type-assert this to the domain-specific interface
	GetCurrentImplementation() any
}
