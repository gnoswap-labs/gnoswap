# Common Package

Package common provides shared realm utilities for GnoSwap protocol contracts.

## Overview

The common package contains shared GRC20 token queries and native coin validation.

## Key Components

1. **GRC20 Registry Helpers**: Convenient wrappers for GRC20 token queries
2. **Coin Utilities**: Native coin (GNOT) handling and validation
3. **Assertion Utilities**: Input validation and authorization checks

## API Reference

### GRC20 Registry Helpers

**Token Operations:**
- **GetToken**: Retrieves GRC20 token instance
- **IsRegistered**: Checks token registration status
- **MustRegistered**: Validates multiple tokens are registered

**Token Queries:**
- **TotalSupply**: Returns total supply of a token
- **BalanceOf**: Returns token balance for an address
- **Allowance**: Returns allowance from owner to spender

### Coin Utilities

**Coin Validation:**
- **ExistsUserSendCoins**: Checks if user sent any coins
- **AssertIsNotHandleNativeCoin**: Ensures no native coins in transaction
