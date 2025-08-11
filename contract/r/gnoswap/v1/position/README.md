# Position

NFT-based liquidity position management for concentrated liquidity.

## Overview

Each liquidity position is a unique GRC721 NFT containing:
- Pool identifier (token pair + fee tier)
- Price range (upper/lower ticks)
- Liquidity amount
- Accumulated fees
- Token balances

## Core Functions

### `Mint`
Creates new position NFT with initial liquidity.

**Key Parameters:**
- `tickLower/tickUpper`: Price range boundaries (must be tick-aligned)
- `amount0Desired/amount1Desired`: Target deposit amounts
- `amount0Min/amount1Min`: Slippage protection
- `deadline`: Transaction must execute before this timestamp

**Process:**
1. Validates tick range (lower < upper, both on grid)
2. Calculates optimal token ratio for current price
3. Mints NFT to recipient
4. Deposits tokens to pool
5. Returns actual amounts used (may differ from desired)

**Common Issues:**
- Price moved: Actual amounts differ significantly from desired
- Invalid ticks: Not aligned to tick spacing
- Zero liquidity: Amounts too small for any liquidity

### `IncreaseLiquidity`
Adds more liquidity to existing position.

**Important:** 
- Cannot change price range (use new position instead)
- Maintains same tick boundaries
- Pro-rata token amounts based on current price

### `DecreaseLiquidity`
Removes liquidity but keeps position NFT.

**Two-step process:**
1. Decrease: Removes liquidity, calculates owed tokens
2. Collect: Claims tokens (separate transaction)

### `CollectFee`
Claims accumulated swap fees without removing liquidity.

**Fee Calculation:**
```
fees = liquidity * (feeGrowthInside - feeGrowthInsideLast)
```

**Withdrawal Fee:**
- 1% protocol fee on collected amounts
- Sent to protocol fee contract
- Applied before transfer to user

### `Reposition`
Atomic operation to move liquidity to new price range.

**When to reposition:**
- Price moved far outside range
- Optimize for new price regime
- Consolidate multiple positions

**Process:**
1. Burns old position entirely
2. Creates new position with same tokens
3. Transfers any leftover tokens
4. Burns old NFT, mints new NFT

## Price Range Selection

### Tick Alignment
Ticks must align with pool's tick spacing:
- 0.01% fee: every 1 tick
- 0.05% fee: every 10 ticks  
- 0.3% fee: every 60 ticks
- 1% fee: every 200 ticks

Example for 0.3% pool:
```
Valid: -1200, -1140, -1080, 0, 60, 120
Invalid: -1150, -1100, 50, 75
```

### Optimal Range Width

**Stable Pairs (USDC/USDT):**
- Narrow: ±0.05% (max capital efficiency)
- Medium: ±0.1% (balanced)
- Wide: ±0.5% (safety buffer)

**Correlated Pairs (WETH/stETH):**
- Narrow: ±0.5%
- Medium: ±1%
- Wide: ±2%

**Volatile Pairs (WETH/USDC):**
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

## Token Amount Calculations

### Single-Sided Deposits

**Below range (token1 only):**
```
amount1 = L * (sqrtUpper - sqrtLower)
amount0 = 0
```

**Above range (token0 only):**
```
amount0 = L * (sqrtUpper - sqrtLower) / (sqrtUpper * sqrtLower)
amount1 = 0
```

**In range (both tokens):**
```
amount0 = L * (sqrtUpper - sqrtCurrent) / (sqrtUpper * sqrtCurrent)
amount1 = L * (sqrtCurrent - sqrtLower)
```

### Liquidity from Amounts

Given desired token amounts, calculate max liquidity:
```
L0 = amount0 * (sqrtUpper * sqrtCurrent) / (sqrtUpper - sqrtCurrent)
L1 = amount1 / (sqrtCurrent - sqrtLower)
L = min(L0, L1)
```

## NFT Metadata

Each position NFT stores:
```json
{
  "tokenId": 12345,
  "pool": "WETH/USDC 0.3%",
  "tickLower": -887220,
  "tickUpper": 887220,
  "liquidity": "1000000000000000000",
  "token0": "0.5 WETH",
  "token1": "1000 USDC"
}
```

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Withdrawal Fee**: 1% (default) on collected fees
- **Max Position Size**: No limit by default
- **Position Transfer Restrictions**: None (fully transferable NFTs)