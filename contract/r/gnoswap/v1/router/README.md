# Router

Swap routing engine for optimal trade execution across pools.

## Core Functions

### `ExactInSwapRoute`
Swaps exact input amount for minimum output. Best for when you know exactly how much you want to spend.
- Input amount is fixed, output varies with price
- Reverts if output < `amountOutMin` (slippage protection)
- Supports multi-hop routing through multiple pools

### `ExactOutSwapRoute`
Swaps for exact output amount with maximum input. Best for when you need exactly X tokens.
- Output amount is fixed, input varies with price
- Reverts if input > `amountInMax` (slippage protection)
- Calculates optimal path backwards from output

### `DrySwapRoute`
Simulates swap without execution. Essential for:
- Frontend price quotes
- Slippage calculation
- Gas estimation
- Path validation

## Route Format

Routes encode the swap path as a colon-separated string:
```
POOL_PATH,TOKEN0,TOKEN1,FEE:NEXT_POOL...
```

Example single-hop:
```
gno.land/r/demo/bar:gno.land/r/demo/baz:3000,BAR,BAZ,3000
```

Example multi-hop (BAR → BAZ → QUX):
```
POOL1,BAR,BAZ,3000:POOL2,BAZ,QUX,500
```

## Quote Distribution

For large trades, split across multiple routes to minimize price impact:
- `quoteArr`: Percentage allocation per route (must sum to 100)
- Example: "30,70" sends 30% through route1, 70% through route2

## Technical Details

### Path Finding
Router doesn't auto-calculate paths. Frontend must:
1. Query available pools via pool package
2. Calculate optimal route considering liquidity/fees
3. Encode route string properly

### GNOT Handling
- Auto-wraps GNOT to WUGNOT when "gnot" specified
- Auto-unwraps on output if recipient expects GNOT
- No manual wrapping needed

### Slippage Protection
- Set `amountOutMin` = expected * (1 - slippage%)
- Typically 0.5-1% for stable pairs, 1-3% for volatile
- Transaction reverts if slippage exceeded

### Fee Structure
- Pool fees: 0.01%, 0.05%, 0.3%, 1% tiers
- Protocol fee: 0.15% additional on swaps
- Fees auto-deducted from input amount

## Usage Examples

```go
// Simple exact input swap
amountIn, amountOut := ExactInSwapRoute(
    "gno.land/r/demo/bar",     // input token
    "gno.land/r/demo/baz",     // output token
    "1000000",                 // 1 BAR (6 decimals)
    "POOL,BAR,BAZ,3000",       // route through 0.3% pool
    "100",                     // 100% through this route
    "950000",                  // min 0.95 BAZ expected
    time.Now().Unix() + 300,   // 5 min deadline
    "g1referrer...",           // referral address
)

// Multi-hop swap (BAR → WUGNOT → BAZ)
ExactInSwapRoute(
    "gno.land/r/demo/bar",
    "gno.land/r/demo/baz",
    "1000000",
    "POOL1,BAR,WUGNOT,3000:POOL2,WUGNOT,BAZ,3000",
    "100",
    "900000",
    deadline,
    "",
)

// Split route for large trades
ExactInSwapRoute(
    "gno.land/r/demo/usdc",
    "gnot",
    "10000000000",  // 10k USDC
    "POOL1,USDC,WUGNOT,500:POOL2,USDC,WUGNOT,3000",
    "60,40",        // 60% through 0.05% pool, 40% through 0.3%
    "9500000000",
    deadline,
    "",
)
```

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Protocol Fee**: 0.15% (default) - additional fee on all swaps
- **Max Hops**: 7 (default) - maximum pools per route
- **Deadline Buffer**: Recommended 5-30 minutes