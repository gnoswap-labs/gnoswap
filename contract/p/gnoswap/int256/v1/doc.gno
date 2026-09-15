// Package int256 implements 256-bit signed integer arithmetic for GnoSwap.
//
// This package provides an Int type that represents a 256-bit signed integer
// using two's complement representation. It supports the full range from
// -(2^255) to 2^255-1. The unsuffixed Add, Sub, and Mul methods return the
// truncated 256-bit result; AddOverflow, SubOverflow, and MulOverflow also
// return a signed-overflow flag.
//
// The implementation follows Ethereum's int256 semantics, ensuring compatibility
// for cross-chain DeFi protocols. Operations are optimized for common AMM
// calculations including tick math and price computations.
package int256
