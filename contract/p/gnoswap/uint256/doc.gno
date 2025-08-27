// Package uint256 implements 256-bit unsigned integer arithmetic for GnoSwap.
//
// This package provides a Uint type that represents a 256-bit unsigned integer,
// stored as four uint64 values in little-endian order. It includes arithmetic
// operations with overflow detection, which are essential for safe token
// calculations in DeFi protocols.
//
// The implementation is optimized for gas efficiency while maintaining
// compatibility with Ethereum's uint256 semantics, ensuring consistent
// behavior across different blockchain environments.
//
// All operations that may overflow return both the result and an overflow flag,
// allowing calling code to handle overflow conditions appropriately.
package uint256
