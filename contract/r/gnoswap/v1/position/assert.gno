package position

import (
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/v1/common"
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
	n := len(input)
	if n == 0 {
		panic(newErrorWithDetail(
			errInvalidInput,
			ufmt.Sprintf("input is empty")))
	}

	isNegative := input[0] == '-'

	if n == 1 && isNegative {
		panic(newErrorWithDetail(
			errInvalidInput,
			ufmt.Sprintf("input string : %s", input)))
	}

	start := 0
	if isNegative {
		start = 1
	}

	for i := start; i < n; i++ {
		if input[i] < '0' || input[i] > '9' {
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
func assertIsOwnerForToken(positionId uint64, caller address) {
	assertExistsPosition(positionId)

	if !isOwner(positionId, caller) {
		panic(newErrorWithDetail(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not owner of positionId(%d)", caller, positionId),
		))
	}
}

// assertIsOwnerOrOperatorForToken panics if caller is not the owner or operator of the position.
func assertIsOwnerOrOperatorForToken(positionId uint64, caller address) {
	assertExistsPosition(positionId)

	if !isOwnerOrOperator(positionId, caller) {
		panic(newErrorWithDetail(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not owner or approved operator of positionId(%d)", caller, positionId),
		))
	}
}

// assertEqualsAddress panics if addresses are invalid or not equal.
func assertEqualsAddress(prevAddr, otherAddr address) {
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

// assertIsValidUserCoinSendWithTokenPair asserts that the user has sent the correct amount of native coin.
func assertIsValidUserCoinSendWithTokenPair(token0, token1 string, amount0, amount1 string) {
	if common.IsGNOTNativePath(token0) {
		common.AssertIsUserSendGNOTAmount(mustParseInt64(amount0))

		return
	}

	if common.IsGNOTNativePath(token1) {
		common.AssertIsUserSendGNOTAmount(mustParseInt64(amount1))

		return
	}

	common.AssertIsNotHandleNativeCoin()
}

// assertIsValidUserCoinSendWithWrappedTokenPair asserts that the user has sent the correct amount of native coin.
func assertIsValidUserCoinSendWithWrappedTokenPair(token0, token1 string, amount0, amount1 string) {
	isExistsUserSendCoins := common.ExistsUserSendCoins()

	if isExistsUserSendCoins {
		if common.IsGNOTPath(token0) {
			common.AssertIsUserSendGNOTAmount(mustParseInt64(amount0))

			return
		}

		if common.IsGNOTPath(token1) {
			common.AssertIsUserSendGNOTAmount(mustParseInt64(amount1))

			return
		}
	}

	common.AssertIsNotHandleNativeCoin()
}
