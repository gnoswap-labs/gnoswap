# Router

Swap routing engine for optimal trade execution across pools.

## Overview

Router handles swap execution across multiple pools, finding optimal paths and managing slippage protection for traders.

## Configuration

- **Router Fee**: 0.15% on all swaps
- **Max Hops**: 3 pools per route
- **Deadline Buffer**: 5-30 minutes recommended

## Core Functions

### `ExactInSwapRoute`
Swaps exact input amount for minimum output.
- Fixed input, variable output
- Reverts if output < amountOutMin
- Supports multi-hop routing

### `ExactOutSwapRoute`
Swaps for exact output amount with maximum input.
- Fixed output, variable input  
- Reverts if input > amountInMax
- Calculates path backwards

### `DrySwapRoute`
Simulates swap without execution.
- Frontend price quotes
- Slippage calculation
- Gas estimation
- Path validation

## Technical Details

### Route Format vs Pool Format - IMPORTANT DISTINCTION

#### Route Format (Swap Direction)
Routes in the router follow **swap direction ordering**: `tokenIn:tokenOut:fee`
- First token = Input token (what you're swapping FROM)
- Second token = Output token (what you're swapping TO)
- This represents the actual flow of the swap

Example for swapping BAR to BAZ:
```
gno.land/r/demo/bar:gno.land/r/demo/baz:3000
```

#### Pool Format (Alphabetical)
Pools are identified using **alphabetical ordering**: `token0:token1:fee`
- token0 < token1 (lexicographically sorted)
- This is the canonical pool identifier

Example pool identifier (same pool as above):
```
gno.land/r/demo/bar:gno.land/r/demo/baz:3000  # if bar < baz alphabetically
```

#### Key Difference
- **Router routes**: Follow your swap direction (BAR→BAZ means bar:baz in route)
- **Pool identifiers**: Always alphabetically sorted (might be bar:baz or baz:bar)
- The router automatically handles the conversion between these formats

#### Route String Format

Single-hop format:
```
tokenIn:tokenOut:fee
```

Multi-hop format (using *POOL* separator):
```
tokenIn:tokenB:fee1*POOL*tokenB:tokenC:fee2*POOL*tokenC:tokenOut:fee3
```

Single-hop example:
```
# Swapping BAR to BAZ
Route: gno.land/r/demo/bar:gno.land/r/demo/baz:3000
# Router interprets: tokenIn=bar, tokenOut=baz, fee=3000
```

Multi-hop example (BAR → BAZ → QUX):
```
# Each segment follows swap direction, connected by *POOL*
gno.land/r/demo/bar:gno.land/r/demo/baz:3000*POOL*gno.land/r/demo/baz:gno.land/r/demo/qux:500
```

### Quote Distribution
Split large trades across routes to minimize impact:
- `quoteArr`: Percentage per route (must sum to 100)
- Example: "30,70" = 30% route1, 70% route2

### GNOT Handling
- Auto-wraps GNOT to WUGNOT when specified
- Auto-unwraps on output if needed
- No manual wrapping required

### Slippage Protection
- Set `amountOutMin = expected * (1 - slippage%)`
- 0.5-1% for stable pairs
- 1-3% for volatile pairs
- Reverts if exceeded

## Usage

```go
// Simple exact input swap
amountIn, amountOut := ExactInSwapRoute(
    "gno.land/r/demo/bar",     // input token
    "gno.land/r/demo/baz",     // output token
    "1000000",                 // amount (6 decimals)
    "POOL,BAR,BAZ,3000",       // route
    "100",                     // 100% through route
    "950000",                  // min output
    time.Now().Unix() + 300,   // deadline
    "g1referrer...",           // referral
)

// Multi-hop swap
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
    "10000000000",
    "POOL1,USDC,WUGNOT,500:POOL2,USDC,WUGNOT,3000",
    "60,40",  // 60% through 0.05%, 40% through 0.3%
    "9500000000",
    deadline,
    "",
)
```

## Security

- Path validation prevents circular routes
- Deadline prevents stale transactions
- Slippage limits protect against MEV
- Router fees immutable per swap