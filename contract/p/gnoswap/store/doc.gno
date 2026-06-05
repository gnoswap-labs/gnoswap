// Package store provides a domain-specific key-value storage system with
// permission-based write access control for Gno smart contracts.
//
// ## Overview
//
// Each domain (e.g., pool, position, router, staker) creates its own KVStore
// instance bound to a unique domain address. That domain address is the
// primary authority over the store: it can write, manage the authorized-writer
// set, and is itself implicitly authorized as a writer.
//
// Key components of this package:
//
//  1. **KVStore Interface** - The contract for domain-specific storage operations.
//  2. **kvStore Implementation** - Concrete implementation with permission
//     management and data storage.
//  3. **Write-only Permission System** - Reads are public within the package;
//     only writes (Set, Delete, ACL changes) are gated.
//  4. **Type-Safe Getters** - Typed getter methods with runtime type casting
//     and validation.
//
// ## Key Features
//
//   - **Domain Isolation**: Each domain has its own isolated storage space
//     identified by its domain address. Keys are internally prefixed with that
//     address so domains cannot collide.
//   - **Per-Realm Write ACL**: The store maintains an explicit set of realms
//     authorized to write. The domain owner is in the set by default.
//   - **Type-Safe Operations**: Specialized getters (`GetInt64`, `GetString`,
//     `GetAddress`, ...) with automatic casting and structured errors.
//   - **Realm-Frame Auth Checks**: Every write call accepts a `realm` value
//     representing the live crossing frame; the store verifies that frame
//     before consulting the ACL, defending against replayed or captured
//     `realm` values.
//
// ## Permission Model
//
// There is exactly one assignable permission level:
//
//   - **Write**: Allowed to call `Set` and `Delete`.
//
// The zero value of `Permission` is reserved and rejected by registration APIs.
// The domain address is always treated as authorized and cannot be removed.
//
// ## Realm Threading
//
// Every mutating method takes two leading parameters:
//
//	func (k *kvStore) Set(_ int, rlm realm, key string, value any) error
//
// The leading `_ int` is a deliberate sentinel: at the call site it shows up
// as a `0`, making it visually obvious that a `realm` value is being threaded
// through. `rlm` is the live crossing frame, and `rlm.IsCurrent()` is checked
// first in every mutating method to reject stale or spoofed tokens.
//
// The v1 -> v2 mapping for the two realm-identity expressions is straightforward:
//
//   - `runtime.CurrentRealm().Address()` -> `rlm.Address()` (the current realm)
//   - `runtime.PreviousRealm().Address()` -> `rlm.Previous().Address()` (the caller)
//
// Which one a given method checks is a per-method domain decision, not a v2
// framework rule. The store currently checks:
//
//   - `Set` / `Delete`: `rlm.Previous().Address()` (the caller) against the
//     write ACL. Set additionally bypasses the ACL when `rlm.IsCode()` is
//     false so EOA / user-realm callers (deploy, tests) can populate state
//     without prior registration; Delete has no such bypass.
//   - `AddAuthorizedCaller`, `UpdateAuthorizedCaller`,
//     `RemoveAuthorizedCaller`: `rlm.Address()` (the current realm) against
//     the domain address.
//
// ## Workflow
//
//  1. **Initialization**: Create a store with `NewKVStore(domainAddress)`.
//  2. **Data Operations**: Use `Set` / `Get` (and typed getters) for I/O.
//  3. **Permission Management**: From the domain realm, call
//     `AddAuthorizedCaller` to grant write access to additional realms.
//  4. **Type-Safe Retrieval**: Prefer typed getters (`GetInt64`, `GetString`,
//     etc.) over raw `Get` whenever the stored type is known.
//
// ## Example Usage
//
// ```gno
// package examplerealm
//
// import (
//
//	"gno.land/p/gnoswap/store"
//
// )
//
//	func Configure(cur realm, routerAddr address) error {
//	    // Create a KVStore owned by the current (pool) realm.
//	    kv := store.NewKVStore(cur.Address())
//
//	    // Persist some values. `0, cur` threads the live realm frame through.
//	    if err := kv.Set(0, cur, "totalLiquidity", uint64(1_000_000)); err != nil {
//	        return err
//	    }
//	    if err := kv.Set(0, cur, "poolName", "ETH-USDC"); err != nil {
//	        return err
//	    }
//
//	    // Grant write access to the router realm.
//	    if err := kv.AddAuthorizedCaller(0, cur, routerAddr, store.Write); err != nil {
//	        return err
//	    }
//
//	    // Reads are public -- no realm needed.
//	    liquidity, err := kv.GetUint64("totalLiquidity")
//	    if err != nil {
//	        return err
//	    }
//	    _ = liquidity
//
//	    return nil
//	}
//
// ```
//
// ## Permission Checks at a Glance
//
//   - **Read Operations** (`Get`, `GetInt64`, `GetString`, ...): no permission
//     check; reads are public within the package.
//   - **Write Operations** (`Set`, `Delete`): require the caller --
//     `rlm.Previous().Address()` -- to be in the write ACL. Set additionally
//     bypasses the ACL when the immediate caller is an EOA / user realm
//     (`!rlm.IsCode()`); Delete has no such bypass.
//   - **Management Operations** (`AddAuthorizedCaller`,
//     `UpdateAuthorizedCaller`, `RemoveAuthorizedCaller`): require the
//     current realm -- `rlm.Address()` -- to equal the domain address.
//
// ## Key Prefixing
//
// Internally, all keys are prefixed with the domain address to keep domains
// isolated:
//
//	Stored key: "{domainAddress}:{userKey}"
//
// This prevents key collisions between domains that share a runtime.
//
// ## Errors
//
//   - `ErrKeyNotFound` - Requested key does not exist.
//   - `ErrWritePermissionDenied` - the caller (`rlm.Previous().Address()`) is
//     not in the write ACL. For Set, this only fires when `rlm.IsCode()` is
//     true; the EOA / user-realm path bypasses the ACL.
//   - `ErrUpdatePermissionDenied` - ACL change attempted from a current realm
//     (`rlm.Address()`) other than the domain address.
//   - `ErrAuthorizedCallerAlreadyRegistered` - Adding a caller that already
//     exists.
//   - `ErrAuthorizedCallerNotFound` - Updating or removing a caller that was
//     never registered.
//   - `ErrInvalidPermission` - Permission value other than `Write` was passed.
//   - `ErrFailedCast` - Typed getter saw a value whose runtime type does not
//     match.
//   - `errSpoofedRealm` - The supplied `realm` is not the live crossing frame.
//
// ## Limitations and Considerations
//
//   - All stored values are of type `any`, so retrieval requires either a
//     typed getter or a cast.
//   - ACL management can only be performed by the domain realm itself.
//   - The domain address is implicitly authorized and cannot be removed.
//   - Keys are automatically prefixed; callers should not encode the domain
//     address into their own keys.
//
// Package store is intended for use in Gno smart contracts that need
// isolated, write-gated storage for distinct protocol components.
package store
