# Pool

Concentrated liquidity AMM pools with tick-based pricing.

## Overview

Pool contracts implement Uniswap V3-style concentrated liquidity, allowing LPs to provide liquidity within custom price ranges for maximum capital efficiency.

## Configuration

- **Pool Creation Fee**: 100 GNS (default)
- **Protocol Fee**: 0-10% of swap fees per token
- **Withdrawal Fee**: 1% on collected fees
- **Fee Tiers**: 0.01%, 0.05%, 0.3%, 1%
- **Tick Spacing**: Auto-set by fee tier
- **Max Liquidity Per Tick**: 2^128 - 1

## Core Concepts

### Concentrated Liquidity
Liquidity providers concentrate capital within custom price ranges instead of 0-∞. This allows LPs to allocate capital where it's most likely to generate fees - near the current price for volatile pairs, or within tight ranges for stable pairs. Capital efficiency can improve by orders of magnitude depending on range selection and pair volatility. For more details, check out [GnoSwap Docs](https://docs.gnoswap.io/core-concepts/amm/concentrated-liquidity).

### Tick System
- Price space divided into discrete ticks (0.01% apart)
- Each tick represents ~0.01% price change
- Positions defined by upper/lower tick boundaries
- Liquidity activated only when price in range

## Key Functions

### `CreatePool`
Deploys new trading pair.
- Requires 100 GNS creation fee
- Valid fee tier required
- Initial price via sqrtPriceX96
- Unique token pair per fee tier

### `Mint`
Adds liquidity to position (called by Position contract).
- Calculates token amounts from liquidity
- Updates tick bitmap
- Transfers tokens from owner
- Returns actual amounts used

### `Burn`
Removes liquidity without collecting tokens.
- Two-step: burn then collect
- Calculates owed amounts
- Updates position state

### `Collect`
Claims tokens from burned position + fees.
- Transfers principal and fees
- Updates tokensOwed
- Applies withdrawal fee

### `Swap`
Core swap execution (called by Router).
- Iterates through ticks
- Updates price and liquidity
- Calculates fees
- Maintains TWAP oracle

## Technical Details

### Price Math

**Q96 Format**: Prices stored as `sqrtPriceX96 = sqrt(price) * 2^96`

```
Price 1:1   → sqrtPriceX96 = 79228162514264337593543950336
Price 1:4   → sqrtPriceX96 = 39614081257132168796771975168  
Price 100:1 → sqrtPriceX96 = 792281625142643375935439503360
```

**Tick to Price**: `price = 1.0001^tick`
```
tick 0     = price 1
tick 6932  = price ~2
tick -6932 = price ~0.5
```

### Liquidity Math

**Range Liquidity Formula**:
```
L = amount / (sqrt(upper) - sqrt(lower))        // current < lower
L = amount * sqrt(current) / (upper - current)  // lower < current < upper  
L = amount / (sqrt(current) - sqrt(lower))      // current > upper
```

**Impermanent Loss**:
- Narrow range: Higher fees, higher IL
- Wide range: Lower fees, lower IL
- Stable pairs: ±0.1% ranges optimal
- Volatile pairs: ±10%+ ranges recommended

### Fee Mechanics

**Swap Fees**:
- Charged on input amount
- Accumulates as feeGrowthGlobal
- Distributed pro-rata to in-range liquidity

**Fee Calculation**:
```
fees = feeGrowthInside * liquidity
feeGrowthInside = feeGrowthGlobal - feeGrowthOutside
```

**Protocol fees**:
- Optional 0-10% of swap fees
- Configurable per pool
- Sent to protocol fee contract

## Security

### Reentrancy Protection
- Pools lock during swaps (`slot0.unlocked`)
- External calls after state updates
- Checks-effects-interactions pattern

### Price Manipulation
- TWAP oracle resists manipulation
- Large swaps limited by liquidity
- Slippage protection required

### Rounding
- Division rounds down (favors protocol)
- Minimum liquidity enforced
- Full precision for amounts