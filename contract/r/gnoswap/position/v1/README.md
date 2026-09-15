# Position

NFT-based liquidity position management for concentrated liquidity.

## Overview

Each liquidity position is a unique GRC721 NFT. Stored state includes the pool
key, price range, liquidity, fee-growth checkpoints, tokens owed, burned marker,
and operator. Current token balances are derived from the current pool price,
range, and liquidity; they are not permanently stored balances.

The pool accounting key encodes only the lower/upper tick pair and is scoped by
pool. NFTs with the same range in one pool share the pool-level accounting entry.

## Configuration

- **Withdrawal Fee**: 1% by default on fee-bearing swap-fee collection
- **Max Position Size**: No separate position-level cap; pool tick limits apply
- **Transfers**: Unstaked NFTs follow GRC721 owner/approval/operator rules;
  staked NFTs are locked to staker-mediated transfers

## Core Functions

### `Mint`

Creates new position NFT with initial liquidity.

- Validates tick range alignment
- Calculates optimal token ratio
- Returns actual amounts used

### `IncreaseLiquidity`

Adds liquidity to an existing position.

- Maintains the existing price range
- Uses the current-price token ratio
- Can clear a burned marker when the position is used again

### `DecreaseLiquidity`

Removes liquidity while keeping the NFT.

- One atomic public operation: internally collects swap fees, burns liquidity,
  then collects principal through the pool's fee-free `Collect` path
- Returns fee amounts net of the withdrawal fee and collected principal
- Amount-minimum checks apply to the principal actually collected

### `CollectFee`

Claims accumulated swap fees without removing liquidity.

- No liquidity removal required
- Returns net collected amounts plus the raw pre-withdrawal-fee amounts
- The configured withdrawal fee applies only to this fee-bearing path

### `Reposition`

Updates an existing position's price range.

- Requires the position to be clear first (zero liquidity and tokens owed)
- Reuses the same position ID and NFT
- Adds new liquidity to the updated range and clears the burned marker

## Technical Details

### Tick Alignment

Ticks must align with pool's tick spacing:

```
0.01% fee: every 1 tick
0.05% fee: every 10 ticks
0.3% fee: every 60 ticks
1% fee: every 200 ticks
```

### Optimal Range Width

**Stable Pairs (USDC/USDT)**:

- Narrow: ±0.05% (max efficiency)
- Medium: ±0.1% (balanced)
- Wide: ±0.5% (safety)

**Correlated Pairs (WETH/stETH)**:

- Narrow: ±0.5%
- Medium: ±1%
- Wide: ±2%

**Volatile Pairs (WETH/USDC)**:

- Narrow: ±5%
- Medium: ±10%
- Wide: ±25%

### Capital Efficiency

Concentration factor vs infinite range:

```
Range ±0.1%  → 2000x efficient
Range ±1%    → 200x efficient
Range ±10%   → 20x efficient
Range ±50%   → 4x efficient
```

### Token Calculations

For liquidity `L` and square-root prices `sqrtLower`, `sqrtCurrent`, and
`sqrtUpper`:

**Below range (`current < lower`, token0 only)**:

```
amount0 = L * (sqrtUpper - sqrtLower) / (sqrtUpper * sqrtLower)
amount1 = 0
```

**In range (`lower <= current < upper`, both tokens)**:

```
amount0 = L * (sqrtUpper - sqrtCurrent) / (sqrtUpper * sqrtCurrent)
amount1 = L * (sqrtCurrent - sqrtLower)
```

**Above range (`current >= upper`, token1 only)**:

```
amount0 = 0
amount1 = L * (sqrtUpper - sqrtLower)
```

## Usage

```go
// Mint a new position through the domain proxy
tokenId, liquidity, amount0, amount1 := Mint(
    cross,
    "gno.land/r/onbloc/weth",  // token0
    "gno.land/r/gnoswap/test_token/test_usdc",  // token1
    3000,                      // fee
    -887220,                   // tickLower
    887220,                    // tickUpper
    "1000000",                 // amount0Desired
    "2000000000",              // amount1Desired
    "950000",                  // amount0Min
    "1900000000",              // amount1Min
    deadline,
    recipient,                 // mintTo
    "",                        // referrer
)

// Add liquidity
positionId, liquidity, amount0, amount1, poolPath := IncreaseLiquidity(
    cross,
    tokenId,
    "500000",
    "1000000000",
    "475000",
    "950000000",
    deadline,
)

// Collect swap fees
positionId, collected0, collected1, poolPath, rawAmount0, rawAmount1 := CollectFee(
    cross,
    tokenId,
)

// Reposition to a new range (requires a clear position)
positionId, liquidity, tickLower, tickUpper, amount0, amount1 := Reposition(
    cross,
    tokenId,
    -443610,                   // new tickLower
    443610,                    // new tickUpper
    "1000000",                 // amount0Desired
    "2000000000",              // amount1Desired
    "950000",                  // amount0Min
    "1900000000",              // amount1Min
    deadline,
)
```

## Lifecycle

A full decrease that leaves zero liquidity and zero tokens owed sets the
`burned` marker but does not destroy the NFT. `IncreaseLiquidity` and
`Reposition` clear the marker when the position is used again; the marker does
not by itself block an increase.

## Security

- Tick range validation prevents invalid positions
- Slippage protection applies to liquidity-changing operations; fee collection
  has no amount-minimum parameter
- Deadlines prevent stale liquidity-changing transactions
- Unstaked NFTs follow standard GRC721 transfer authorization; staked NFTs
  can move only through staker-mediated flows
- Liquidity changes and repositioning require the owner; fee collection also
  permits the position's approved operator where applicable
