package router

import (
	"bytes"
	"errors"
	"strconv"
	"strings"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	"gno.land/p/gnoswap/utils"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/pool"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// calculateSwapAmountByQuote allocates a signed swap amount by a route quote percentage.
//
// Parameters:
//   - amountSpecified: total signed amount to distribute across routes
//   - quote: decimal percentage string; must be within the configured quote range
//
// Returns:
//   - amount: allocated signed amount after percentage scaling
//   - err: nil for a valid quote producing a nonzero amount; parse, range, or zero-amount error otherwise
func calculateSwapAmountByQuote(amountSpecified int64, quote string) (int64, error) {
	quoteInt, err := strconv.ParseInt(quote, 10, 64)
	if err != nil {
		return 0, ufmt.Errorf("invalid quote(%s)", quote)
	}

	if quoteInt < MinQuotePercentage || quoteInt > MaxQuotePercentage {
		return 0, ufmt.Errorf(ErrInvalidQuoteRange, quoteInt, MinQuotePercentage, MaxQuotePercentage)
	}

	toSwap := gnsmath.SafeMulDivInt64(amountSpecified, quoteInt, PERCENTAGE_DENOMINATOR)
	if toSwap == 0 {
		return 0, errors.New(errInvalidSwapAmount)
	}

	return toSwap, nil
}

// assertHopsInRange panics unless the route contains one, two, or three pool hops.
//
// Parameters:
//   - hops: number of pools in the route
func assertHopsInRange(hops int) {
	switch hops {
	case 1, 2, 3:
		return
	default:
		panic(errors.New(errHopsOutOfRange))
	}
}

// getDataForSinglePath extracts the route-ordered token paths and fee from one pool path.
// Tokens remain in route direction rather than canonical pool ordering.
//
// Parameters:
//   - poolPath: single-hop path formatted as token0:token1:fee
//
// Returns:
//   - token0: first token path as written in poolPath
//   - token1: second token path as written in poolPath
//   - fee: parsed pool fee tier
func getDataForSinglePath(poolPath string) (token0, token1 string, fee uint32) {
	token0, token1, fee, err := getDataForSinglePathWithError(poolPath)
	if err != nil {
		panic(err)
	}

	return token0, token1, fee
}

// getDataForSinglePathWithError parses one token0:token1:fee path without panicking.
//
// Parameters:
//   - poolPath: single-hop path with exactly two non-empty token paths and a decimal fee
//
// Returns:
//   - token0: first token path as written in poolPath, or empty on error
//   - token1: second token path as written in poolPath, or empty on error
//   - fee: parsed fee tier, or zero on error
//   - err: nil for a valid path; malformed path, empty token, or invalid fee error otherwise
func getDataForSinglePathWithError(poolPath string) (string, string, uint32, error) {
	poolPathSplit := strings.Split(poolPath, ":")
	if len(poolPathSplit) != 3 {
		return "", "", 0, makeErrorWithDetails(
			errInvalidPoolPath,
			ufmt.Sprintf("len(poolPathSplit) != 3, poolPath: %s", poolPath),
		)
	}

	poolPathSplit[0] = strings.TrimSpace(poolPathSplit[0])
	poolPathSplit[1] = strings.TrimSpace(poolPathSplit[1])

	if poolPathSplit[0] == "" || poolPathSplit[1] == "" {
		return "", "", 0, makeErrorWithDetails(
			errInvalidPoolPath,
			ufmt.Sprintf("token addresses cannot be empty: %s", poolPath),
		)
	}

	f, err := strconv.Atoi(poolPathSplit[2])
	if err != nil {
		return "", "", 0, makeErrorWithDetails(
			errInvalidPoolPath,
			ufmt.Sprintf("invalid fee: %s", poolPathSplit[2]),
		)
	}

	return poolPathSplit[0], poolPathSplit[1], uint32(f), nil
}

// getDataForMultiPath extracts route-ordered token paths and fee from one indexed hop.
//
// Parameters:
//   - possiblePath: multi-hop path whose hops are separated by POOL_SEPARATOR
//   - poolIdx: zero-based hop index; indexes outside 0-2 return zero values, while an in-range index must exist in possiblePath
//
// Returns:
//   - token0: first token path for the selected hop
//   - token1: second token path for the selected hop
//   - fee: selected hop's pool fee tier
func getDataForMultiPath(possiblePath string, poolIdx int) (token0, token1 string, fee uint32) {
	pools := strings.Split(possiblePath, POOL_SEPARATOR)

	switch poolIdx {
	case 0:
		return getDataForSinglePath(pools[0])
	case 1:
		return getDataForSinglePath(pools[1])
	case 2:
		return getDataForSinglePath(pools[2])
	default:
		return "", "", uint32(0)
	}
}

// i256MinMax returns absolute values in the order selected by signed comparison of x and y.
//
// Parameters:
//   - x: signed integer whose absolute value is compared
//   - y: signed integer whose absolute value is compared
//
// Returns:
//   - min: absolute value of x when x <= y, otherwise absolute value of y
//   - max: absolute value of y when x <= y, otherwise absolute value of x
func i256MinMax(x, y *i256.Int) (min, max *u256.Uint) {
	if x.Lt(y) || x.Eq(y) {
		return x.Abs(), y.Abs()
	}
	return y.Abs(), x.Abs()
}

// validateRoutePaths validates every comma-separated route against common endpoints
// and checks hop-to-hop continuity.
//
// Parameters:
//   - routePathArrString: comma-separated route paths to validate
//   - inputToken: expected first token path for every route
//   - outputToken: expected last token path for every route
//
// Returns:
//   - err: nil when all routes are valid; the first route or continuity validation error otherwise
func validateRoutePaths(routePathArrString, inputToken, outputToken string) error {
	routePaths := strings.Split(routePathArrString, ",")

	for _, routePath := range routePaths {
		if err := validateRoutePath(routePath, inputToken, outputToken); err != nil {
			return err
		}
	}

	return nil
}

// validateRoutePath validates one single-hop or multi-hop route against its endpoints.
//
// Parameters:
//   - routePath: route containing one or more token:token:fee hops
//   - inputToken: expected first token path
//   - outputToken: expected last token path
//
// Returns:
//   - err: nil when route format, hop continuity, and endpoints are valid; a detailed validation error otherwise
func validateRoutePath(routePath, inputToken, outputToken string) error {
	// Extract first and last tokens from the routePath
	var (
		firstToken, lastToken string
		err                   error
	)

	// multi-hop routePath
	if strings.Contains(routePath, POOL_SEPARATOR) {
		pools := strings.Split(routePath, POOL_SEPARATOR)

		// Get first token from first pool
		firstPool := pools[0]
		firstToken, _, _, err = getDataForSinglePathWithError(firstPool)
		if err != nil {
			return err
		}

		// Validate hop-to-hop continuity: output token of hop N must equal input token of hop N+1
		err = validatePoolPathHopContinuity(pools)
		if err != nil {
			return err
		}

		// Get last token from last pool
		lastPool := pools[len(pools)-1]
		_, lastToken, _, err = getDataForSinglePathWithError(lastPool)
		if err != nil {
			return err
		}
	} else {
		// single-hop routePath
		firstToken, lastToken, _, err = getDataForSinglePathWithError(routePath)
		if err != nil {
			return err
		}
	}

	if firstToken == "" || lastToken == "" {
		return makeErrorWithDetails(errInvalidRoutePath, ufmt.Sprintf("firstToken: %s, lastToken: %s", firstToken, lastToken))
	}

	// Validate consistency
	if firstToken != inputToken {
		return makeErrorWithDetails(errInvalidRouteFirstToken, ufmt.Sprintf("firstToken: %s, inputToken: %s", firstToken, inputToken))
	}

	if lastToken != outputToken {
		return makeErrorWithDetails(errInvalidRouteLastToken, ufmt.Sprintf("lastToken: %s, outputToken: %s", lastToken, outputToken))
	}

	return nil
}

func validatePoolPathHopContinuity(routePoolPaths []string) error {
	if len(routePoolPaths) < 2 {
		return nil
	}

	_, previousOut, _, pErr := getDataForSinglePathWithError(routePoolPaths[0])
	if pErr != nil {
		return pErr
	}

	for i := 1; i < len(routePoolPaths); i++ {
		nextIn, nextOut, _, nErr := getDataForSinglePathWithError(routePoolPaths[i])
		if nErr != nil {
			return nErr
		}

		if previousOut != nextIn {
			return makeErrorWithDetails(
				errRouteHopDisconnected,
				ufmt.Sprintf("hop %d output(%s) != hop %d input(%s)", i-1, previousOut, i, nextIn),
			)
		}

		previousOut = nextOut
	}

	return nil
}

// splitSingleChar splits a string on one byte separator while preserving empty segments.
//
// Parameters:
//   - s: string to split
//   - sep: single-byte separator
//
// Returns:
//   - parts: segments in order, including empty leading, trailing, or repeated-separator segments
func splitSingleChar(s string, sep byte) []string {
	if s == "" {
		return []string{""}
	}

	result := make([]string, 0, bytes.Count([]byte(s), []byte{sep})+1)
	start := 0
	for i := range s {
		if s[i] == sep {
			result = append(result, s[start:i])
			start = i + 1
		}
	}
	result = append(result, s[start:])
	return result
}

// parsePoolPathsByRoutePathArr converts route-direction paths to canonical pool paths.
//
// Parameters:
//   - routePathArr: comma-separated single- or multi-hop route paths
//
// Returns:
//   - poolPaths: canonical pool paths with alphabetically ordered token endpoints
//   - err: nil on successful parsing; malformed hop-path error otherwise
func parsePoolPathsByRoutePathArr(routePathArr string) ([]string, error) {
	poolPaths := make([]string, 0)

	for _, routePaths := range strings.Split(routePathArr, ",") {
		for _, routePath := range strings.Split(routePaths, POOL_SEPARATOR) {
			token0Path, token1Path, fee, err := getDataForSinglePathWithError(routePath)
			if err != nil {
				return []string{}, err
			}

			if token0Path > token1Path {
				token0Path, token1Path = token1Path, token0Path
			}

			poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
			poolPaths = append(poolPaths, poolPath)
		}
	}

	return poolPaths, nil
}

// BuildSingleHopRoutePath formats one route-direction single-hop path.
//
// Parameters:
//   - tokenA: input token contract path
//   - tokenB: output token contract path
//   - fee: pool fee tier appended as a decimal value
//
// Returns:
//   - routePath: tokenA:tokenB:fee formatted route string; panics for empty or identical tokens
func BuildSingleHopRoutePath(tokenA, tokenB string, fee uint32) string {
	if tokenA == "" || tokenB == "" {
		panic("token addresses cannot be empty")
	}
	if tokenA == tokenB {
		panic("tokenA and tokenB cannot be the same")
	}

	return tokenA + ":" + tokenB + ":" + utils.FormatUint(fee)
}
