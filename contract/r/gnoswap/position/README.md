# Position

NFT-based liquidity position management for concentrated liquidity.

## Overview

Each liquidity position is a unique GRC721 NFT. Stored state includes the pool
key, price range, liquidity, fee-growth checkpoints, tokens owed, burned marker,
and operator. Current token balances are derived from the current pool price,
range, and liquidity; they are not permanently stored balances.

The pool accounting key encodes only the lower/upper tick pair and is scoped by
pool. NFTs with the same range in one pool share the pool-level accounting entry.

## Gnoweb

The root `Render("")` delegates to the active implementation and shows realm identity, halt flags, stored position count, and the next position ID. Stored records include burned positions, so the count does not represent active liquidity positions.

Supported routes:

- `""`: the root summary. It reads only aggregate position-store metadata.
- `position/<id>`: one position record, selected by a single keyed lookup. The `<id>` must be an unsigned decimal `uint64`; malformed, overflowing, missing, and extra-segment paths return `404`.

For example, `/r/gnoswap/position:position/1` shows position 1. Detail pages show
the ID, burn status, NFT owner when available, token realm links, fee tier, tick
range, liquidity, and stored fee accounting.

The composite pool key is inline code; each token reference links to its defining
realm rather than a `.SYMBOL` URL. Rendering does not enumerate positions or
recompute claimable fees and current token balances. Burned records remain
addressable even when their NFT owner is unavailable.

## Configuration

- **Withdrawal Fee**: 1% by default on fee-bearing swap-fee collection
- **Max Position Size**: No separate position-level cap; pool tick limits apply
- **Transfers**: Unstaked NFTs follow GRC721 owner/approval/operator rules;
  staked NFTs are locked to staker-mediated transfers

## Core Functions

### `Mint`

Creates new position NFT with initial liquidity.

- Validates tick range alignment
- Calculates optimal token ratio
- Returns actual amounts used

### `IncreaseLiquidity`

Adds liquidity to an existing position.

- Maintains the existing price range
- Uses the current-price token ratio
- Can clear a burned marker when the position is used again

### `DecreaseLiquidity`

Removes liquidity while keeping the NFT.

- One atomic public operation: internally collects swap fees, burns liquidity,
  then collects principal through the pool's fee-free `Collect` path
- Returns fee amounts net of the withdrawal fee and collected principal
- Amount-minimum checks apply to the principal actually collected

### `CollectFee`

Claims accumulated swap fees without removing liquidity.

- No liquidity removal required
- Returns net collected amounts plus the raw pre-withdrawal-fee amounts
- The configured withdrawal fee applies only to this fee-bearing path

### `Reposition`

Updates an existing position's price range.

- Requires the position to be clear first (zero liquidity and tokens owed)
- Reuses the same position ID and NFT
- Adds new liquidity to the updated range and clears the burned marker

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

For liquidity `L` and square-root prices `sqrtLower`, `sqrtCurrent`, and
`sqrtUpper`:

**Below range (`current < lower`, token0 only)**:

```
amount0 = L * (sqrtUpper - sqrtLower) / (sqrtUpper * sqrtLower)
amount1 = 0
```

**In range (`lower <= current < upper`, both tokens)**:

```
amount0 = L * (sqrtUpper - sqrtCurrent) / (sqrtUpper * sqrtCurrent)
amount1 = L * (sqrtCurrent - sqrtLower)
```

**Above range (`current >= upper`, token1 only)**:

```
amount0 = 0
amount1 = L * (sqrtUpper - sqrtLower)
```

## Approval and Transfer Requirements

`Mint`, `IncreaseLiquidity`, and `Reposition` pull token0 and token1 from the
caller inside the **pool** realm, so the approved spender is the pool realm
address, not the position realm.

- Approve the pool realm for both token contracts before calling a
  liquidity-adding function.
- Approving the position realm alone is not sufficient; the position realm never
  holds or pulls the pair tokens itself.
- Approve at least `amount0Desired` / `amount1Desired`. Any desired amount the
  pool does not consume stays with the caller.
- `DecreaseLiquidity` and `CollectFee` pay out to the caller and require no
  approval.

```go
// Approve the pool realm for both pair tokens before minting
poolAddress := access.MustGetAddress(prabc.ROLE_POOL.String())
weth.Approve(cross(cur), poolAddress, 1000000)
usdc.Approve(cross(cur), poolAddress, 2000000000)
```

## Usage

These snippets call the public domain proxy from a realm function with a current `cur` token.
Import the proxy package and qualify its function names in integrating code.

```go
// Mint new position
tokenId, liquidity, amount0, amount1 := Mint(
    cross(cur),
    "gno.land/r/onbloc/weth",  // token0
    "gno.land/r/gnoswap/test_token/test_usdc",  // token1
    3000,                      // fee
    -887220,                   // tickLower
    887220,                    // tickUpper
    "1000000",                 // amount0Desired
    "2000000000",              // amount1Desired
    "950000",                  // amount0Min
    "1900000000",              // amount1Min
    deadline,
    recipient,                 // mintTo
    "",                        // referrer
)

// Add liquidity
positionId, liquidity, amount0, amount1, poolPath := IncreaseLiquidity(
    cross(cur),
    tokenId,
    "500000",
    "1000000000",
    "475000",
    "950000000",
    deadline,
)

// Collect fees
positionId, collected0, collected1, poolPath, rawAmount0, rawAmount1 := CollectFee(
    cross(cur),
    tokenId,
)

// Reposition to new range (requires cleared position)
positionId, liquidity, tickLower, tickUpper, amount0, amount1 := Reposition(
    cross(cur),
    tokenId,
    -443610,                   // new tickLower
    443610,                    // new tickUpper
    "1000000",                 // amount0Desired
    "2000000000",              // amount1Desired
    "950000",                  // amount0Min
    "1900000000",              // amount1Min
    deadline,
)
```

## Lifecycle

A full decrease that leaves zero liquidity and zero tokens owed sets the
`burned` marker but does not destroy the NFT. `IncreaseLiquidity` and
`Reposition` clear the marker when the position is used again; the marker does
not by itself block an increase.

## Security

- Tick range validation prevents invalid positions
- Slippage protection applies to liquidity-changing operations; fee collection
  has no amount-minimum parameter
- Deadlines prevent stale liquidity-changing transactions
- Unstaked NFTs follow standard GRC721 transfer authorization; staked NFTs
  can move only through staker-mediated flows
- Liquidity changes and repositioning require the owner; fee collection also
  permits the position's approved operator where applicable
