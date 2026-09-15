// Package uint256 implements 256-bit unsigned integer arithmetic for GnoSwap.
//
// This package provides a Uint type that represents a 256-bit unsigned integer,
// stored as four uint64 values in little-endian order. The unsuffixed Add, Sub,
// and Mul methods return the low 256 bits; AddOverflow, SubOverflow, and
// MulOverflow additionally report an overflow/underflow flag. MulDiv and
// MulDivRoundingUp panic on a zero denominator or an unrepresentable result;
// the rounding variant also panics if adding one to its result would overflow.
//
// The implementation is optimized for gas efficiency while maintaining
// compatibility with Ethereum's uint256 semantics, ensuring consistent
// behavior across different blockchain environments.
package uint256
