package pool

import (
	ufmt "gno.land/p/nt/ufmt/v0"
	pl "gno.land/r/gnoswap/pool"
)

func assertIsNotUserCall(_ int, rlm realm) {
	previousRealm := rlm.Previous()
	if previousRealm.IsUserCall() {
		panic(newErrorWithDetail(
			errNotAccessEOA,
			ufmt.Sprintf("previousRealm(%s) is EOA", previousRealm.Address()),
		))
	}
}

// assertIsNotEqualsTokens asserts that the token0Path and token1Path are not equal.
// Parameters:
//   - token0Path: first token contract path to compare.
//   - token1Path: second token contract path to compare; must differ from
//     token0Path.
func assertIsNotEqualsTokens(token0Path, token1Path string) {
	if token0Path == token1Path {
		panic(newErrorWithDetail(
			errDuplicateTokenInPool,
			ufmt.Sprintf("expected token0Path(%s) != token1Path(%s)", token0Path, token1Path),
		))
	}
}

// assertIsSupportedFeeTier asserts that the fee is a supported fee tier.
// Parameters:
//   - fee: pool fee tier, which must be one of the supported fee constants.
func assertIsSupportedFeeTier(fee uint32) {
	if !isValidFeeTier(fee) {
		panic(newErrorWithDetail(
			errUnsupportedFeeTier,
			ufmt.Sprintf("expected fee(%d) to be one of %d, %d, %d, %d", fee, FeeTier100, FeeTier500, FeeTier3000, FeeTier10000),
		))
	}
}

// assertIsNotExistsPoolPath asserts that the pool path does not exist.
// Parameters:
//   - instance: pool implementation whose stored pool tree is checked.
//   - token0Path: first token contract path used to derive the candidate pool
//     path.
//   - token1Path: second token contract path used to derive the candidate pool
//     path.
//   - fee: fee tier included in the candidate pool path.
func assertIsNotExistsPoolPath(instance *poolV1, token0Path, token1Path string, fee uint32) {
	poolPath := pl.GetPoolPath(token0Path, token1Path, fee)

	pools := instance.store.GetPools()
	if pools.Has(poolPath) {
		panic(newErrorWithDetail(
			errPoolAlreadyExists,
			ufmt.Sprintf("expected poolPath(%s:%s:%d) not to exist", token0Path, token1Path, fee),
		))
	}
}

func assertIsValidTokenOrder(token0Path, token1Path string) {
	if token0Path >= token1Path {
		panic(newErrorWithDetail(
			errInvalidInput,
			ufmt.Sprintf("expected token0Path(%s) < token1Path(%s)", token0Path, token1Path),
		))
	}
}
