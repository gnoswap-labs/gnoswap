# Pool

Concentrated liquidity AMM pools with tick-based pricing.

## Overview

Pool contracts implement Uniswap V3-style concentrated liquidity, allowing LPs to provide liquidity within custom price ranges for maximum capital efficiency.

## Configuration

- **Pool Creation Fee**: 100 GNS (default)
- **Protocol Fee**: Disabled (0) or 1/4 to 1/10 of swap fees (denominator: 4-10)
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
- **Note**: No price validation performed (see Security Considerations)

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

#### Swap Callback

The `Swap` function uses a callback pattern for token transfers, following the Uniswap V3 flash swap design.

**Callback Signature**:

```go
func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error
```

**Delta Convention**:
| Delta | Meaning |
|-------|---------|
| Positive (`> 0`) | Amount the pool must RECEIVE (input token) |
| Negative (`< 0`) | Amount the pool has SENT (output token) |

**Swap Direction Examples**:

For `zeroForOne = true` (token0 → token1):

- `amount0Delta > 0`: Pool receives token0 (input)
- `amount1Delta < 0`: Pool sends token1 (output)

For `zeroForOne = false` (token1 → token0):

- `amount0Delta < 0`: Pool sends token0 (output)
- `amount1Delta > 0`: Pool receives token1 (input)

**Callback Implementation Example**:

```go
func swapCallback(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
    caller := runtime.PreviousRealm().Address()
    poolAddr := chain.PackageAddress("gno.land/r/gnoswap/pool")

    // Security check: ensure this callback is invoked by the legitimate pool
    if caller != poolAddr {
        return errors.New("unauthorized caller")
    }

    if amount0Delta > 0 {
        // Transfer token0 to pool
        common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
    }
    if amount1Delta > 0 {
        // Transfer token1 to pool
        common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
    }
    return nil
}
```

**Important Notes**:

- It is recommended that the callback verify the caller is the legitimate pool to prevent unauthorized invocations
- The callback MUST transfer at least the positive delta amount to the pool
- Return `nil` on success, or an error to revert the swap
- Pool validates balance increase after callback execution

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

- Optional 0% or 4-10% of swap fees
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

### Pool Creation Griefing

**Issue**: CreatePool allows arbitrary initial prices without validation, enabling griefing attacks where pools are created at extreme prices (e.g., 1 GNO = 0.000001 USDC).

**Impact**:

- Pool becomes temporarily unusable
- No rational LP will provide liquidity at distorted prices
- Price cannot self-correct without liquidity

**Recovery Mechanism**:
Griefed pools can be restored through an atomic transaction:

1. **Add Liquidity**: Provide wide-range liquidity at the distorted price
2. **Execute Swap**: Trade to move price toward market rate
3. **Remove Liquidity**: Withdraw the provided liquidity

The executor acts as both LP (losing value to slippage) and arbitrageur (gaining from price correction). These effects largely cancel out, with only gas and protocol fees as net cost.

**Example Recovery Transaction**:

```
// Atomic recovery for griefed pool
1. position.Mint(fullRange, largeAmount)  // Add liquidity
2. router.Swap(correctPrice)               // Fix price via arbitrage
3. position.Burn(positionId)               // Remove liquidity
4. position.Collect(positionId)            // Collect tokens
```

**Prevention**:

- 100 GNS creation fee provides deterrent
- Consider implementing price oracle validation for high-value pairs
- Monitor pool creation events for suspicious activity

### Rounding

- Division rounds down (favors protocol)
- Minimum liquidity enforced
- Full precision for amounts
