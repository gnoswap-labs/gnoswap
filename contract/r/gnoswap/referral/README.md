# Referral

Referral system for tracking user relationships.

## Overview

Manages referral relationships between users. Non-removal writes have a 24-hour cooldown per user.

## Global Functions

### `TryRegister(cur realm, addr address, referral string) string`
Attempts to register, update, or remove a referral relationship and returns the effective referrer string.

- An empty `referral` only reads and returns the user's current referrer. It does not require authorization or emit an event.
- An authorized non-empty write that fails emits `ReferralRegistrationFailed` and returns the currently stored referrer.
- Passing `ContractAddress()` as `referral` removes the relationship and returns an empty string. The zero address is not the removal sentinel and is invalid.

### `GetReferral(addr string) string`
Returns the referral address for the given address. Returns empty string if not found.

### `HasReferral(addr string) bool`
Returns true if the given address has a referral.

### `IsEmpty() bool`
Returns true if no referrals exist in the system.

### `GetLastOpTimestamp(addr string) (int64, error)`
Returns the last non-removal registration or update timestamp for the address. Returns `ErrNotFound` if no such operation has been recorded.

### `ContractAddress() string`
Returns the address of the referral contract. Pass this value as `referral` to remove an existing relationship.

## Usage

### Registering or Updating a Referral

```go
package example

import (
    "gno.land/r/gnoswap/referral"
)

// RegisterUserReferral registers or updates a referral relationship.
// The returned string is the effective referrer.
func RegisterUserReferral(cur realm, userAddr, referrerAddr address) string {
    return referral.TryRegister(cross(cur), userAddr, referrerAddr.String())
}
```

### Removing a Referral

```go
package example

import (
    "gno.land/r/gnoswap/referral"
)

// RemoveUserReferral removes the referral relationship for a user.
func RemoveUserReferral(cur realm, userAddr address) string {
    return referral.TryRegister(cross(cur), userAddr, referral.ContractAddress())
}
```

### Querying Referrals

```go
package example

import (
    "gno.land/r/gnoswap/referral"
)

// GetUserReferrer returns the referrer address for a user.
// Returns empty string if no referral exists.
func GetUserReferrer(userAddr string) string {
    return referral.GetReferral(userAddr)
}

// CheckUserHasReferral returns true if the user has a registered referral.
func CheckUserHasReferral(userAddr string) bool {
    return referral.HasReferral(userAddr)
}
```

## Rate Limiting

- Non-removal registrations and updates are limited to one operation per 24 hours per address.
- Passing the referral contract's own address removes a relationship and bypasses the rate-limit check.
- Removal does not overwrite the previous non-removal timestamp, so immediate re-registration can still be rejected while that timestamp is within the cooldown.

## Events

- `RegisterReferral` is emitted for every successful non-empty write, including creation, update, and removal.
- `ReferralRegistrationFailed` is emitted when an authorized non-empty write fails.
- Empty referral queries do not emit events.

## Security

- One referral per address
- Self-referrals are rejected
- Non-empty writes require an authorized caller
- The referral contract's own address is the removal sentinel; the zero address is invalid
