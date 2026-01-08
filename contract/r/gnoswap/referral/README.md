# Referral

Referral system for tracking user relationships.

## Overview

Manages referral relationships between users with cooldown periods to prevent gaming.

## Global Functions

### `TryRegister(cur realm, addr address, referral string) bool`
Attempts to register a referral relationship. Returns true on success, false on failure.
Emits `ReferralRegistrationFailed` event on error.

### `GetReferral(addr string) string`
Returns the referral address for the given address. Returns empty string if not found.

### `HasReferral(addr string) bool`
Returns true if the given address has a referral.

### `IsEmpty() bool`
Returns true if no referrals exist in the system.

### `ContractAddress() string`
Returns the address of the referral contract. Use this address as the referral parameter in `TryRegister` to remove an existing referral.

## Usage

### Registering a Referral

```go
package example

import (
    "gno.land/r/gnoswap/referral"
)

// RegisterUserReferral registers a referral relationship for a user.
// Must be called from an authorized realm (router, staker, etc.)
func RegisterUserReferral(userAddr, referrerAddr address) bool {
    return referral.TryRegister(cross, userAddr, referrerAddr.String())
}
```

### Removing a Referral

```go
package example

import (
    "gno.land/r/gnoswap/referral"
)

// RemoveUserReferral removes the referral relationship for a user.
// Pass the contract's own address as the referral to indicate removal.
func RemoveUserReferral(userAddr address) bool {
    return referral.TryRegister(cross, userAddr, referral.ContractAddress())
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

## Security

- One referral per address
- 24-hour change cooldown
- No self-referrals
- Immutable during cooldown
- Only authorized callers can modify referrals