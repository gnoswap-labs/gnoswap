# Common Package

Package common provides shared realm utilities for GnoSwap protocol contracts.

## Overview

The common package contains helpers that must keep a realm boundary, including GRC20 token operations and native coin validation.

## Key Components

1. **GRC20 Registry Helpers**: Convenient wrappers for GRC20 token operations
2. **Coin Utilities**: Native coin (GNOT) handling and validation
3. **Assertion Utilities**: Input validation and authorization checks

## API Reference

### GRC20 Registry Helpers

The write helpers are crossing adapters and should be called as
`common.Transfer(cross(cur), ...)`, `common.SafeGRC20Transfer(cross(cur), ...)`,
and so on. They intentionally keep `cur realm` as the first parameter so the
helper runs in common's crossing frame, then forward that live `cur` to
`grc20.Teller` as `Transfer(0, cur, ...)`. Because `GetTokenTeller` returns a
`CallerTeller`, the token actor is derived from `cur.Previous()`, which is the
realm that crossed into common. Do not convert these helpers to
`_ int, rlm realm`; that would remove the common crossing boundary and change
which realm `CallerTeller` treats as the actor.

**Token Operations:**
- **GetToken**: Retrieves GRC20 token instance
- **GetTokenTeller**: Gets a CallerTeller for token operations
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
