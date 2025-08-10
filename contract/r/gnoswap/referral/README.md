# Referral

Referral system for tracking user relationships.

## Features

- Register referral relationships
- 24-hour cooldown period
- Update/remove relationships
- AVL tree storage

## Functions

- `TryRegister` - Attempt to register referral
- `Register` - Register new referral
- `UpdateReferral` - Change referral address
- `DeleteReferral` - Remove referral relationship
- `GetReferral` - Query referral for address

## Usage

```go
// Register referral
success := TryRegister(user, referrer)

// Update referral (after cooldown)
UpdateReferral(newReferrer)

// Query referral
referrer := GetReferral(userAddress)
```

## Notes

- One referral per address
- 24-hour cooldown between changes
- Self-referral not allowed

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Cooldown Period**: 24 hours (default) - time between referral changes