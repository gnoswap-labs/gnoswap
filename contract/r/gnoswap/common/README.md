# Common Package

Package common provides shared realm utilities for GnoSwap protocol contracts.

## Overview

The common package contains shared GRC20 token operations and native coin validation.

## Key Components

1. **GRC20 Registry Helpers**: Convenient wrappers for GRC20 token operations
2. **Coin Utilities**: Native coin (GNOT) handling and validation
3. **Assertion Utilities**: Input validation and authorization checks

## API Reference

### GRC20 Registry Helpers

The write helpers are called without crossing, for example
`common.Transfer(0, cur, ...)` and `common.SafeGRC20Transfer(0, cur, ...)`.
`GetTokenTeller` uses `RealmTeller` to bind the token actor to that current
realm before forwarding the operation.

**Token Operations:**
- **GetToken**: Retrieves GRC20 token instance
- **GetTokenTeller**: Gets a teller bound to the current realm
- **IsRegistered**: Checks token registration status
- **MustRegistered**: Validates multiple tokens are registered

**Token Queries:**
- **TotalSupply**: Returns total supply of a token
- **BalanceOf**: Returns token balance for an address
- **Allowance**: Returns allowance from owner to spender

**Token Transfers:**
- **Transfer/TransferFrom/Approve**: Returns error on failure
- **SafeGRC20Transfer/SafeGRC20TransferFrom/SafeGRC20Approve**: Panics on failure

### Coin Utilities

**Coin Validation:**
- **ExistsUserSendCoins**: Checks if user sent any coins
- **AssertIsNotHandleNativeCoin**: Ensures no native coins in transaction
