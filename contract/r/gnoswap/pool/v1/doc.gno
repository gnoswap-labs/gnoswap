// Package pool implements GnoSwap's concentrated liquidity pools based on Uniswap V3.
// It manages liquidity positions, executes swaps, and maintains pool state including
// price, liquidity, and fee calculations.
//
// The pool contract is the core of the GnoSwap AMM, supporting:
// - Concentrated liquidity within custom price ranges
// - Multiple fee tiers (0.01%, 0.05%, 0.3%, 1%)
// - Single-tick and cross-tick swaps
// - Protocol fee collection
// - Tick bitmap optimization for gas efficiency
package pool
