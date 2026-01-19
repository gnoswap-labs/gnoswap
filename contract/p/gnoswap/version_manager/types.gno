package version_manager

import "gno.land/p/nt/avl/rotree"

// VersionManager defines the interface for managing multiple versioned implementations of a domain.
// It enables the Strategy Pattern at the package level, allowing runtime switching between
// different versions (v1, v2, v3, etc.) without requiring data migration.
//
// Design Goals:
//   - Enable zero-downtime upgrades through hot-swapping implementations
//   - Maintain a single source of truth for storage across all versions
//   - Enforce security through domain-scoped registration
//   - Support backward compatibility by keeping old versions available in read-only mode
//
// Implementation Note:
// The actual implementations of each version must satisfy a common domain interface
// defined by the specific domain (e.g., ProtocolFee interface for protocol_fee domain).
type VersionManager interface {
	// RegisterInitializer registers a version's implementation.
	// Must be called by each version package during initialization.
	// First registration becomes the active implementation with write access.
	// Subsequent registrations are granted read-only access.
	RegisterInitializer(initializer func(store any) any) error

	// ChangeImplementation switches the active version at runtime.
	// The new active version gets write access, while others remain read-only.
	// This enables hot-swapping without downtime or data migration.
	ChangeImplementation(packagePath string) error

	// GetDomainPath returns the base domain path (e.g., "gno.land/r/gnoswap/protocol_fee")
	GetDomainPath() string

	// GetInitializers returns all registered version initializers
	GetInitializers() *rotree.ReadOnlyTree

	// GetCurrentPackagePath returns the package path of the active implementation
	GetCurrentPackagePath() string

	// GetCurrentImplementation returns the active version instance
	// The caller should type-assert this to the domain-specific interface
	GetCurrentImplementation() any
}
