// Package router handles token swaps through GnoSwap liquidity pools.
//
// The router provides user-facing swap functions with slippage protection,
// multi-hop routing, and automatic GNOT wrapping/unwrapping. It supports
// both exact input and exact output swap modes.
//
// All swap functions include deadline checks and minimum output validation
// to protect users from unfavorable price movements.
package router
