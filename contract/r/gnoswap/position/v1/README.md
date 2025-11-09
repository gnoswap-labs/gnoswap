# Position

NFT-based liquidity position management for concentrated liquidity.

## Overview

Each liquidity position is a unique GRC721 NFT containing pool identifier, price range, liquidity amount, accumulated fees, and token balances.

## Configuration

- **Withdrawal Fee**: 1% on collected fees
- **Max Position Size**: No limit
- **Transfer Restrictions**: Non-transferable NFTs

## Core Functions

### `Mint`

Creates new position NFT with initial liquidity.

- Validates tick range alignment
- Calculates optimal token ratio
- Returns actual amounts used

### `IncreaseLiquidity`

Adds liquidity to existing position.

- Maintains same price range
- Pro-rata token amounts

### `DecreaseLiquidity`

Removes liquidity while keeping NFT.

- Two-step: decrease then collect
- Calculates owed tokens

### `CollectFee`

Claims accumulated swap fees.

- No liquidity removal required
- 1% protocol fees applied

### `Reposition`

Atomically moves liquidity to new range.

- Burns old position
- Creates new position
- Mints new NFT

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

**Below range (token1 only)**:

```
amount1 = L * (sqrtUpper - sqrtLower)
amount0 = 0
```

**Above range (token0 only)**:

```
amount0 = L * (sqrtUpper - sqrtLower) / (sqrtUpper * sqrtLower)
amount1 = 0
```

**In range (both tokens)**:

```
amount0 = L * (sqrtUpper - sqrtCurrent) / (sqrtUpper * sqrtCurrent)
amount1 = L * (sqrtCurrent - sqrtLower)
```

## Usage

```go
// Mint new position
tokenId := Mint(
    "WETH/USDC:3000",  // pool
    -887220,           // tickLower
    887220,            // tickUpper
    "1000000",         // amount0Desired
    "2000000000",      // amount1Desired
    "950000",          // amount0Min
    "1900000000",      // amount1Min
    deadline,
    recipient,
)

// Add liquidity
IncreaseLiquidity(
    tokenId,
    "500000",
    "1000000000",
    "475000",
    "950000000",
    deadline,
)

// Collect fees
CollectFee(tokenId)
```

## Security

- Tick range validation prevents invalid positions
- Slippage protection on all operations
- Deadline prevents stale transactions
- Position NFTs are non-transferable
- Only owner can manage their positions
