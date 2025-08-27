# GNS

GnoSwap governance and utility token.

## Overview

GNS is the native governance token of GnoSwap, featuring a deflationary emission schedule with halvings every 2 years over 12 years total.

## Token Economics

- **Symbol**: GNS
- **Decimals**: 6
- **Max Supply**: 1,000,000,000 GNS
- **Initial Mint**: 100,000,000 GNS
- **Total Emission**: 900,000,000 GNS over 12 years

## Emission Schedule

| Years | Annual Emission | Rate |
|-------|----------------|------|
| 1-2   | 225,000,000    | 100% |
| 3-4   | 112,500,000    | 50%  |
| 5-6   | 56,250,000     | 25%  |
| 7-8   | 28,125,000     | 12.5%|
| 9-12  | 14,062,500     | 6.25%|

## Core Functions

### `Transfer`
Transfers tokens between addresses.

### `TransferFrom`
Transfers with allowance.

### `Approve`
Approves spending allowance.

### `MintGns`
Mints new tokens per emission schedule.

### `Burn`
Burns tokens from supply.

## Usage

```go
// Transfer tokens
Transfer(to, amount)

// Approve and transfer
Approve(spender, amount)
TransferFrom(from, to, amount)

// Mint per emission schedule
MintGns()
```

## Distribution

See [emission contract](../emission) for distribution details.