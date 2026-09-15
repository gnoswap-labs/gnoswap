# Position Module

NFT-based concentrated-liquidity position management.

## Position State

Each position is a GRC721 NFT. Its stored state includes the pool key, tick
range, liquidity, fee-growth checkpoints, tokens owed, burned marker, and
operator. Current token balances are calculated from the current pool price,
range, and liquidity; they are not a permanently stored balance snapshot.

The pool's accounting key is the encoded lower/upper tick pair, scoped to a
pool. It does not include the owner, Position package path, or NFT ID, so NFTs
with the same range in one pool share the pool-level liquidity and fee-growth
accounting.

## Core Operations

- **Mint** validates tick alignment, computes the required token amounts, and
  returns the actual amounts used.
- **IncreaseLiquidity** adds liquidity to the existing range and can revive a
  position whose burned marker was set after it became clear.
- **DecreaseLiquidity** is one atomic caller-visible operation. Internally it
  settles accrued swap fees first, burns the requested liquidity, then collects
  principal through the fee-free pool `Collect` path. It returns fee amounts
  net of the withdrawal fee and the collected principal amounts.
- **CollectFee** claims accrued swap fees without removing liquidity. It returns
  net amounts and the raw pre-withdrawal-fee amounts; the default withdrawal
  fee is 1% and the configured rate can change.
- **Reposition** requires a clear position (zero liquidity and zero tokens
  owed), reuses the NFT ID, and adds liquidity in the new range. It also clears
  the burned marker.

## Transfer and Lifecycle Rules

- An unstaked NFT follows the GRC721 owner/approval/operator transfer rules.
- A staked NFT (held by the staker contract) is locked to staker-mediated
  transfers.
- A full decrease sets a `burned` marker when the position becomes clear; it
  does not destroy the NFT. `IncreaseLiquidity` and `Reposition` can clear that
  marker when the position is used again.
- Liquidity-changing operations have amount-minimum slippage checks and
  deadlines. `CollectFee` has no deadline or output-minimum argument.

## Token Amounts

For liquidity `L` and square-root prices `sqrtLower`, `sqrtCurrent`, and
`sqrtUpper`:

- **Below range** (`current < lower`): token0 only,
  `amount0 = L * (sqrtUpper - sqrtLower) / (sqrtUpper * sqrtLower)`.
- **In range**: both tokens,
  `amount0 = L * (sqrtUpper - sqrtCurrent) / (sqrtUpper * sqrtCurrent)` and
  `amount1 = L * (sqrtCurrent - sqrtLower)`.
- **Above range** (`current >= upper`): token1 only,
  `amount1 = L * (sqrtUpper - sqrtLower)`.
