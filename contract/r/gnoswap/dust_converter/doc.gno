// Overview
// - Purpose: Convert small, accumulated protocol-fee balances ("dust") from many tokens
//   into a single target asset (default: GNS) and transfer the consolidated result to
//   a recipient in one call.
// - Design goal: Minimize operational overhead by allowing an admin/governance-defined
//   policy (min/max thresholds, cooldown, target assets) and a single batched conversion
//   entrypoint.
// - Intended use: Periodic cleanup of small protocol-fee balances without requiring
//   per-token manual swaps.
//
// Key Concepts
// - Dust: A token balance that falls within a global `[min, max]` window.
// - Target asset: The asset into which all eligible dust balances are converted.
// - Batch input: A comma-separated list of token:amount pairs provided as a string.
// - Cooldown: A global time-based throttle to prevent frequent executions.
//
// High-Level Flow (`ConvertDustToGns`)
// 1) Validate target asset and batch input.
// 2) Enforce cooldown (if configured).
// 3) For each token:amount pair:
//    - Parse and validate input.
//    - Check dust min/max thresholds.
//    - Ensure the contract holds enough balance.
//    - If token == target: add amount directly (fee-adjusted).
//    - Else: select the best pool by liquidity across fee tiers and swap:
//      * `DrySwapRoute` to get a quote.
//      * `ExactInSingleSwapRoute` using the dry quote as `amountOutMin`.
//    - Accumulate net output to total.
// 4) Transfer total target asset to the recipient.
// 5) Update lastExecutedTimestamp and emit event.
//
// Input Format
// - Signature: `ConvertDustToGns`(realm, targetPath, pairs, deadline, recipient) int64
// - pairs format: "tokenA:100,tokenB:200"
//   * token path and amount are trimmed.
//   * amount must parse to int64, and negative amounts are rejected.
//   * zero amounts are ignored.
// - targetPath must be registered in the target asset allowlist.
//
// Pool Selection and Swap Details
// - Only single-hop swaps are supported.
// - The contract checks pools across fixed fee tiers and chooses the one with the
//   largest liquidity for the token pair.
// - `DrySwapRoute` is used as the min-out guard; if the quote is unfavorable or zero,
//   the pair is skipped.
// - Swaps are executed via `router.ExactInSingleSwapRoute` with the dry quote as
//   `amountOutMin` to enforce strict slippage protection.
//
// State and Configuration
// - `dustMinAmount`, `dustMaxAmount`: Global dust thresholds (admin/governance).
// - `cooldownSeconds`: Global execution cooldown (admin/governance).
// - `lastExecutedTimestamp`: Time of last successful batch (read-only).
// - `targetAssets`: Allowlist of acceptable target assets (admin/governance).
// - `feeBps`: Conversion fee in basis points (currently 0).
//
// Events
// - `ConvertDustToGns` emits caller, recipient, target asset, total output, and
//   `lastExecutedTimestamp`.
//
// Error/Skip Behavior
// - Invalid input format or negative amounts: revert.
// - Amount below min or above max: skip the pair.
// - Missing pool, DrySwap failure, or zero output: skip the pair.
// - Insufficient contract balance: revert.
//
// Operational Notes
// - Default policy: `dustMinAmount` and `dustMaxAmount` start at 10 (int64 units);
//   `cooldownSeconds` defaults to 0 (no cooldown). Governance/admin should tune
//   thresholds based on typical protocol-fee dust sizes to avoid wasting swaps.
// - Execution role: `ConvertDustToGns` is permissionless; any caller can execute
//   the batch, while policy changes (thresholds, cooldown, target assets) are
//   restricted to admin/governance.
// - Target asset policy: `targetAssets` is an allowlist controlled by admin/governance.
//   It initializes with GNS only and can be expanded via `AddTargetAsset`.
//
// Example
// - Inputs:
//   targetPath = "gno.land/r/gnoswap/gns"
//   pairs = "gno.land/r/gnoswap/gns:50,gno.land/r/foo/bar:100,gno.land/r/baz/qux:200"
// - Outcome (simplified):
//   * gns:50 is added directly to total (fee-adjusted if feeBps > 0).
//   * bar:100 is swapped if a pool exists and `DrySwapRoute` returns a positive quote.
//   * qux:200 is skipped if no pool exists or the dry quote is zero.
//   * total output is transferred to recipient; `lastExecutedTimestamp` updates only
//     if at least one pair was processed.
//
// Limitations and Future Extensions
// - Global min/max thresholds are not per-token.
// - Multi-hop routes are not supported.
// - feeBps is defined but currently zero.
// - [Placeholder: Future design for per-token dust thresholds.]
// - [Placeholder: Optional TWAP or slippage policy enhancements.]
package dust_converter
