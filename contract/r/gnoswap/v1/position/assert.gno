package position

import (
	"std"
	"time"

	ufmt "gno.land/p/nt/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/access"
)

// assertIsNotExpired panics if the deadline is expired.
func assertIsNotExpired(deadline int64) {
	now := time.Now().Unix()

	if now > deadline {
		panic(makeErrorWithDetails(
			errExpired,
			ufmt.Sprintf("transaction too old, now(%d) > deadline(%d)", now, deadline),
		))
	}
}

// assertValidNumberString panics if the input string does not represent a valid integer.
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

// assertValidLiquidityAmount panics if the liquidity amount is zero.
func assertValidLiquidityAmount(liquidity string) {
	if u256.MustFromDecimal(liquidity).IsZero() {
		panic(newErrorWithDetail(
			errZeroLiquidity,
			ufmt.Sprintf("liquidity amount must be greater than 0, got %s", liquidity),
		))
	}
}

// assertExistsPosition panics if the position does not exist.
func assertExistsPosition(positionId uint64) {
	if !exists(positionId) {
		panic(newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}
}

// assertIsOwnerForToken panics if caller is not the owner of the position.
func assertIsOwnerForToken(positionId uint64, caller std.Address) {
	assertExistsPosition(positionId)

	if !isOwner(positionId, caller) {
		panic(newErrorWithDetail(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not owner of positionId(%d)", caller, positionId),
		))
	}
}

// assertIsOwnerOrOperatorForToken panics if caller is not the owner or operator of the position.
func assertIsOwnerOrOperatorForToken(positionId uint64, caller std.Address) {
	assertExistsPosition(positionId)

	if !isOwnerOrOperator(positionId, caller) {
		panic(newErrorWithDetail(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not owner or approved operator of positionId(%d)", caller, positionId),
		))
	}
}

// assertEqualsAddress panics if addresses are invalid or not equal.
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

// assertSlippageIsNotExceeded panics if slippage tolerance is exceeded.
func assertSlippageIsNotExceeded(amount0, amount1, amount0Min, amount1Min *u256.Uint) {
	if !(amount0.Gte(amount0Min) && amount1.Gte(amount1Min)) {
		panic(newErrorWithDetail(
			errSlippage,
			ufmt.Sprintf("amount0(%s) >= amount0Min(%s) && amount1(%s) >= amount1Min(%s)",
				amount0.ToString(), amount0Min.ToString(), amount1.ToString(), amount1Min.ToString()),
		))
	}
}
