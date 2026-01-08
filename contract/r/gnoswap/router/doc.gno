// Package router provides swap routing and execution across GnoSwap liquidity pools.
//
// The router handles token swaps with multi-hop routing, slippage protection,
// and automatic GNOT wrapping/unwrapping. It supports both exact input and
// exact output swap modes with deadline validation.
//
// Key features:
// - Multi-hop routing across up to 3 pools
// - Quote distribution for optimal execution
// - Native GNOT handling with automatic wrap/unwrap
// - Slippage protection via min/max amounts
// - Router fee (0.15%) on all swaps
// - Deadline enforcement to prevent stale transactions
//
// The router acts as a proxy to version-specific implementations,
// currently routing to v1 for all swap operations.
package router
