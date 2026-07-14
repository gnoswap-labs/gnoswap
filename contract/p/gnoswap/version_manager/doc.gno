// Package version_manager provides a runtime version management system for dynamic
// implementation switching without data migration. It implements the Strategy Pattern
// combined with Plugin Architecture to enable hot-swapping between different versioned
// implementations of the same domain.
//
// ## Overview
//
// Version Manager enables seamless upgrades by allowing multiple versioned implementations
// (v1, v2, v3) to coexist and share a unified storage layer. The domain
// (proxy) realm owns that storage; the manager records version initializers and
// swaps the active implementation reference without granting implementation
// realms direct write permission.
//
// Key components of this package include:
//
//  1. **VersionManager Interface**: Defines the contract for managing multiple versioned
//     implementations of a domain.
//  2. **versionManager Implementation**: Concrete implementation that manages version
//     registration and active implementation switching.
//  3. **Realm-Threaded Validation**: Validates live realm tokens and restricts
//     registration to packages under the configured domain path.
//  4. **Domain-Scoped Security**: Ensures only authorized packages within the domain
//     path can register implementations.
//
// ## Key Features
//
//   - **Zero-Downtime Upgrades**: Switch implementations at runtime without service
//     interruption or data migration.
//   - **Unified Storage**: All versions share a single KVStore owned by the
//     domain (proxy) realm, eliminating migration overhead.
//   - **Hot-Swapping**: Instant version switching through dynamic strategy replacement
//     with explicit realm validation.
//   - **Domain-Scoped Security**: Only packages under the authorized domain path can
//     register implementations, preventing unauthorized access.
//   - **Backward Compatibility**: Previous versions remain registered for
//     gradual migration and rollback support.
//   - **Strategy Pattern**: Enables runtime algorithm swapping without code changes.
//
// ## Architecture Pattern
//
// The package implements two complementary design patterns:
//
//   - **Strategy Pattern**: Enables runtime selection of implementation strategies
//   - **Plugin Architecture**: Supports dynamic loading and registration of versions
//
// ## Workflow
//
// Typical usage of the version_manager package includes the following steps:
//
//  1. **Initialization**: Create a version manager for the domain using NewVersionManager.
//  2. **Version Registration**: Each version (v1, v2, v3) calls RegisterInitializer during
//     its init(cur realm) function to register its implementation.
//  3. **Active Implementation**: The first registered version becomes the active implementation;
//     subsequent versions are retained for later switching.
//  4. **Version Switching**: Use ChangeImplementation to hot-swap to a different version
//     while storage ownership stays with the domain KVStore.
//
// ## Example Usage
//
// ### Step 1: Define Domain Interface
//
// ```gno
// // protocol_fee/types.gno
// package protocol_fee
//
//	type ProtocolFee interface {
//	    SetFeeRatio(ratio uint64) error
//	    GetFeeRatio() uint64
//	}
//
// ```
//
// ### Step 2: Create Version Manager
//
// ```gno
// // protocol_fee/protocol_fee.gno
// package protocol_fee
//
// import (
//
//	"gno.land/p/gnoswap/version_manager"
//	"gno.land/p/gnoswap/store"
//
// )
//
//	var manager version_manager.VersionManager
//
//	func init(cur realm) {
//	    kvStore := store.NewKVStore(cur.Address())
//
//	    manager = version_manager.NewVersionManager(
//	        cur.PkgPath(),
//	        kvStore,
//	        func(_ int, rlm realm, kv store.KVStore) any {
//	            return NewProtocolFeeStore(kv)
//	        },
//	    )
//	}
//
//	func GetManager() version_manager.VersionManager {
//	    return manager
//	}
//
// ```
//
// ### Step 3: Implement Version 1
//
// ```gno
// // protocol_fee/v1/v1.gno
// package v1
//
// import "gno.land/r/gnoswap/protocol_fee"
//
// type protocolFeeV1 struct {
//
//	store any
//
// }
//
//	func init(cur realm) {
//	    // Register this version during package initialization.
//	    protocol_fee.RegisterInitializer(cross(cur), func(_ int, rlm realm, store any) any {
//	        return &protocolFeeV1{store: store}
//	    })
//	}
//
//	func (pf *protocolFeeV1) SetFeeRatio(ratio uint64) error {
//	    // v1 implementation
//	    return nil
//	}
//
//	func (pf *protocolFeeV1) GetFeeRatio() uint64 {
//	    // v1 implementation
//	    return 0
//	}
//
// ```
//
// ### Step 4: Implement Version 2
//
// ```gno
// // protocol_fee/v2/v2.gno
// package v2
//
// import "gno.land/r/gnoswap/protocol_fee"
//
// type protocolFeeV2 struct {
//
//	store any
//
// }
//
//	func init(cur realm) {
//	    // Register v2 - inactive until explicitly activated.
//	    protocol_fee.RegisterInitializer(cross(cur), func(_ int, rlm realm, store any) any {
//	        return &protocolFeeV2{store: store}
//	    })
//	}
//
//	func (pf *protocolFeeV2) SetFeeRatio(ratio uint64) error {
//	    // v2 improved implementation
//	    return nil
//	}
//
//	func (pf *protocolFeeV2) GetFeeRatio() uint64 {
//	    // v2 improved implementation
//	    return 0
//	}
//
// ```
//
// ### Step 5: Use Active Implementation
//
// ```gno
// // client code
// import "gno.land/r/gnoswap/protocol_fee"
//
//	func UseFee() {
//	    manager := protocol_fee.GetManager()
//	    impl := manager.GetCurrentImplementation().(protocol_fee.ProtocolFee)
//
//	    ratio := impl.GetFeeRatio()
//	    // Use the active version's implementation
//	}
//
// ```
//
// ### Step 6: Switch Versions at Runtime
//
// ```gno
// // governance or admin function
//
//	func UpgradeToV2(cur realm) {
//	    // Hot-swap to v2 - zero downtime.
//	    protocol_fee.UpgradeImpl(cross(cur), "gno.land/r/gnoswap/protocol_fee/v2")
//	}
//
// ```
//
// ## Registration Flow
//
// The version registration process follows this sequence:
//
//  1. Domain package initializes version manager with KVStore
//     ↓
//  2. v1 package calls the domain registration wrapper during init(cur realm)
//     → Becomes the active implementation
//     ↓
//  3. v2 package calls the domain registration wrapper during init(cur realm)
//     → Registered for later activation
//     ↓
//  4. v3 package calls the domain registration wrapper during init(cur realm)
//     → Registered for later activation
//
// ## Version Switching Flow
//
// When switching versions, the following steps occur:
//
//  1. Admin/governance calls the domain upgrade wrapper
//     ↓
//  2. The domain wrapper enforces authorization and calls ChangeImplementation(0, cur, ...)
//     ↓
//  3. Version Manager validates the live realm token and retrieves v2's initializer
//     ↓
//  4. Executes v2 initializer with the shared KVStore
//     ↓
//  5. Updates currentPackagePath and currentImplementation
//
// ## Storage Access Model
//
// The version manager keeps storage ownership with the domain (proxy) realm:
//
//   - **Domain Ownership**: The domain realm owns the KVStore and drives writes.
//   - **No Direct Grants**: Implementation realms do not receive direct storage
//     permissions from version_manager.
//   - **Explicit Realm Threading**: Registration and switching calls validate the
//     live realm token with `rlm.IsCurrent()` and identify the caller with
//     `rlm.Previous()`.
//   - **Domain Isolation**: Registration is scoped to packages under the domain path.
//
// ## Security
//
// Domain-scoped security ensures that only authorized packages can register:
//
//   - **Path Validation**: Caller's package path must start with the domain path + "/"
//   - **Realm Verification**: Only realm (contract) code can register, not user calls
//   - **Example**: For domain "gno.land/r/gnoswap/protocol_fee":
//   - Valid: "gno.land/r/gnoswap/protocol_fee/v1", "gno.land/r/gnoswap/protocol_fee/v2"
//   - Invalid: "gno.land/r/gnoswap/other", "gno.land/r/attacker/malicious"
//
// ## Error Handling
//
// The package returns errors for:
//
//   - Unauthorized caller attempting to register (not in domain path)
//   - Duplicate registration of the same package path
//   - Attempting to switch to an unregistered version
//   - Invalid initializer function type
//
// ## Best Practices
//
//  1. **Version Registration**: All versions should register during init(cur realm) to ensure
//     they're available before any runtime operations.
//  2. **Interface Compliance**: Ensure all versions implement the same domain interface
//     for seamless switching.
//  3. **Storage Compatibility**: Design storage schema to be forward and backward
//     compatible across versions to prevent data corruption.
//  4. **Testing**: Thoroughly test version switching in a staging environment before
//     production use.
//  5. **Rollback Support**: Keep previous versions registered to enable quick rollback
//     if issues are detected in new versions.
//  6. **Type Assertions**: Always check type assertions when retrieving the current
//     implementation to prevent runtime panics.
//
// ## Use Cases
//
// ### Protocol Upgrades
//
// Upgrade DeFi protocol logic without disrupting active users:
//
//	manager.ChangeImplementation(0, cur, "gno.land/r/gnoswap/protocol_fee/v2")
//
// ### A/B Testing
//
// Test new implementations before full rollout:
//
//	// Switch to experimental version
//	manager.ChangeImplementation(0, cur, "gno.land/r/gnoswap/protocol_fee/experimental")
//
//	// Rollback if issues detected
//	manager.ChangeImplementation(0, cur, "gno.land/r/gnoswap/protocol_fee/v1")
//
// ### Emergency Response
//
// Quickly switch to a patched version during security incidents:
//
//	manager.ChangeImplementation(0, cur, "gno.land/r/gnoswap/protocol_fee/v1_hotfix")
//
// ## Limitations and Considerations
//
//   - **Type Safety**: Requires runtime type assertion to domain interface. No compile-time
//     type checking for implementation compatibility.
//   - **Atomic Switching**: Initializer side effects during ChangeImplementation are not
//     transactionally rolled back on partial failure. Manual recovery may be required.
//   - **Storage Schema**: Requires careful schema design for cross-version compatibility.
//     Breaking schema changes require migration or careful version ordering.
//   - **Registration Order**: The first registered version automatically becomes the
//     active implementation. Plan your deployment order carefully.
//   - **No Unregistration**: Once registered, a version cannot be unregistered. Plan
//     version lifecycles accordingly.
//
// ## Related Packages
//
//   - gno.land/p/gnoswap/store: Provides KVStore with permission-based access control
//
// Package version_manager is intended for use in Gno smart contracts requiring
// dynamic, upgradeable implementations with zero-downtime version switching.
package version_manager
