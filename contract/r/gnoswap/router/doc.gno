// Package router provides swap routing and execution across GnoSwap liquidity pools.
//
// Router domain proxy for single-hop and multi-hop exact-in, exact-out, and
// dry-route operations.
//
// Live exact-in and exact-out calls validate a deadline and the corresponding
// amount limit (minimum output or maximum input). DrySwapRoute is a read-only
// quote path with no deadline or token transfer.
//
// The router fee is charged on output tokens. It defaults to 15 bps (0.15%)
// and is configurable by admin/governance from 0 through 1000 bps (0–10%);
// the current rate is fixed for each individual execution.
//
// The router acts as a proxy to version-specific implementations,
// currently routing to v1 for all swap operations.
package router
