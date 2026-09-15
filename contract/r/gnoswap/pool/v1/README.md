# Pool

Concentrated liquidity AMM pools with tick-based pricing.

## Overview

Pool contracts implement Uniswap V3-style concentrated liquidity, allowing LPs to provide liquidity within custom price ranges for maximum capital efficiency.

## Configuration

- **Pool Creation Fee**: 100 GNS (default)
- **Protocol Fee**: Disabled (0) or a denominator of 4-10, routing 1/4 to
  1/10 of swap fees to the protocol
- **Withdrawal Fee**: 1% on fee-bearing collection (configurable)
- **Fee Tiers**: 0.01%, 0.05%, 0.3%, 1%
- **Tick Spacing**: Auto-set by fee tier
- **Max Liquidity Per Tick**: Depends on tick spacing. Query
  `GetTickSpacing(poolPath)` through the public pool proxy; the proxy does not
  expose a max-liquidity getter, and the pool enforces the active implementation's
  spacing-specific limit during liquidity changes.

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

Deploys a new trading pair.

- Requires 100 GNS creation fee by default
- Valid fee tier required
- Accepts either token path order and canonicalizes token0/token1
- If paths are reversed, the initial square-root price is inverted
- Initial `sqrtPriceX96` must be in `[MIN_SQRT_RATIO, MAX_SQRT_RATIO)`
- Does not compare the initial price with an oracle or external market price

### `Mint`

Adds liquidity to position (called by Position contract).

- Calculates token amounts from liquidity
- Updates tick bitmap
- Transfers tokens from owner
- Returns actual amounts used

### `Burn`

Removes liquidity without collecting tokens.

- Pool-level operation: burn first, then collect owed tokens
- Calculates owed principal
- Updates position state

### `Collect`

Pays tokens owed by a pool position without a withdrawal fee. This fee-free
path is normally used for principal after `Burn`.

- Transfers the requested portion of `tokensOwed`
- Updates `tokensOwed`

### `CollectSwapFee`

Pays accrued swap fees through the fee-bearing collection path.

- Applies the configured withdrawal fee
- Returns gross collected amounts and the fee withheld
- `Position.DecreaseLiquidity` and `Position.CollectFee` invoke the appropriate
  pool paths internally

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
func swapCallback(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error
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
    caller := cur.Previous().Address()
    poolAddr := chain.PackageAddress("gno.land/r/gnoswap/pool")

    // Security check: ensure this callback is invoked by the legitimate pool
    if caller != poolAddr {
        return errors.New("unauthorized caller")
    }

    if amount0Delta > 0 {
        // Transfer token0 to pool
        common.SafeGRC20Transfer(0, cur, token0Path, poolAddr, amount0Delta)
    }
    if amount1Delta > 0 {
        // Transfer token1 to pool
        common.SafeGRC20Transfer(0, cur, token1Path, poolAddr, amount1Delta)
    }
    return nil
}
```

**Important Notes**:

- A custom callback should verify that the caller is the legitimate pool.
- In the router flow, the supplied closure performs that pool-origin check
  before calling `router.SwapCallback`; the Router implementation then checks
  that its caller is Router v1.
- The callback MUST transfer at least the positive delta amount to the pool.
- Return `nil` on success, or an error to revert the swap.
- Pool validates the balance increase after callback execution.

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

**Range Liquidity**:

Liquidity is calculated from the token required by the current price:

- Below the range (`current < lower`): token0 only
- In the range (`lower <= current < upper`): both token0 and token1
- Above the range (`current >= upper`): token1 only

The integer formulas use the square-root prices and round in the direction
required by the mint or burn operation; there is no single `amount` formula
that applies to all three cases.

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

- `0` disables protocol fee collection
- `4` through `10` are denominators: `4` routes 25% and `10` routes 10% of
  swap fees to the protocol
- Governance-managed configuration applies to the pool set, not an independent
  percentage selected on each pool

## Security

### Reentrancy Protection

- The live guard is the pool-wide `Unlocked` key in the pool KV store, managed
  by `pool/v1/lock.gno`. `Slot0.unlocked` is a separate stored field and is not
  the guard; `GetSlot0Unlocked` reports that field, not the live lock.
- The lock is not swap-specific. `CreatePool`, `Mint`, `Burn`, `Collect`,
  `CollectSwapFee`, `CollectProtocol`, `SetFeeProtocol`, `SetWithdrawalFee`,
  `SetPoolCreationFee`, `IncreaseObservationCardinalityNext`,
  `SetSwapStartHook`, `SetSwapEndHook`, `SetTickCrossHook`, `Swap`, and the
  read-only `DrySwap` all assert that the pool is unlocked before doing any
  work.
- The unlocked assertion is read-only and runs before the access checks, so a
  call that aborts on authorization leaves no persisted lock behind.
- Settlement order is operation-specific rather than uniformly
  checks-effects-interactions. `Swap` settles optimistically through the
  callback and verifies the resulting balance increase afterwards, while `Mint`
  pulls tokens before its final pool save. Review the specific path rather than
  assuming every write precedes every external call.

### Price Manipulation

- TWAP oracle provides time-weighted observations for monitoring; it is not an
  automatic initial-price guard
- Large swaps limited by liquidity
- Slippage protection required

### Pool Creation Griefing

**Issue**: `CreatePool` validates the fee tier, token canonicalization, and
square-root price bounds, but does not compare the initial price with an
oracle or external market price. A pool can therefore be created at an
economically inappropriate extreme price.

**Impact**:

- Pool may be temporarily unusable
- No rational LP may provide liquidity at a distorted price
- Price cannot self-correct without liquidity

**Recovery Mechanism**:
Recovery requires coordinated liquidity provision and swaps to move the price
toward a desired market rate, followed by liquidity removal. The protocol does
not perform this correction automatically, and profitability depends on market
conditions, fees, and slippage.

**Example Recovery Sequence**:

This pseudocode assumes the integrating realm function has a current `cur` token.

```
// Illustrative sequence; the caller must compose and execute these operations
1. position.Mint(cross(cur), ..., fullRange, largeAmount, ...)  // Add liquidity
2. router.ExactInSwapRoute(cross(cur), ..., targetRoute, ...)    // Fix price via arbitrage
3. position.DecreaseLiquidity(cross(cur), positionId, ...)       // Remove liquidity and collect principal
4. position.CollectFee(cross(cur), positionId)                   // Collect any remaining fees
```

**Prevention**:

- 100 GNS creation fee provides deterrent
- Consider implementing price oracle validation for high-value pairs
- Monitor pool creation events for suspicious activity

### Rounding

- Integer math rounds directionally for the input/output invariant; not every
  division rounds down
- Minimum liquidity enforced
- Full precision for amounts
