// Package dependency provides contract dependency management and version-aware function dispatching.
//
// # Overview
//
// The dependency package is part of Layer 0 (System Infrastructure) in the GnoSwap
// architecture. It manages dependencies between contract versions and provides
// dynamic function dispatching based on the caller's version.
//
// # Key Features
//
//   - Contract version registration with realm information
//   - Dependency tracking between contract versions
//   - Version-aware function dispatching using previousRealm
//   - Circular dependency detection
//   - Upgrade path validation
//   - Impact analysis for contract upgrades
//
// # Architecture
//
// The dependency system consists of four main components:
//
//  1. Registry (registry.gno): Stores contract versions and their dependencies
//  2. Dispatcher (dispatcher.gno): Routes function calls based on caller version
//  3. Resolver (resolver.gno): Validates and resolves dependencies
//  4. Types (types.gno): Defines core data structures
//
// # Core Concept: Version-Aware Dispatching
//
// When a contract calls another contract through the dependency system:
//
//  1. The dispatcher checks std.PrevRealm() to identify the caller
//  2. It looks up the caller's contract version
//  3. It finds the required dependency version from the caller's dependency set
//  4. It returns the realm address of the correct version to call
//
// This enables different versions to coexist and call their respective dependencies.
//
// # Data Model
//
// ## Contract Version Registration
//
// Each contract version is registered with:
//   - Contract name (e.g., "pool")
//   - Version number (e.g., 2)
//   - Realm address (where the contract is deployed)
//   - List of dependencies
//
// Example:
//
//	RegisterContractVersion(
//	    ContractPool,
//	    2,
//	    std.NewRealm("gno.land/r/gnoswap/pool/v2"),
//	    []Dependency{
//	        { Contract: ContractPosition, Version: 2 },
//	        { Contract: ContractCommon, Version: 1 },
//	    },
//	)
//
// ## Dependency Set
//
// Each contract version maintains its dependencies:
//
//	DependencySet {
//	    Contract: "pool"
//	    Version: 2
//	    Dependencies: [
//	        { Contract: "position", Version: 2 },
//	        { Contract: "common", Version: 1 },
//	    ]
//	}
//
// # Usage Examples
//
// ## Registering a Contract Version
//
// When deploying pool v2:
//
//	import "gno.land/r/gnoswap/dependency"
//
//	func init() {
//	    // Called by pool/v2 during deployment
//	    realm := std.CurrentRealm()
//	    dependency.RegisterContractVersion(
//	        dependency.ContractPool,
//	        2,
//	        realm,
//	        []dependency.Dependency{
//	            { Contract: dependency.ContractPosition, Version: 2 },
//	        },
//	    )
//	}
//
// ## Making Cross-Contract Calls
//
// In pool/v2, calling position contract:
//
//	import (
//	    "gno.land/r/gnoswap/dependency"
//	    positionv2 "gno.land/r/gnoswap/position/v2"
//	)
//
//	func Swap() {
//	    // The dispatcher will ensure we call position v2
//	    // because pool v2 depends on position v2
//	    realm, err := dependency.Call(dependency.ContractPosition)
//	    if err != nil {
//	        panic(err)
//	    }
//
//	    // Now call the position contract at the correct version
//	    // The actual implementation would involve calling the realm
//	    positionv2.UpdatePosition(...)
//	}
//
// ## Simplified Usage with MustCall
//
//	func Swap() {
//	    // Panics if dependency not found
//	    realm := dependency.MustCall(dependency.ContractPosition)
//	    // Use realm to make the call
//	}
//
// ## Getting Dependency Version
//
// To check which version of a dependency you should use:
//
//	version, err := dependency.GetDependencyVersion(dependency.ContractPosition)
//	if err != nil {
//	    panic(err)
//	}
//	// version = 2 (if caller is pool v2)
//
// ## Validating Before Call
//
//	err := dependency.ValidateCall(dependency.ContractPosition)
//	if err != nil {
//	    // Handle error: dependency not registered or version mismatch
//	}
//
// ## Getting Caller's Own Version
//
//	contract, version, err := dependency.GetCallerVersion()
//	// contract = ContractPool, version = 2
//
// # Dependency Rules
//
// The dependency system enforces several rules:
//
//  1. No Self-Dependencies: A contract cannot depend on itself
//  2. No Circular Dependencies: Dependency cycles are detected and rejected
//  3. Valid Versions: All dependencies must reference registered contract versions
//  4. Version Consistency: All references to a contract must use the same version
//
// # Upgrade Process
//
// ## Step 1: Deploy New Version
//
//	// Deploy pool v3
//
// ## Step 2: Register with Dependencies
//
//	dependency.RegisterContractVersion(
//	    dependency.ContractPool,
//	    3,
//	    std.CurrentRealm(),
//	    []dependency.Dependency{
//	        { Contract: dependency.ContractPosition, Version: 3 },
//	        { Contract: dependency.ContractCommon, Version: 2 },
//	    },
//	)
//
// ## Step 3: Validate Dependencies
//
//	err := dependency.ValidateDependencies(dependency.ContractPool, 3)
//	if err != nil {
//	    panic("Invalid dependencies: " + err.Error())
//	}
//
// ## Step 4: Validate Upgrade Path
//
//	err := dependency.ValidateContractUpgrade(
//	    dependency.ContractPool,
//	    2, // from version
//	    3, // to version
//	)
//
// ## Step 5: Analyze Impact
//
//	analysis := dependency.GetImpactAnalysis(
//	    dependency.ContractPool,
//	    2,
//	    3,
//	)
//	// Shows which contracts depend on pool v2 and need updates
//
// ## Step 6: Update RBAC
//
//	// Register pool v3 in RBAC system
//	rbac.UpdateRoleAddressNextVersion("pool", poolV3Address)
//
// # How It Works: Example Scenario
//
// ## Setup
//
//	Pool v1 → Position v1
//	Pool v2 → Position v2
//
// ## Scenario 1: Pool v1 calls Position
//
//  1. Pool v1 calls dependency.Call(ContractPosition)
//  2. Dispatcher checks std.PrevRealm() → identifies caller as "pool v1"
//  3. Looks up pool v1's dependencies → finds Position v1
//  4. Returns realm of Position v1
//  5. Pool v1 calls Position v1
//
// ## Scenario 2: Pool v2 calls Position
//
//  1. Pool v2 calls dependency.Call(ContractPosition)
//  2. Dispatcher checks std.PrevRealm() → identifies caller as "pool v2"
//  3. Looks up pool v2's dependencies → finds Position v2
//  4. Returns realm of Position v2
//  5. Pool v2 calls Position v2
//
// ## Result
//
// Both versions coexist and call their respective dependencies automatically,
// with no data migration or downtime.
//
// # Security Considerations
//
//   - Only admin can register or update contract versions
//   - Circular dependency detection prevents infinite loops
//   - Version validation ensures all dependencies exist
//   - Immutable once deployed (admin can update if needed)
//
// # Integration with Other Components
//
// The dependency package integrates with other Layer 0 components:
//
//   - rbac: Manages role-based access for contract versions
//   - halt: Can halt specific contract versions independently
//   - access: Validates permissions for admin operations
//
// # Best Practices
//
//  1. Register contract versions immediately after deployment
//  2. Always validate dependencies before activation
//  3. Use ValidateContractUpgrade before upgrading
//  4. Review impact analysis to understand affected contracts
//  5. Test upgrade paths in development environment
//  6. Keep dependency chains shallow (max 2-3 levels)
//  7. Use MustCall for dependencies that are always expected
//  8. Handle errors gracefully when using Call
//
// # Performance Considerations
//
//   - Contract version lookups are O(1) using AVL tree storage
//   - Realm lookup by address is O(n) where n is total registered versions
//   - Circular dependency detection is O(d) where d is dependency depth
//   - Impact analysis iterates all registered versions
//
// # Error Handling
//
// Common errors and their meanings:
//
//   - errContractNotRegistered: Caller's realm not registered in dependency system
//   - errVersionNotFound: Specified contract version not found
//   - errDependencyNotFound: Required dependency not in caller's dependency set
//   - errCircularDependency: Circular dependency detected during registration
//   - errDependencyMismatch: Version conflict in dependency resolution
//   - errInvalidAddress: Invalid realm address provided
//
// # Debugging Tips
//
//  1. Use GetCallerVersion() to verify your contract is registered
//  2. Use GetDependencyTree() to visualize dependency structure
//  3. Use ValidateCall() to check if a call is valid before making it
//  4. Use GetImpactAnalysis() to understand upgrade implications
//  5. Check ResolveCallerDependencies() to see all your dependencies
//
// # Future Enhancements
//
// Potential future features:
//
//   - Semantic versioning support (e.g., "^1.0.0")
//   - Optional dependencies
//   - Conditional dependencies
//   - Dependency profiles (development, production)
//   - Automated dependency updates
//   - Dependency health checks
//   - Version compatibility matrix
package dependency
