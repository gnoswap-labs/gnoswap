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

#### Native Token Route Specification

**IMPORTANT**: When using native GNOT tokens, there's a critical distinction between token identifiers and route paths:

- **Token Parameters**: Use `"gnot"` for `inputToken` and `outputToken` parameters
- **Route Paths**: Must use `"gno.land/r/gnoland/wugnot"` in route strings

This dual-identifier system exists because:

- Pools only operate on wrapped tokens (WUGNOT)
- Router functions accept native token identifiers for user convenience
- Internal processing automatically converts between native and wrapped forms

**Correct Usage Example**:

```go
// CORRECT: inputToken="gnot", route uses wugnot path
ExactInSwapRoute(
    "gnot",                                    // input token identifier
    "gno.land/r/demo/bar",                    // output token
    "1000000",
    "gno.land/r/gnoland/wugnot:gno.land/r/demo/bar:3000", // route uses wugnot
    "100", "950000", deadline, ""
)

// INCORRECT: using "gnot" in route will fail
ExactInSwapRoute(
    "gnot", "gno.land/r/demo/bar", "1000000",
    "gnot:gno.land/r/demo/bar:3000",          // Wrong: pools don't exist for "gnot"
    "100", "950000", deadline, ""
)
```

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

The Router automatically handles native GNOT token operations through wrapping/unwrapping mechanisms:

#### Token Identifier Requirements

- **Input Token**: Use `"gnot"` to specify native GNOT as input token
- **Output Token**: Use `"gnot"` to specify native GNOT as output token
- **Routes**: Must always use wrapped token path `"gno.land/r/gnoland/wugnot"` in route specifications

#### Native Token Send Requirements

When using native GNOT tokens, you must send the appropriate amount of native `ugnot` with your function call:

- **ExactInSwapRoute**: Send exactly `amountIn` amount of `ugnot`
- **ExactInSingleSwapRoute**: Send exactly `amountIn` amount of `ugnot`
- **ExactOutSwapRoute**: Send exactly `amountInMax` amount of `ugnot`
- **ExactOutSingleSwapRoute**: Send exactly `amountInMax` amount of `ugnot`

#### WUGNOT Approval Requirements for Refunds

```go
// Before calling router functions with native tokens
wugnot.Approve(cross, routerAddress, maxAmount)
```

This approval is required because:

- Router wraps native GNOT to WUGNOT for internal processing
- Unused GNOT is refunded by transferring WUGNOT from user and unwrapping it
- The `unwrapWithTransferFrom` function requires WUGNOT transfer approval

#### Refund Logic

- **ExactIn Functions**: Unused GNOT is automatically refunded after swap
- **ExactOut Functions**: Excess GNOT (difference between `amountInMax` and actual input used) is refunded
- Refunds use `unwrapWithTransferFrom` which requires prior WUGNOT approval

#### Example with Native GNOT

```go
// 1. First approve WUGNOT spending for potential refunds
wugnot.Approve(cross, routerAddress, 1000000) // Approve max amount

// 2. Call swap function with native GNOT, sending ugnot
// Note: inputToken="gnot" but route uses wugnot path
amountIn, amountOut := ExactInSwapRoute(
    "gnot",                                    // input token (native)
    "gno.land/r/demo/bar",                    // output token
    "1000000",                                // amount (send this much ugnot)
    "gno.land/r/gnoland/wugnot:gno.land/r/demo/bar:3000", // route uses wugnot
    "100",                                    // 100% through route
    "950000",                                 // min output
    time.Now().Unix() + 300,                  // deadline
    "",                                       // no referrer
)
// Any unused GNOT will be automatically refunded
```

### Slippage Protection

- Set `amountOutMin = expected * (1 - slippage%)`
- 0.5-1% for stable pairs
- 1-3% for volatile pairs
- Reverts if exceeded

## Usage

### Basic Token Swaps

```go
// Simple exact input swap
amountIn, amountOut := ExactInSwapRoute(
    "gno.land/r/demo/bar",     // input token
    "gno.land/r/demo/baz",     // output token
    "1000000",                 // amount (6 decimals)
    "gno.land/r/demo/bar:gno.land/r/demo/baz:3000", // route
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
    "gno.land/r/demo/bar:gno.land/r/gnoland/wugnot:3000*POOL*gno.land/r/gnoland/wugnot:gno.land/r/demo/baz:3000",
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
    "gno.land/r/demo/usdc:gno.land/r/gnoland/wugnot:500,gno.land/r/demo/usdc:gno.land/r/gnoland/wugnot:3000",
    "60,40",  // 60% through 0.05%, 40% through 0.3%
    "9500000000",
    deadline,
    "",
)
```

### Single Swap with Partial Execution

Single swap functions support partial execution through price limits:

```go
// Partial swap with price limit - may not consume full input amount
amountIn, amountOut := ExactInSingleSwapRoute(
    "gno.land/r/demo/bar",     // input token
    "gno.land/r/demo/baz",     // output token
    "1000000",                 // max amount to swap
    "gno.land/r/demo/bar:gno.land/r/demo/baz:3000", // single route
    "950000",                  // min output
    "1000000000000000000",     // sqrtPriceLimitX96 (price limit)
    deadline,
    "",
)
// If price limit is reached, only partial amount is swapped
// Remaining input tokens stay with user (no refund needed for GRC20 tokens)
```

### Native GNOT Swaps with Refunds

When using native GNOT, automatic refunds handle unused amounts:

```go
// STEP 1: Approve WUGNOT for potential refunds
wugnot.Approve(cross, routerAddress, 2000000) // Approve more than needed

// STEP 2: ExactIn with native GNOT (send exactly amountIn)
amountIn, amountOut := ExactInSwapRoute(
    "gnot",                    // native input
    "gno.land/r/demo/bar",     // output token
    "1000000",                 // send this amount of ugnot with call
    "gno.land/r/gnoland/wugnot:gno.land/r/demo/bar:3000",
    "100", "950000", deadline, ""
)
// Any unused GNOT automatically refunded

// STEP 3: ExactOut with native GNOT (send amountInMax)
amountIn, amountOut := ExactOutSwapRoute(
    "gnot",                    // native input
    "gno.land/r/demo/bar",     // output token
    "1000000",                 // exact output desired
    "gno.land/r/gnoland/wugnot:gno.land/r/demo/bar:3000",
    "100",
    "1200000",                 // send this max amount of ugnot with call
    deadline, ""
)
// Excess GNOT (1200000 - actual_input_used) automatically refunded

// STEP 4: Single swap with partial execution + refund
amountIn, amountOut := ExactInSingleSwapRoute(
    "gnot",                    // native input
    "gno.land/r/demo/bar",     // output token
    "1000000",                 // send this amount of ugnot with call
    "gno.land/r/gnoland/wugnot:gno.land/r/demo/bar:3000",
    "950000",
    "1000000000000000000",     // price limit may cause partial swap
    deadline, ""
)
// Unswapped GNOT due to price limit automatically refunded
```

## Important Developer Notes

### Common Integration Pitfalls

1. **WUGNOT Approval Forgotten**: Most transaction failures with native GNOT occur because developers forget to approve WUGNOT spending before calling router functions.

2. **Route vs Token Identifier Confusion**: Using `"gnot"` in route strings instead of `"gno.land/r/gnoland/wugnot"` will cause transactions to fail since no pools exist for the `"gnot"` identifier.

3. **Incorrect Native Token Send Amount**:

   - ExactIn functions: Must send exactly `amountIn` of native ugnot
   - ExactOut functions: Must send exactly `amountInMax` of native ugnot
   - Sending wrong amounts will cause transaction reversion

4. **Missing Refund Handling**: When integrating, remember that native GNOT refunds are automatic but require prior WUGNOT approval.

### Frontend Integration Checklist

- [ ] Implement WUGNOT approval before native GNOT swaps
- [ ] Use correct token identifiers: `"gnot"` for parameters, `"gno.land/r/gnoland/wugnot"` for routes
- [ ] Send correct native token amounts with function calls
- [ ] Handle automatic refunds in UI balance updates
- [ ] Test both partial and full swap scenarios
- [ ] Implement proper error handling for failed approvals

### Single Swap Partial Execution

The `ExactInSingleSwapRoute` and `ExactOutSingleSwapRoute` functions support partial execution when `sqrtPriceLimitX96` is set. This means:

- Swap may consume less than the specified input amount
- Price impact is limited by the price limit parameter
- Remaining tokens are handled automatically (refunded for native GNOT, stay with user for GRC20)
- This is useful for large trades to prevent excessive slippage

## Security

- Path validation prevents circular routes
- Deadline prevents stale transactions
- Slippage limits protect against MEV
- Router fees immutable per swap
- WUGNOT approval requirement prevents unauthorized token transfers
