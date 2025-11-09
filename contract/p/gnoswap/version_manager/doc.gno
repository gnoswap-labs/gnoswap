// Package version_manager provides a runtime version management system for dynamic
// implementation switching without data migration. It implements the Strategy Pattern
// combined with Plugin Architecture to enable hot-swapping between different versioned
// implementations of the same domain.
//
// ## Overview
//
// Version Manager enables seamless upgrades by allowing multiple versioned implementations
// (v1, v2, v3) to coexist and share a unified storage layer. The system manages permissions
// dynamically, granting write access only to the active implementation while keeping
// previous versions available in read-only mode for backward compatibility.
//
// Key components of this package include:
//
//  1. **VersionManager Interface**: Defines the contract for managing multiple versioned
//     implementations of a domain.
//  2. **versionManager Implementation**: Concrete implementation that manages version
//     registration, permission control, and implementation switching.
//  3. **Permission-Based Access Control**: Dynamically manages read/write permissions
//     for each version through the shared KVStore.
//  4. **Domain-Scoped Security**: Ensures only authorized packages within the domain
//     path can register implementations.
//
// ## Key Features
//
//   - **Zero-Downtime Upgrades**: Switch implementations at runtime without service
//     interruption or data migration.
//   - **Unified Storage**: All versions share a single KVStore with permission-based
//     access control, eliminating migration overhead.
//   - **Hot-Swapping**: Instant version switching through dynamic strategy replacement
//     with automatic permission management.
//   - **Domain-Scoped Security**: Only packages under the authorized domain path can
//     register implementations, preventing unauthorized access.
//   - **Backward Compatibility**: Previous versions remain accessible in read-only mode
//     for gradual migration and rollback support.
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
//     their init() function to register their implementation.
//  3. **Active Implementation**: The first registered version becomes the active implementation
//     with write access; subsequent versions are granted read-only access.
//  4. **Version Switching**: Use ChangeImplementation to hot-swap to a different version,
//     which automatically updates permissions.
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
//	func init() {
//	    kvStore := store.NewKVStore("protocol_fee")
//
//	    manager = version_manager.NewVersionManager(
//	        "gno.land/r/gnoswap/protocol_fee",
//	        kvStore,
//	        func(kv store.KVStore) any {
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
//	func init() {
//	    // Register this version during package initialization
//	    manager := protocol_fee.GetManager()
//	    manager.RegisterInitializer(func(store any) any {
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
//	func init() {
//	    // Register v2 - will be read-only until explicitly activated
//	    manager := protocol_fee.GetManager()
//	    manager.RegisterInitializer(func(store any) any {
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
//	func UpgradeToV2() error {
//	    manager := protocol_fee.GetManager()
//
//	    // Hot-swap to v2 - zero downtime
//	    err := manager.ChangeImplementation("gno.land/r/gnoswap/protocol_fee/v2")
//	    if err != nil {
//	        return err
//	    }
//
//	    // v2 now has write access
//	    // v1 automatically becomes read-only
//	    return nil
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
//  2. v1 package calls RegisterInitializer during init()
//     → Becomes active implementation (write access)
//     ↓
//  3. v2 package calls RegisterInitializer during init()
//     → Registered but read-only
//     ↓
//  4. v3 package calls RegisterInitializer during init()
//     → Registered but read-only
//
// ## Version Switching Flow
//
// When switching versions, the following steps occur:
//
//  1. Admin calls ChangeImplementation("path/to/v2")
//     ↓
//  2. Version Manager retrieves v2's initializer
//     ↓
//  3. Executes v2 initializer with shared KVStore
//     ↓
//  4. Updates permissions:
//     - v1: Write → ReadOnly
//     - v2: ReadOnly → Write
//     - v3: ReadOnly (unchanged)
//     ↓
//  5. v2 is now active with write access
//
// ## Permission Model
//
// The version manager enforces a strict permission model:
//
//   - **Write Access**: Only the active implementation can modify storage. Granted
//     automatically to the first registered version or during ChangeImplementation.
//   - **Read-Only Access**: Inactive versions can read storage but cannot modify it.
//     All non-active versions are automatically downgraded to read-only.
//   - **Automatic Transition**: Permission changes are handled automatically by the
//     manager during version switching.
//   - **Domain Isolation**: Permissions are scoped to the domain's KVStore.
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
//   - Permission update failures during version switching
//   - Invalid initializer function type
//
// ## Best Practices
//
//  1. **Version Registration**: All versions should register during init() to ensure
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
//	manager.ChangeImplementation("gno.land/r/gnoswap/protocol_fee/v2")
//
// ### A/B Testing
//
// Test new implementations before full rollout:
//
//	// Switch to experimental version
//	manager.ChangeImplementation("gno.land/r/gnoswap/protocol_fee/experimental")
//
//	// Rollback if issues detected
//	manager.ChangeImplementation("gno.land/r/gnoswap/protocol_fee/v1")
//
// ### Emergency Response
//
// Quickly switch to a patched version during security incidents:
//
//	manager.ChangeImplementation("gno.land/r/gnoswap/protocol_fee/v1_hotfix")
//
// ## Limitations and Considerations
//
//   - **Type Safety**: Requires runtime type assertion to domain interface. No compile-time
//     type checking for implementation compatibility.
//   - **Atomic Switching**: Permission updates during ChangeImplementation are not
//     transactionally rolled back on partial failure. Manual recovery may be required.
//   - **Storage Schema**: Requires careful schema design for cross-version compatibility.
//     Breaking schema changes require migration or careful version ordering.
//   - **Registration Order**: The first registered version automatically becomes the
//     active implementation with write access. Plan your deployment order carefully.
//   - **No Unregistration**: Once registered, a version cannot be unregistered. Plan
//     version lifecycles accordingly.
//
// ## Related Packages
//
//   - gno.land/p/gnoswap/store: Provides KVStore with permission-based access control
//   - gno.land/p/nt/avl: AVL tree used for efficient initializer storage and lookup
//   - gno.land/p/nt/avl/rotree: Read-only tree wrapper for safe external access
//
// Package version_manager is intended for use in Gno smart contracts requiring
// dynamic, upgradeable implementations with zero-downtime version switching.
package version_manager
