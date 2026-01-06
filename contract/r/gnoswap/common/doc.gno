// Package common provides shared utilities and mathematical functions for GnoSwap protocol contracts.
//
// The package contains essential mathematical functions, helper utilities, and shared
// logic used across the GnoSwap protocol. It provides implementations for concentrated liquidity
// calculations, price/tick conversions, GRC20 token operations, and native coin handling.
//
// This package serves as the mathematical foundation for the protocol, implementing algorithms
// based on Uniswap V3's concentrated liquidity model with Q64.96 fixed-point arithmetic.
//
// Key components:
// - Tick Math: Price-tick conversion functions for concentrated liquidity positions
// - Liquidity Math: Liquidity calculations based on token amounts and price ranges
// - GRC20 Registry Helpers: Convenient wrappers for GRC20 token operations
// - Coin Utilities: Native coin (GNOT) handling and validation
// - Assertion Utilities: Input validation and authorization checks
package common
