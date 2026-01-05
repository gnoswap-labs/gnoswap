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

## Usage

```go
// Register referral (returns bool)
success := TryRegister(cross, userAddr, referrerAddr.String())

// Query referral
referrer := GetReferral(userAddress)

// Check if referral exists
exists := HasReferral(userAddress)
```

## Security

- One referral per address
- 24-hour change cooldown
- No self-referrals
- Immutable during cooldown
- Only authorized callers can modify referrals