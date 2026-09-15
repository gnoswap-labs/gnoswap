// package router handles token swaps through GnoSwap liquidity pools.
//
// The router provides user-facing swap functions with slippage protection,
// multi-hop routing, and both exact-input and exact-output swap modes.
//
// Live exact-input calls enforce a minimum output and deadline. Live
// exact-output calls enforce a maximum input and deadline. DrySwapRoute is
// read-only and has no deadline or transfer.
package router
