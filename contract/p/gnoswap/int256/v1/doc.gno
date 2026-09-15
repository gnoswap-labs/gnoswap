// Package int256 implements 256-bit signed integer arithmetic for GnoSwap.
//
// This package provides an Int type that represents a 256-bit signed integer
// using two's complement representation. It supports the full range from
// -(2^255) to 2^255-1, with arithmetic operations that detect overflow.
//
// The implementation follows Ethereum's int256 semantics, ensuring compatibility
// for cross-chain DeFi protocols. Operations are optimized for common AMM
// calculations including tick math and price computations.
//
// Critical operations like Add, Sub, and Mul return overflow flags, enabling
// safe handling of edge cases in financial calculations.
package int256
