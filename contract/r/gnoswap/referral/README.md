# Referral

Referral system for tracking user relationships.

## Overview

Manages referral relationships between users with cooldown periods to prevent gaming.

## Key Functions

### `TryRegister`
Attempts to register referral relationship.

### `Register`
Registers new referral (panics if exists).

### `UpdateReferral`
Changes referral address after cooldown.

### `DeleteReferral`
Removes referral relationship.

### `GetReferral`
Returns referral for address.

## Usage

```go
// Register referral
success := TryRegister(user, referrer)

// Update after cooldown
UpdateReferral(newReferrer)

// Query referral
referrer := GetReferral(userAddress)

// Remove referral
DeleteReferral()
```

## Security

- One referral per address
- 24-hour change cooldown
- No self-referrals
- Immutable during cooldown