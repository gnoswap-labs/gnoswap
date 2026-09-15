# Router Module (`v1/router/`)

Swap routing across up to seven routes, with up to three pools (hops) per route. The
live entry points support exact-in and exact-out swaps; single-hop entry points also
accept a price limit.

## Key Files

| File              | Purpose        |
| ----------------- | -------------- |
| `exact_in.gno`    | Exact-input swap entry points |
| `exact_out.gno`   | Exact-output swap entry points |
| `swap_single.gno` | Single-hop swap |
| `swap_multi.gno`  | Multi-hop swap (up to 3 hops) |
| `swap_inner.gno`  | Core swap execution and pool callback closure |
| `router.gno`      | Validation and finalization |
| `base.gno`        | Shared route and operation utilities |

## Rules

- **SwapCallback** has a two-stage caller invariant. The callback closure in
  `swap_inner.gno` first verifies that the call came from the pool with
  `access.AssertIsPool`; it then delegates to the Router implementation,
  whose `SwapCallback` verifies the Router-v1 implementation caller with
  `assertIsRouterImplementation`. The direct callback body is reached only
  after the pool-origin check.
- Router fees are charged on output tokens. The default is 15 bps (0.15%);
  admin/governance can configure the rate from 0 through 1000 bps (0–10%).
  The configured rate is fixed for an individual execution, but can change
  for later swaps.
- Route format is
  `TOKEN_IN:TOKEN_OUT:FEE*POOL*TOKEN_IN:TOKEN_OUT:FEE...`. Each route must
  start at `inputToken`, end at `outputToken`, and have continuous hops.
  Validation does not reject a repeated intermediate token or otherwise
  enforce an acyclic route.
- `DrySwapRoute` and live swaps share route parsing and pool simulation rules,
  but dry swaps do not check a deadline or perform transfers.
- Multi-hop entry points use a zero price-limit argument internally. Single-hop
  entry points accept caller-supplied `sqrtPriceLimitX96`; a nonzero limit can
  stop execution early and permit a partial fill.

## Exact-Out Semantics

The `amountOut` argument is the user's **post-router-fee output target**.
The router requests a gross amount from the pool using the configured fee,
deducts the fee from the pool output, and transfers the resulting net amount
to the user. With no single-hop price limit, the net output is checked against
the target within a small per-hop rounding tolerance, while `amountInMax`
limits the input spent. This is not the Uniswap V3 exact-out convention of
passing the user target directly to the pool.

When a nonzero single-hop price limit is reached, exact-out target validation
is intentionally skipped so that the swap can return a partial output. The
`amountInMax` check still applies.

## Price Limits and Partial Fills

- `ExactInSingleSwapRoute` may consume less than its requested input when a
  nonzero price limit is reached; `amountOutMin` still applies.
- `ExactOutSingleSwapRoute` may deliver less than its requested output when a
  nonzero price limit is reached; `amountInMax` still applies.
- A zero single-hop limit means no caller-selected bound; the router uses the
  corresponding global tick-math boundary. Multi-hop routes always use this
  zero-limit behavior.

## Pitfalls

- Applying the router fee to an exact-out target twice understates the desired
  pool output. Model the target as the amount received after one router fee.
- Assuming every price limit failure reverts is incorrect: a reached nonzero
  single-hop limit is a successful partial execution subject to the relevant
  amount limit.
- Assuming route validation prevents circular routes is incorrect; only
  endpoints, hop continuity, syntax, and referenced-pool existence are checked.
