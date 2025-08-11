# Pool

Concentrated liquidity AMM pools with tick-based pricing.

## Core Concepts

### Concentrated Liquidity
Liquidity providers concentrate capital within custom price ranges instead of 0-∞. This increases capital efficiency by 4000x+ for stable pairs.

### Tick System
- Price space divided into discrete ticks (0.01% apart)
- Each tick represents ~0.01% price change
- Positions defined by upper/lower tick boundaries
- Liquidity activated only when price in range

## Key Functions

### `CreatePool`
Deploys new trading pair. Requirements:
- 100 GNS creation fee (prevents spam)
- Valid fee tier (100, 500, 3000, 10000 = 0.01%, 0.05%, 0.3%, 1%)
- Initial price via sqrtPriceX96 (see price math below)
- Token pair must not exist at that fee tier

### `Mint`
Adds liquidity to position. Called by Position contract, not directly.
- Calculates token amounts from liquidity amount
- Updates tick bitmap for efficient traversal
- Transfers tokens from position owner
- Returns actual amounts used (may differ slightly due to rounding)

### `Burn`
Removes liquidity but doesn't collect tokens. Two-step process:
1. Burn: Removes liquidity, calculates owed amounts
2. Collect: Transfers tokens to recipient

### `Collect`
Claims tokens from burned position + accumulated fees.
- Transfers both principal and fees
- Updates position's tokensOwed
- Applies withdrawal fee (1% default)

### `Swap`
Core swap execution. Called by Router, not directly.
- Iterates through ticks until amount satisfied
- Updates price and liquidity at each tick
- Calculates fees per liquidity unit
- Maintains price oracle (TWAP)

## Price Math

### Q96 Format
Prices stored as `sqrtPriceX96 = sqrt(price) * 2^96`

Example conversions:
```
Price 1:1     → sqrtPriceX96 = 79228162514264337593543950336
Price 1:4     → sqrtPriceX96 = 39614081257132168796771975168  
Price 100:1   → sqrtPriceX96 = 792281625142643375935439503360
```

### Tick to Price
```
price = 1.0001^tick
tick 0     = price 1
tick 6932  = price ~2
tick -6932 = price ~0.5
```

## Liquidity Math

### Range Liquidity Formula
For range [tickLower, tickUpper]:
```
L = amount / (sqrt(upper) - sqrt(lower))        // if current < lower
L = amount * sqrt(current) / (upper - current)   // if lower < current < upper  
L = amount / (sqrt(current) - sqrt(lower))      // if current > upper
```

### Impermanent Loss
Concentrated positions experience amplified IL:
- Narrow range: Higher fees but higher IL
- Wide range: Lower fees but lower IL
- Stable pairs: Use ±0.1% ranges
- Volatile pairs: Use ±10% or wider

## Fee Mechanics

### Swap Fees
- Charged on input amount
- Accumulates as `feeGrowthGlobal`
- Distributed pro-rata to in-range liquidity

### Fee Calculation
```
fees = feeGrowthInside * liquidity
feeGrowthInside = feeGrowthGlobal - feeGrowthOutside
```

### Protocol Fees
- Optional protocol take (0-10% of swap fees)
- Configurable per pool
- Sent to protocol fee contract

## Security Considerations

### Reentrancy Protection
- Pools lock during swaps (`slot0.unlocked`)
- External calls only after state updates
- Follow checks-effects-interactions

### Price Manipulation
- TWAP oracle resists single-block manipulation
- Large swaps limited by liquidity
- Sandwich protection via slippage limits

### Rounding
- All division rounds down (favors protocol)
- Minimum liquidity prevents rounding attacks
- Token amounts use full precision

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Pool Creation Fee**: 100 GNS (default)
- **Protocol Fee**: 0-10% of swap fees per token
- **Withdrawal Fee**: 1% (default) on collected fees
- **Fee Tiers**: 0.01%, 0.05%, 0.3%, 1% available
- **Tick Spacing**: Automatically set based on fee tier
- **Max Liquidity Per Tick**: 2^128 - 1