// Package referral implements a referral system on Gno. It allows
// authorized contracts to register, update, or remove referral
// relationships. A referral link is defined as a mapping from one
// address (the "user") to another address (the "referrer").
//
// ## Overview
//
// The referral package is composed of the following components:
//
//  1. **errors.gno**: Defines error types for invalid addresses,
//     unauthorized callers, self-referrals, rate limits, and missing referrals.
//  2. **assert.gno**: Checks whether a caller has an authorized role.
//  3. **type.gno**: Defines the ReferralKeeper interface and the contract-address
//     sentinel used to request removal.
//  4. **keeper.gno**: Implements ReferralKeeper with BPTree storage. Non-removal
//     registrations and updates have a 24-hour cooldown.
//  5. **global_keeper.gno**: Exposes the public API and emits referral events.
//
// ## Public API
//
// The package exposes the following public functions:
//
//   - GetReferral(addr string) string: Returns the referrer address for
//     the given user. Returns empty string if not found.
//   - HasReferral(addr string) bool: Returns true if the user has a
//     registered referrer.
//   - IsEmpty() bool: Returns true if no referral relationships exist.
//   - GetLastOpTimestamp(addr string) (int64, error): Returns the last
//     non-removal registration or update timestamp for the user.
//   - TryRegister(cur realm, addr address, referral string) string:
//     Empty input reads the stored referral without authorization. A non-empty
//     input registers, updates, or removes a relationship and returns the
//     effective referrer string. Passing ContractAddress() requests removal.
//
// ## Workflow
//
// Typical usage of this contract follows these steps:
//
//  1. A caller uses TryRegister to resolve the effective referrer. Empty input
//     only reads; non-empty input must come from an authorized role.
//  2. The keeper validates the caller's permissions via assertValidCaller.
//  3. Address validation ensures the user address is valid, the referral is
//     valid for registration, and self-referrals are rejected. The contract's
//     own address is the removal sentinel.
//  4. The 24-hour rate limit is checked for non-removal registrations and
//     updates. Removal bypasses this check.
//  5. Successful non-removal writes store a new timestamp. Successful
//     non-empty writes emit a RegisterReferral event.
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
// To prevent abuse, the system enforces a 24-hour cooldown between non-removal
// registrations or updates for each address. This means:
//
//   - A new referral can only be registered once per 24 hours per address.
//   - Updates are also subject to the same rate limit.
//   - Removal via the contract-address sentinel bypasses the rate-limit check.
//   - Removal does not overwrite the previous timestamp, so immediate
//     re-registration can still be rejected during the prior cooldown.
//   - A non-removal attempt that exceeds the cooldown fails with the keeper's
//     `ErrTooManyRequests`; `TryRegister` emits `ReferralRegistrationFailed` and
//     returns the currently stored effective referrer instead of an error.
//
// ## Events
//
// The package emits the following events:
//
//   - RegisterReferral: Emitted for every successful non-empty write, including
//     creation, update, and removal.
//   - ReferralRegistrationFailed: Emitted when an authorized non-empty write
//     fails.
//   - Empty referral queries do not emit events.
//
// ## Error Handling
//
// The package defines several error values. `TryRegister` returns only a string; it
// does not return a keeper error. For an authorized non-empty write that the
// keeper rejects, including a rate-limit, validation, or self-referral failure,
// `TryRegister` emits `ReferralRegistrationFailed` and returns the currently
// stored effective referrer. An unauthorized caller is rejected before keeper
// handling and causes a panic.
//
//   - `ErrInvalidAddress`: Used when an address format is invalid
//   - `ErrSelfReferral`: Used when attempting to set self as referrer
//   - `ErrUnauthorized`: Used when the caller lacks permission; `TryRegister`
//     panics for this case
//   - `ErrTooManyRequests`: Used by the keeper when the 24-hour rate limit is
//     exceeded; `TryRegister` handles it as described above
//   - `ErrNotFound`: Used when attempting to get a non-existent referral
//   - `ErrInvalidTime`: Used when the stored timestamp format is invalid
//
// ## Example: Integration with Router Contract
//
// The router contract can register referrals during swap operations:
//
// ```go
//
//	import (
//	    "gno.land/r/gnoswap/referral/v1"
//	)
//
//	func SwapWithReferral(cur realm, referralCode string, ...) {
//	    // Get the caller address
//	    caller := cur.Previous().Address()
//
//	    actualReferrer := referral.TryRegister(cross(cur), caller, referralCode)
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
//	    "gno.land/r/gnoswap/referral/v1"
//	)
//
//	func DistributeRewards(user address, amount uint64) {
//	    // Check if user has a referrer
//	    if referral.HasReferral(user.String()) {
//	        referrerAddr := referral.GetReferral(user.String())
//	        // Calculate and distribute referral bonus
//	        referrerBonus := amount * referralRate / 100
//	        sendReward(address(referrerAddr), referrerBonus)
//	    }
//	}
//
// ```
//
// ## Limitations and Constraints
//
//   - A user can have only one referrer at a time.
//   - Self-referral is not allowed.
//   - Non-removal registrations and updates are rate-limited to once per 24
//     hours per address.
//   - Only callers with an authorized role can perform non-empty writes.
//   - The referral contract's own address is the removal sentinel; the zero
//     address is invalid.
//
// ## Notes
//
//   - The contract uses RBAC (Role-Based Access Control) for authorization.
//   - Rate-limit state persists across transactions.
//   - The referral relationship is stored in a BPTree.
package referral
