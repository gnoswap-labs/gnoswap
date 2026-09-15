package router

import (
	"errors"
	"strings"
	"time"

	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/common"
)

// assertIsNotExpired rejects a transaction whose deadline is earlier than the current Unix time.
//
// Parameters:
//   - deadline: transaction expiration as a Unix timestamp
func assertIsNotExpired(deadline int64) {
	now := time.Now().Unix()

	if now > deadline {
		panic(makeErrorWithDetails(
			errExpired,
			ufmt.Sprintf("transaction too old, now(%d) > deadline(%d)", now, deadline),
		))
	}
}

// assertSingleSwap validates that a single-pool swap uses distinct registered tokens.
//
// Parameters:
//   - p: single-pool swap parameters whose token paths are checked
func assertSingleSwap(p *SingleSwapParams) {
	if p.tokenIn == p.tokenOut {
		panic(errors.New(errSameTokenSwap))
	}

	common.MustRegistered(p.tokenIn, p.tokenOut)
}

// assertIsValidSqrtPriceLimitX96 validates a non-empty decimal Q64.96 price limit.
//
// Parameters:
//   - sqrtPriceLimitX96: decimal square-root price limit; empty or unparsable values panic
func assertIsValidSqrtPriceLimitX96(sqrtPriceLimitX96 string) {
	if sqrtPriceLimitX96 == "" {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("invalid sqrtPriceLimitX96: %s", sqrtPriceLimitX96),
		))
	}

	_, err := u256.FromDecimal(sqrtPriceLimitX96)
	if err != nil {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("invalid sqrtPriceLimitX96: %s", sqrtPriceLimitX96),
		))
	}
}

// assertIsValidSingleSwapRouteArrPath validates that routePaths is one connected single-hop route.
//
// Parameters:
//   - routePaths: route path to validate; commas and multi-hop separators are rejected
//   - inputToken: expected first token contract path
//   - outputToken: expected last token contract path
func assertIsValidSingleSwapRouteArrPath(routePaths, inputToken, outputToken string) {
	if routePaths == "" {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("invalid route: %s", routePaths),
		))
	}

	if strings.Count(routePaths, ",") > 0 {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("invalid routePaths: %s", routePaths),
		))
	}

	if strings.Count(routePaths, POOL_SEPARATOR) > 0 {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("invalid routePaths: %s", routePaths),
		))
	}

	assertIsValidRoutePaths(routePaths, inputToken, outputToken)
}

// assertIsValidRoutePaths validates all comma-separated routes against their endpoint tokens.
//
// Parameters:
//   - routePaths: comma-separated route paths to validate
//   - inputToken: expected first token contract path for every route
//   - outputToken: expected last token contract path for every route
func assertIsValidRoutePaths(routePaths, inputToken, outputToken string) {
	err := validateRoutePaths(routePaths, inputToken, outputToken)
	if err != nil {
		panic(err)
	}
}

// assertIsExistsPools verifies that every pool referenced by a route exists.
//
// Parameters:
//   - routePathArr: comma-separated and multi-hop route paths whose pools are checked
func assertIsExistsPools(routePathArr string) {
	poolPaths, err := parsePoolPathsByRoutePathArr(routePathArr)
	if err != nil {
		panic(err)
	}

	for _, poolPath := range poolPaths {
		if !pool.ExistsPoolPath(poolPath) {
			panic(makeErrorWithDetails(
				errInvalidInput,
				ufmt.Sprintf("pool does not exist: %s", poolPath),
			))
		}
	}
}

// assertIsRouterImplementation rejects callbacks not originating from the registered v1 implementation address.
//
// Parameters:
//   - caller: address reported as the callback caller
func assertIsRouterImplementation(caller address) {
	if caller != routerImplAddr {
		panic(makeErrorWithDetails(
			errUnAuthorizedCaller,
			ufmt.Sprintf("caller %s is not router implementation(%s)", caller, routerImplAddr),
		))
	}
}

// assertHopFullyConsumed rejects an exact-input hop that consumed less than requested.
//
// Parameters:
//   - hopIndex: zero-based route hop index used in error detail
//   - specifiedAmount: amount requested for the hop
//   - consumedAmount: amount actually consumed by the pool
func assertHopFullyConsumed(hopIndex int, specifiedAmount, consumedAmount int64) {
	err := validateHopFullyConsumed(hopIndex, specifiedAmount, consumedAmount)
	if err != nil {
		panic(err)
	}
}

// validateHopFullyConsumed checks whether an exact-input hop consumed its full request.
//
// Parameters:
//   - hopIndex: zero-based route hop index used in error detail
//   - specifiedAmount: amount requested for the hop
//   - consumedAmount: amount actually consumed by the pool
//
// Returns:
//   - err: nil when consumedAmount equals specifiedAmount; insufficient-liquidity error otherwise
func validateHopFullyConsumed(hopIndex int, specifiedAmount, consumedAmount int64) error {
	if consumedAmount != specifiedAmount {
		return makeErrorWithDetails(
			errInsufficientLiquidity,
			ufmt.Sprintf("partial fill on hop(%d): requested=%d, consumed=%d", hopIndex, specifiedAmount, consumedAmount),
		)
	}

	return nil
}
