package position

import (
	"std"
	"time"

	ufmt "gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/access"
)

// assertIsNotExpired checks if the deadline is expired.
// If the deadline is expired, it panics.
// The deadline is expired if the current time is greater than the deadline.
// Input:
//   - deadline: the deadline to check
func assertIsNotExpired(deadline int64) {
	now := time.Now().Unix()
	
	if now > deadline {
		panic(makeErrorWithDetails(
			errExpired,
			ufmt.Sprintf("transaction too old, now(%d) > deadline(%d)", now, deadline),
		))
	}
}


// assertValidNumberString verifies that the input string represents a valid integer.
//
// This function checks each character in the string to ensure it falls within the numeric ASCII range ('0' to '9').
// The first character is allowed to be a negative sign ('-'), indicating a negative number. If the input does not
// meet these criteria, the function panics with a detailed error message.
//
// Parameters:
//   - input (string): The string to validate.
//
// Panics:
//   - If the input string is empty.
//   - If the input contains non-numeric characters (excluding an optional leading '-').
//   - If the input is not a valid integer representation.
//
// Example:
//
//	assertValidNumberString("12345")       -> Pass (valid positive number)
//	assertValidNumberString("-98765")      -> Pass (valid negative number)
//	assertValidNumberString("12a45")       -> Panic (invalid character 'a')
//	assertValidNumberString("")            -> Panic (empty input)
//	assertValidNumberString("++123")       -> Panic (invalid leading '+')
func assertValidNumberString(input string) {
	if len(input) == 0 {
		panic(newErrorWithDetail(
			errInvalidInput,
			ufmt.Sprintf("input is empty")))
	}

	bytes := []byte(input)
	for i, b := range bytes {
		if i == 0 && b == '-' {
			continue // Allow if the first character is a negative sign (-)
		}
		if b < '0' || b > '9' {
			panic(newErrorWithDetail(
				errInvalidInput,
				ufmt.Sprintf("input string : %s", input)))
		}
	}
}

func assertValidLiquidityAmount(liquidity string) {
	if u256.MustFromDecimal(liquidity).IsZero() {
		panic(newErrorWithDetail(
			errZeroLiquidity,
			ufmt.Sprintf("liquidity amount must be greater than 0, got %s", liquidity),
		))
	}
}

func assertExistsPosition(positionId uint64) {
	if !exists(positionId) {
		panic(newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}
}

func assertIsOwnerForToken(positionId uint64, caller std.Address) {
	assertExistsPosition(positionId)

	if !isOwner(positionId, caller) {
		panic(newErrorWithDetail(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not owner or approved operator of positionId(%d)", caller, positionId),
		))
	}
}

func assertIsOwnerOrOperatorForToken(positionId uint64, caller std.Address) {
	assertExistsPosition(positionId)
	
	if !isOwnerOrOperator(positionId, caller) {
		panic(newErrorWithDetail(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not owner or approved operator of positionId(%d)", caller, positionId),
		))
	}
}

// assertEqualsAddress panics if the address is invalid or previous address is not
// different from the other address.
func assertEqualsAddress(prevAddr, otherAddr std.Address) {
	access.AssertIsValidAddress(prevAddr)
	access.AssertIsValidAddress(otherAddr)

	if prevAddr != otherAddr {
		panic(newErrorWithDetail(
			errInvalidAddress,
			ufmt.Sprintf("(%s, %s)", prevAddr, otherAddr),
		))
	}
}

func assertSlippageIsNotExceeded(amount0, amount1, amount0Min, amount1Min *u256.Uint) {
	if !(amount0.Gte(amount0Min) && amount1.Gte(amount1Min)) {
		panic(newErrorWithDetail(
			errSlippage,
			ufmt.Sprintf("amount0(%s) >= amount0Min(%s) && amount1(%s) >= amount1Min(%s)",
				amount0.ToString(), amount0Min.ToString(), amount1.ToString(), amount1Min.ToString()),
		))
	}
}