// Package common provides shared realm utilities for GnoSwap protocol contracts.
//
// The package contains helpers that must keep a realm boundary, including GRC20
// token operations and native coin validation. AMM math lives in
// gno.land/p/gnoswap/gnsmath.
//
// Key components:
// - GRC20 Registry Helpers: convenient wrappers for GRC20 token operations
// - Coin Utilities: native coin handling and validation
// - Assertion Utilities: input validation and authorization checks
package common
