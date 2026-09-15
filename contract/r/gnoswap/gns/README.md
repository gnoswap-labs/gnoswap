# GNS

GnoSwap governance and utility token.

## Overview

GNS is the native governance token of GnoSwap, featuring a deflationary emission schedule with halvings every 2 years over 12 years total.

## Token Economics

- **Symbol**: GNS
- **Decimals**: 6
- **Max Supply**: 1,000,000,000 GNS
- **Initial Mint**: 100,000,000 GNS, pre-minted to the configured `ADMIN`
  role address during GNS realm initialization
- **Total Emission**: 900,000,000 GNS over 12 years

## Emission Schedule

| Years | Annual Emission | Rate  |
| ----- | --------------- | ----- |
| 1-2   | 225,000,000     | 100%  |
| 3-4   | 112,500,000     | 50%   |
| 5-6   | 56,250,000      | 25%   |
| 7-8   | 28,125,000      | 12.5% |
| 9-12  | 14,062,500      | 6.25% |

## Core Functions

### `Transfer`

Transfers tokens between addresses.

### `TransferFrom`

Transfers with allowance.

### `Approve`

Approves spending allowance.

### `InitEmissionState`

Initializes the emission schedule with start height and timestamp.
Sets up the 12-year emission schedule with halving periods.
Only callable by emission contract.

### `MintGns`

Mints new tokens per emission schedule. Only callable by emission contract.
Calculates tokens to mint based on elapsed time and updates halving year state.

## Usage

These snippets call the GNS realm from a realm function with a current `cur`
token. Import the package and qualify its function names in integrating code.

```go
// Transfer tokens
Transfer(cross(cur), to, amount)

// Approve and transfer
Approve(cross(cur), spender, amount)
TransferFrom(cross(cur), from, to, amount)

// Mint per emission schedule (called by emission contract)
MintGns(cross(cur), recipientAddress)
```

## Distribution

See [emission contract](../emission) for distribution details.
