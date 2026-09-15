# Pool Module (`v1/pool/`)

Concentrated-liquidity AMM pools with tick-based price ranges, oracle
observations, protocol-fee accounting, and callback settlement.

## Key Concepts

- **Pool key**: `token0:token1:fee`, with token paths canonicalized so
  `token0 < token1`.
- **Slot0**: current `sqrtPriceX96`, current tick, observation index/cardinality,
  protocol-fee denominator, and the pool's `unlocked` reentrancy state.
- **Oracle**: `ObservationTree` is the pool-local observation ring buffer.
- **Ticks**: initialized ticks track gross liquidity and fee-growth-outside
  values; tick spacing is selected by the fee tier.
- **Position accounting**: a pool position key encodes only the lower and upper
  ticks. Positions with the same range in one pool share that pool-level
  accounting entry; the Position module separately tracks each NFT's state.

## Rules

- `GetSlot0Unlocked` returns whether the pool is currently unlocked, not a
  lock-status value with the opposite polarity.
- Protocol fee values are denominators: `0` disables the fee, and `4` through
  `10` route one quarter through one tenth of swap fees to the protocol. The
  setting is managed globally for the pools; it is not a per-pool percentage.
- The withdrawal fee is separate from the swap protocol fee. It defaults to
  1% (100 bps) and is configurable up to 10% (1000 bps) for fee-bearing
  collection.
- Maximum liquidity per tick is dependent on the pool's tick spacing; it is
  not the `2^128 - 1` maximum.

## CreatePool

`CreatePool` accepts either token path order and canonicalizes the pair. If the
paths are supplied in reverse order, the initial square-root price is inverted
to match the canonical token0/token1 order. The resulting
`sqrtPriceX96` must be in `[MIN_SQRT_RATIO, MAX_SQRT_RATIO)`; there is no
external oracle or market-price sanity check at creation.

## Liquidity and Collection

- `Mint` adds liquidity and transfers the required token amounts.
- `Burn` removes liquidity from the pool position and credits principal to its
  `tokensOwed`; it does not transfer tokens.
- `Collect` pays owed tokens without a withdrawal fee. This is the fee-free
  principal path normally used after `Burn`.
- `CollectSwapFee` pays accrued swap fees and applies the configured withdrawal
  fee, returning the gross amounts and fee withheld.
- `Position.DecreaseLiquidity` wraps the fee collection, `Burn`, and fee-free
  principal collection in one caller-visible operation.

## Swap Callback

The pool sends output tokens before invoking the callback with positive input
delta(s). In the router flow, the closure supplied to the pool first checks
that the caller is the pool, then delegates to `router.SwapCallback`, which
checks that the caller is the Router-v1 implementation. This two-stage
invariant protects both the pool-origin and router-implementation boundaries.
The callback must transfer each positive delta back to the pool.

## Swap Flow

1. Validate token direction and the square-root price limit.
2. Find the next initialized tick in the swap direction.
3. Compute the step to the next tick or price limit.
4. Update liquidity and fee growth when crossing a tick.
5. Invoke the callback to settle input, then verify the pool balance increase.
6. Persist `Slot0`, tick, liquidity, and fee-growth state.

## Pitfalls

- Pool math rounds in the direction required by the input/output invariant;
  treating every division as an unconditional round-down can misstate who
  receives the rounding remainder.
- A callback that does not settle the full positive input delta causes the
  swap to revert.
- Pool creation validates square-root bounds, but callers still need to
  choose an economically appropriate initial price.
