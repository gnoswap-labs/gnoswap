# Common Package

Package common provides shared realm utilities for GnoSwap protocol contracts.

## Overview

The common package contains shared GRC20 token operations and native coin validation.

## Gnoweb

The root `Render("")` delegates to the active implementation and shows the realm address, implementation path, and network-wide token registry count. The count is not a Gnoswap whitelist. Token keys use `realm-path.SYMBOL`, and token amounts use each token's base units.

Rendering is read-only and does not enumerate registry entries. Unsupported paths return `404`.

## Key Components

1. **GRC20 Registry Helpers**: Convenient wrappers for GRC20 token operations
2. **Coin Utilities**: Native coin (GNOT) handling and validation
3. **Assertion Utilities**: Input validation for supported operations (not authorization checks)

## API Reference

### GRC20 Registry Helpers

The write helpers are called without crossing, for example
`common.Transfer(0, cur, ...)` and `common.SafeGRC20Transfer(0, cur, ...)`.
The token actor is bound to that current realm via `RealmTeller` before the operation is forwarded.
Token lookup goes through the registered implementation (`common/v1` resolves `gno.land/r/nt/grc20reg/v0`),
which is swapped with `UpgradeImpl` like the other proxy realms.

**Token Operations:**
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
- **AssertIsNotHandleNativeCoin**: Rejects native coins for GRC20-only functions and panics with `[GNOSWAP-COMMON-002] handle native coin is not allowed` when `unsafe.OriginSend()` is non-empty
