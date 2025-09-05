package pool

import (
	"std"

	"gno.land/p/nt/ufmt"
)

// assertIsNotEqualsTokens asserts that the token0Path and token1Path are not equal.
func assertIsNotEqualsTokens(token0Path, token1Path string) {
	if token0Path == token1Path {
		panic(newErrorWithDetail(
			errDuplicateTokenInPool,
			ufmt.Sprintf("expected token0Path(%s) != token1Path(%s)", token0Path, token1Path),
		))
	}
}

// assertIsSupportedFeeTier asserts that the fee is a supported fee tier.
func assertIsSupportedFeeTier(fee uint32) {
	if !isValidFeeTier(fee) {
		panic(newErrorWithDetail(
			errUnsupportedFeeTier,
			ufmt.Sprintf("expected fee(%d) to be one of %d, %d, %d, %d", fee, FeeTier100, FeeTier500, FeeTier3000, FeeTier10000),
		))
	}
}

// assertIsNotExistsPoolPath asserts that the pool path does not exist.
func assertIsNotExistsPoolPath(token0Path, token1Path string, fee uint32) {
	poolPath := GetPoolPath(token0Path, token1Path, fee)

	if pools.Has(poolPath) {
		panic(newErrorWithDetail(
			errPoolAlreadyExists,
			ufmt.Sprintf("expected poolPath(%s:%s:%d) not to exist", token0Path, token1Path, fee),
		))
	}
}

// assertIsValidTicks validates the tick range for a liquidity position.
func assertIsValidTicks(tickLower, tickUpper int32) {
	if err := validateTicks(tickLower, tickUpper); err != nil {
		panic(err)
	}
}

// assertAmountSpecifiedIsNotZero asserts that the amountSpecified is not zero.
func assertAmountSpecifiedIsNotZero(amountSpecified string) {
	if amountSpecified == "0" {
		panic(newErrorWithDetail(
			errInvalidSwapAmount,
			ufmt.Sprintf("amountSpecified == 0"),
		))
	}
}

func assertPayerIsPreviousRealmOrOriginCaller(payer std.Address) {
	if payer != std.PreviousRealm().Address() && payer != std.OriginCaller() {
		panic(newErrorWithDetail(
			errInvalidPayer,
			ufmt.Sprintf("expected payer(%s) to be the previous realm or the caller", payer),
		))
	}
}
