package v3

import (
	"strconv"
	"strings"
	"time"

	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
)

// assertIsNotExpired ensures the transaction deadline has not passed.
func assertIsNotExpired(deadline int64) {
	now := time.Now().Unix()

	if now > deadline {
		panic(makeErrorWithDetails(
			errExpired,
			ufmt.Sprintf("transaction too old, now(%d) > deadline(%d)", now, deadline),
		))
	}
}

// assertIsValidUserCoinSend asserts that the user has sent the correct amount of native coin.
func assertIsValidUserCoinSend(tokenPath string, amount string) {
	if common.IsGNOTNativePath(tokenPath) {
		amountInt64, err := strconv.ParseInt(amount, 10, 64)
		if err != nil {
			panic(err)
		}

		common.AssertIsUserSendGNOTAmount(amountInt64)
	} else {
		common.AssertIsNotHandleNativeCoin()
	}
}

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

func assertIsValidRoutePaths(routePaths, inputToken, outputToken string) {
	err := validateRoutePaths(routePaths, inputToken, outputToken)
	if err != nil {
		panic(err)
	}
}

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

func assertIsRouterV1(caller address) {
	if caller != routerV1Addr {
		panic(makeErrorWithDetails(
			errUnAuthorizedCaller,
			ufmt.Sprintf("caller %s is not router v1(%s)", caller, routerV1Addr),
		))
	}
}
