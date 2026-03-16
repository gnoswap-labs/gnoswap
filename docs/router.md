# Router Module (`v1/router/`)

Swap routing: single-hop, multi-hop (max 3 hops), exact-in, exact-out, split routes.

## Key Files

| File | Purpose |
|------|---------|
| `exact_in.gno` | Exact input swap logic |
| `exact_out.gno` | Exact output swap logic |
| `swap_single.gno` | Single-hop swap |
| `swap_multi.gno` | Multi-hop swap (up to 3 hops) |
| `swap_inner.gno` | Core swap execution |
| `router.gno` | Router entry points |
| `base.gno` | Base utilities |

## Rules

- **SwapCallback** must verify both: `access.AssertIsPool(caller)` + `assertIsRouterV1()`. Missing either check allows forged callbacks.
- Exact-out slippage: output tolerance is ±`swapCount` (one per hop) to account for rounding.
- Router fee charged on output tokens. Fee cap: 10%. Validate all fee-setting functions.
- Route format: `TOKEN0:TOKEN1:FEE*POOL*TOKEN1:TOKEN2:FEE*POOL*...` — verify any route-parsing changes against this.
- `DrySwapRoute` and live swap must behave consistently. Discrepancy causes UX failures.
- Router hardcodes `sqrtPriceLimitX96 = 0` (audit N-04). Only slippage tolerance as MEV protection.

## Exact-Out Semantics

GnoSwap charges router fee on output tokens. In exact-out swaps, user receives `requestedAmount - routerFee`, **not** `requestedAmount`. This differs from Uniswap V3. Do not document as V3-compatible for exact-out.

## Pitfalls

- `SwapCallback` missing `AssertIsPool` → anyone forges callback params, drains approvals.
- `DrySwapRoute` / live swap divergence → users see wrong expected amounts.
- Multi-hop route where intermediate token equals input or output token → unexpected behavior.
