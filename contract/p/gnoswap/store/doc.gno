// Package store provides a domain-specific key-value storage system with
// permission-based access control for Gno smart contracts.
//
// ## Overview
//
// The store package implements a flexible KVStore interface that allows different
// domains (e.g., pool, position, router, staker) to maintain isolated storage with
// granular access control. Each domain creates its own KVStore instance with a
// unique domain address that acts as the primary authority.
//
// Key components of this package include:
//
//  1. **KVStore Interface**: Defines the contract for domain-specific storage operations.
//  2. **kvStore Implementation**: Concrete implementation of the KVStore interface with
//     permission management and data storage.
//  3. **Permission System**: Domain-owned write access with optional Write grants
//     for authorized callers.
//  4. **Type-Safe Getters**: Strongly-typed getter methods with runtime type casting
//     and validation.
//
// ## Key Features
//
//   - **Domain Isolation**: Each domain has its own isolated storage space identified
//     by its domain address.
//   - **Permission-Based Access Control**: Write permission for authorized callers
//     beyond the domain owner.
//   - **Type-Safe Operations**: Specialized getter methods (GetInt64, GetString, GetAddress,
//     etc.) with automatic type casting and error handling.
//   - **Runtime Permission Checks**: Automatic write permission verification using
//     runtime.CurrentRealm() for mutating operations.
//   - **Authorized Caller Management**: Dynamic addition, update, and removal of authorized
//     callers with specific permissions.
//
// ## Permission Model
//
// The package defines one assignable permission level:
//
//   - **Write (1)**: Can mutate data through Set/Delete.
//
// Zero-value or unknown permissions are invalid for registration. Callers not in
// the authorized-caller table have no write access. Read methods do not enforce
// caller permissions; realm-level APIs must gate sensitive reads themselves.
// The domain address (owner) always has Write permission and cannot be removed.
//
// ## Workflow
//
// Typical usage of the store package includes the following steps:
//
//  1. **Initialization**: Create a new KVStore instance using `NewKVStore(domainAddress)`.
//  2. **Data Operations**: Use Set/Get methods to store and retrieve data.
//  3. **Permission Management**: Add authorized callers using `AddAuthorizedCaller`.
//  4. **Type-Safe Retrieval**: Use typed getters like `GetInt64`, `GetString`, etc.
//
// ## Example Usage
//
// ```gno
// package main
//
// import (
//
//	"std"
//
//	"gno.land/p/gnoswap/store"
//
// )
//
//	func main() {
//	    // Create a new KVStore for a pool domain
//	    poolAddr := std.Address("g1pool...")
//	    kvStore := store.NewKVStore(poolAddr)
//
//	    // Store various types of data
//	    kvStore.Set("totalLiquidity", uint64(1000000))
//	    kvStore.Set("poolName", "ETH-USDC")
//	    kvStore.Set("isActive", true)
//	    kvStore.Set("feeRate", int64(3000))
//
//	    // Retrieve data with type safety
//	    liquidity, err := kvStore.GetUint64("totalLiquidity")
//	    if err != nil {
//	        panic(err)
//	    }
//
//	    poolName, err := kvStore.GetString("poolName")
//	    if err != nil {
//	        panic(err)
//	    }
//
//	    // Grant write access to another authorized caller
//	    if err := kvStore.AddAuthorizedCaller(routerAddr, store.Write); err != nil {
//	        panic(err)
//	    }
//
//	    // Check permissions
//	    if kvStore.IsWriteAuthorized(routerAddr) {
//	        println("Router has write access")
//	    }
//
//	    // Get all authorized callers
//	    callers, err := kvStore.GetAuthorizedCallers()
//	    if err != nil {
//	        panic(err)
//	    }
//
//	    // Remove an authorized caller
//	    if err := kvStore.RemoveAuthorizedCaller(routerAddr); err != nil {
//	        panic(err)
//	    }
//	}
//
// ```
//
// ## Permission Checks
//
// The store automatically verifies permissions during operations:
//
//   - **Read Operations**: `Get`, `GetInt64`, `GetString`, etc. do not check caller permission.
//   - **Write Operations**: `Set` and `Delete` require Write permission.
//   - **Management Operations**: `AddAuthorizedCaller`, `UpdateAuthorizedCaller`, and
//     `RemoveAuthorizedCaller` can only be called by the domain address itself.
//
// ## Key Prefixing
//
// Internally, all keys are prefixed with the domain address to ensure isolation:
//
//	Actual key: "{domainAddress}:{userKey}"
//
// This prevents key collisions between different domains.
//
// ## Error Handling
//
// The package defines several error types:
//
//   - ErrKeyNotFound: Requested key does not exist in the store.
//   - ErrReadPermissionDenied: Retained for compatibility; current read paths do not emit it.
//   - ErrWritePermissionDenied: Caller lacks write permission.
//   - ErrUpdatePermissionDenied: Only domain address can manage authorized callers.
//   - ErrAuthorizedCallerAlreadyRegistered: Attempting to add an already registered caller.
//   - ErrAuthorizedCallerNotFound: Attempting to update/remove a non-existent caller.
//   - ErrInvalidPermission: Attempting to assign an unsupported permission level.
//   - ErrFailedCast: Type casting failed during typed getter operations.
//
// ## Type Casting Utilities
//
// The package provides utility functions for safe type casting:
//
//   - CastToInt64: Casts to int64 with error handling
//   - CastToUint64: Casts to uint64 with error handling
//   - CastToBool: Casts to bool with error handling
//   - CastToString: Casts to string with error handling
//   - CastToAddress: Casts to address with error handling
//
// These utilities are used internally by typed getters but can also be used directly.
//
// ## Limitations and Considerations
//
//   - All stored values are of type `any`, requiring runtime type casting for retrieval.
//   - Read methods are not permission-gated. Add realm-level checks for sensitive reads.
//   - Permission management can only be performed by the domain address itself.
//   - The domain address always has Write permission and cannot be removed from
//     authorized callers.
//   - Keys are automatically prefixed with the domain address for isolation.
//
// Package store is intended for use in Gno smart contracts requiring isolated,
// permission-controlled storage for different protocol components.
package store
