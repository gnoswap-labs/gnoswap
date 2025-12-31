// Package referral implements a referral system on Gno. It allows
// authorized contracts to register, update, or remove referral
// relationships. A referral link is defined as a mapping from one
// address (the "user") to another address (the "referrer").
//
// ## Overview
//
// The referral package is composed of the following components:
//
//  1. **errors.gno**: Defines error types for various failure scenarios
//     such as invalid address, unauthorized caller, self-referral,
//     rate limit exceeded, and referral not found.
//  2. **utils.gno**: Contains the isValidCaller function that checks
//     if the caller has an authorized role (governance, router, position,
//     staker, or launchpad contracts).
//  3. **type.gno**: Defines the ReferralKeeper interface and event type
//     constants for register, update, and remove operations.
//  4. **keeper.gno**: Implements the ReferralKeeper interface using an
//     AVL tree for storage. Includes rate limiting (24-hour cooldown)
//     to prevent abuse of referral operations.
//  5. **global_keeper.gno**: Exposes the public API functions that
//     external contracts can use to interact with the referral system.
//
// ## Public API
//
// The package exposes the following public functions:
//
//   - GetReferral(addr string) string: Returns the referrer address for
//     the given user address. Returns empty string if not found.
//   - HasReferral(addr string) bool: Returns true if the user has a
//     registered referrer.
//   - IsEmpty() bool: Returns true if no referral relationships exist.
//   - TryRegister(cur realm, addr address, referral string) bool:
//     Attempts to register a new referral. Returns true on success.
//
// ## Workflow
//
// Typical usage of this contract follows these steps:
//
//  1. An authorized contract (router, staker, etc.) calls TryRegister
//     to create a referral relationship.
//  2. The keeper validates the caller's permissions via isValidCaller.
//  3. Address validation ensures both addresses are valid and not
//     self-referencing.
//  4. Rate limiting checks prevent operations more than once per 24 hours.
//  5. The referral is stored in the AVL tree and an event is emitted.
//
// ## Authorized Callers
//
// Only contracts with the following roles can modify referral data:
//
//   - ROLE_GOVERNANCE: Governance contracts
//   - ROLE_GOV_STAKER: Governance staker contracts
//   - ROLE_ROUTER: Router contracts
//   - ROLE_POSITION: Position manager contracts
//   - ROLE_STAKER: Staker contracts
//   - ROLE_LAUNCHPAD: Launchpad contracts
//
// ## Rate Limiting
//
// To prevent abuse, the system enforces a 24-hour cooldown period between
// operations for each address. This means:
//
//   - A new referral can only be registered once per 24 hours per address
//   - Updates and removals are also subject to the same rate limit
//   - Attempting operations within the cooldown period returns ErrTooManyRequests
//
// ## Events
//
// The package emits the following events:
//
//   - RegisterReferral: Emitted when a new referral is created
//   - UpdateReferral: Emitted when an existing referral is modified
//   - RemoveReferral: Emitted when a referral is deleted
//   - ReferralRegistrationFailed: Emitted when TryRegister fails
//
// ## Error Handling
//
// The package defines several error types:
//   - `ErrInvalidAddress`: Returned when an address format is invalid
//   - `ErrSelfReferral`: Returned when attempting to set self as referrer
//   - `ErrUnauthorized`: Returned when the caller lacks permission
//   - `ErrTooManyRequests`: Returned when rate limit is exceeded (24-hour cooldown)
//   - `ErrNotFound`: Returned when attempting to get a non-existent referral
//
// ## Example: Integration with Router Contract
//
// The router contract can register referrals during swap operations:
//
// ```go
//
//	import (
//	    "gno.land/r/gnoswap/referral"
//	)
//
//	func SwapWithReferral(user std.Address, referralCode string, ...) {
//	    // Register the referral if provided
//	    if referralCode != "" {
//	        referral.TryRegister(std.CurrentRealm(), user, referralCode)
//	    }
//
//	    // Continue with swap logic...
//	}
//
// ```
//
// ## Example: Checking Referral for Rewards
//
// Other contracts can check referral relationships for reward distribution:
//
// ```go
//
//	import (
//	    "gno.land/r/gnoswap/referral"
//	)
//
//	func DistributeRewards(user std.Address, amount uint64) {
//	    // Check if user has a referrer
//	    if referral.HasReferral(user.String()) {
//	        referrerAddr := referral.GetReferral(user.String())
//	        // Calculate and distribute referral bonus
//	        referrerBonus := amount * referralRate / 100
//	        sendReward(std.Address(referrerAddr), referrerBonus)
//	    }
//	}
//
// ```
//
// ## Limitations and Constraints
//
//   - A user can have only one referrer at a time
//   - Self-referral is not allowed
//   - Operations are rate-limited to once per 24 hours per address
//   - Only authorized contracts can register/update/remove referrals
//   - Zero address as referrer triggers removal of the referral
//
// ## Notes
//
//   - The contract uses RBAC (Role-Based Access Control) for authorization
//   - Rate limiting state persists across transactions
//   - Events are emitted for all state changes for off-chain tracking
package referral
