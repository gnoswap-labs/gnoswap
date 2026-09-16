# Router

Swap routing engine for optimal trade execution across pools.

## Overview

Router handles swap execution across multiple pools, finding optimal paths and managing slippage protection for traders.

## Configuration

- **Router Fee**: 15 bps (0.15%) by default on output tokens; configurable by
  admin/governance from 0 through 1000 bps (0–10%)
- **Max Hops**: 3 pools per route
- **Deadline Buffer**: 5-30 minutes recommended for live swaps

## Core Functions

### `ExactInSwapRoute`

Swaps an exact input amount for output, subject to a minimum net output.

- Fixed input, variable output
- The returned output is after the router fee
- Reverts if output < amountOutMin
- Supports multi-hop routing

### `ExactOutSwapRoute`

Swaps for a requested final user output amount with maximum input. The
`amountOut` target is post-router-fee: the router requests the corresponding
gross pool output, deducts the fee, then validates and transfers the net output.

- With no single-hop price limit, targets the requested post-fee output within
  the implementation's small per-hop rounding tolerance
- A nonzero single-hop price limit may stop early and return a partial output
- Reverts if input > amountInMax
- Calculates path backwards

### `DrySwapRoute`

Simulates a swap without execution.

- Frontend price quotes
- Slippage calculation
- Path validation
- No deadline check or token transfer

## Technical Details

### Route Format vs Pool Format - IMPORTANT DISTINCTION

#### Route Format (Swap Direction)

Routes in the router follow **swap direction ordering**: `tokenIn:tokenOut:fee`

- First token = Input token (what you're swapping FROM)
- Second token = Output token (what you're swapping TO)
- This represents the actual flow of the swap

Example for swapping GNS to WUGNOT:

```
gno.land/r/gnoswap/gns.GNS:gno.land/r/gnoland/wugnot.wugnot:3000
```

#### Pool Format (Alphabetical)

Pools are identified using **alphabetical ordering**: `token0:token1:fee`

- token0 < token1 (lexicographically sorted)
- This is the canonical pool identifier

Example pool identifier (same pool as above):

```
gno.land/r/gnoland/wugnot.wugnot:gno.land/r/gnoswap/gns.GNS:3000  # gnoland/wugnot < gnoswap/gns alphabetically
```

#### Key Difference

- **Router routes**: Follow your swap direction (BAR→BAZ means bar:baz in route)
- **Pool identifiers**: Always alphabetically sorted (might be bar:baz or baz:bar)
- The router automatically handles the conversion between these formats

#### Native Token Route Specification

**IMPORTANT**: Router swap functions do **not** accept native `ugnot` directly.

- **Token Parameters**: Use token keys (`pkgPath.SYMBOL`) such as `"gno.land/r/gnoland/wugnot.wugnot"`
- **Route Paths**: Also use token keys (`pkgPath.SYMBOL`) such as `"gno.land/r/gnoland/wugnot.wugnot"`

This matches the current implementation:

- Pools operate on token contract paths, including wrapped GNOT (`wugnot`)
- Router swap entrypoints reject native-coin handling
- Native-token refund and unwrap flows are not part of the current router implementation

#### Route String Format

Single-hop format:

```
tokenIn:tokenOut:fee
```

Multi-hop format (using _POOL_ separator):

```
tokenIn:tokenB:fee1*POOL*tokenB:tokenC:fee2*POOL*tokenC:tokenOut:fee3
```

Single-hop example:

```
# Swapping GNS to WUGNOT
Route: gno.land/r/gnoswap/gns.GNS:gno.land/r/gnoland/wugnot.wugnot:3000
# Router interprets: tokenIn=gns, tokenOut=wugnot, fee=3000
```

Multi-hop example (GNS → WUGNOT → TOKEN_C):

```
# Each segment follows swap direction, connected by *POOL*
gno.land/r/gnoswap/gns.GNS:gno.land/r/gnoland/wugnot.wugnot:3000*POOL*gno.land/r/gnoland/wugnot.wugnot:gno.land/r/<namespace>/token_c.TOKEN_C:500
```

### Quote Distribution

Split large trades across routes to minimize impact:

- `quoteArr`: positive percentage per route, with one quote for each route
- Quotes must sum to 100; at most 7 routes are accepted
- Example: "30,70" = 30% route1, 70% route2

### Native Token Handling

The current router implementation does **not** handle native `ugnot` directly. It rejects native-coin handling and routes swaps only through token keys (`pkgPath.SYMBOL`) such as wrapped GNOT (`wugnot`).

#### Token Identifier Requirements

- Use token keys (`pkgPath.SYMBOL`) such as `gno.land/r/gnoland/wugnot.wugnot` for both inputs/outputs and route specifications.
- Do not pass `"ugnot"` as `inputToken` or `outputToken` to router swap functions.

#### Approval and Transfer Requirements

- Approve the router to spend the token contract you are swapping from.
- If you want wrapped GNOT exposure, use the `wugnot` token contract path directly.
- Native-token refund and unwrap flows are not part of the current router implementation.

For live liquidity-changing swaps:

- Set `amountOutMin = expected * (1 - slippage%)`
- 0.5-1% for stable pairs
- 1-3% for volatile pairs
- Reverts if the net output is below the minimum

## Usage

These snippets call the public domain proxy from a realm function with a current `cur` token.
Import the proxy package and qualify its function names in integrating code.

### Basic Token Swaps

```go
// Simple exact input swap
amountIn, amountOut := ExactInSwapRoute(
    cross(cur),
    "gno.land/r/gnoswap/gns.GNS",       // input token
    "gno.land/r/gnoland/wugnot.wugnot", // output token
    "1000000",                 // amount (6 decimals)
    "gno.land/r/gnoswap/gns.GNS:gno.land/r/gnoland/wugnot.wugnot:3000", // route
    "100",                     // 100% through route
    "950000",                  // min output
    time.Now().Unix() + 300,   // deadline
    "g1referrer...",           // referral
)

// Multi-hop swap
ExactInSwapRoute(
    cross(cur),
    "gno.land/r/gnoswap/gns.GNS",
    "gno.land/r/<namespace>/token_c.TOKEN_C",
    "1000000",
    "gno.land/r/gnoswap/gns.GNS:gno.land/r/gnoland/wugnot.wugnot:3000*POOL*gno.land/r/gnoland/wugnot.wugnot:gno.land/r/<namespace>/token_c.TOKEN_C:3000",
    "100",
    "900000",
    deadline,
    "",
)

// Split route for large trades
ExactInSwapRoute(
    cross(cur),
    "gno.land/r/gnoswap/gns.GNS",
    "gno.land/r/gnoland/wugnot.wugnot",
    "10000000000",
    "gno.land/r/gnoswap/gns.GNS:gno.land/r/gnoland/wugnot.wugnot:500,gno.land/r/gnoswap/gns.GNS:gno.land/r/gnoland/wugnot.wugnot:3000",
    "60,40",  // 60% through 0.05%, 40% through 0.3%
    "9500000000",
    deadline,
    "",
)
```

Single-hop functions support partial execution through a nonzero
`sqrtPriceLimitX96`:

```go
// Partial swap with price limit - may not consume full input amount
amountIn, amountOut := ExactInSingleSwapRoute(
    cross(cur),
    "gno.land/r/gnoswap/gns.GNS",       // input token
    "gno.land/r/gnoland/wugnot.wugnot", // output token
    "1000000",                 // max amount to swap
    "gno.land/r/gnoswap/gns.GNS:gno.land/r/gnoland/wugnot.wugnot:3000", // single route
    "950000",                  // min output
    "1000000000000000000",     // sqrtPriceLimitX96 (price limit)
    deadline,
    "",
)
// If the price limit is reached, only a partial amount is swapped. For exact-in
// this can consume less input; exact-out can deliver less than its target.
// amountOutMin or amountInMax remains enforced, respectively.
```

## Important Developer Notes

### Common Integration Pitfalls

1. **Native Token Assumptions**: Passing `"ugnot"` to router swap functions will fail because router entrypoints reject native-coin handling.

2. **Route vs Token Identifier Confusion**: Using `"ugnot"` in route strings instead of `"gno.land/r/gnoland/wugnot.wugnot"` will cause transactions to fail since no pools exist for the `"ugnot"` identifier.

3. **Wrong Token Path**:

   - Use `gno.land/r/gnoland/wugnot.wugnot` when swapping wrapped GNOT
   - Do not pass native `ugnot` to router swap functions
   - Route strings must stay in swap-direction order and use token contract paths

### Frontend Integration Checklist

- [ ] Implement WUGNOT approval before wrapped-GNOT swaps
- [ ] Use token keys (`pkgPath.SYMBOL`) such as `"gno.land/r/gnoland/wugnot.wugnot"` for both parameters and routes
- [ ] Test both partial and full swap scenarios
- [ ] Implement proper error handling for failed approvals

Both single-hop functions support partial execution when
`sqrtPriceLimitX96` is nonzero:

- Exact-in may consume less than the specified input amount
- Exact-out may deliver less than the requested post-fee output
- The relevant amount limit (`amountOutMin` or `amountInMax`) still applies
- Remaining input tokens stay with the user because the router uses token
  contract transfers
- A zero limit uses the global tick-math boundary and preserves full exact
  semantics

## Security

- Path validation checks syntax, endpoints, hop continuity, and pool existence;
  it does not reject circular routes
- Deadline prevents stale live transactions
- Slippage limits protect against unfavorable execution
- The router fee rate is configurable; the current rate is fixed during one
  execution
- WUGNOT approval requirement prevents unauthorized token transfers
