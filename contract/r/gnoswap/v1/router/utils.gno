package router

import (
	"bytes"
	"strconv"
	"strings"
	"time"

	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/v1/pool"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

var (
	errRouterHalted = "router contract operations are currently disabled"
	errTxExpired    = "transaction too old, now(%d) > deadline(%d)"
)

// assertHopsInRange ensures the number of hops is within the valid range of 1-3.
func assertHopsInRange(hops int) {
	switch hops {
	case 1, 2, 3:
		return
	default:
		panic(errHopsOutOfRange)
	}
}

// assertIsNotPassedDeadline ensures the transaction deadline has not expired.
func assertIsNotPassedDeadline(deadline int64) {
	if err := checkDeadline(deadline); err != nil {
		errMsg := addDetailToError(errExpired, err.Error())
		panic(errMsg)
	}
}

// getDataForSinglePath extracts token addresses and fee from a single pool path.
//
// IMPORTANT: This function returns tokens in the order they appear in the route string,
// which represents the swap direction (tokenIn:tokenOut:fee), NOT the canonical pool ordering.
func getDataForSinglePath(poolPath string) (token0, token1 string, fee uint32) {
	token0, token1, fee, err := getDataForSinglePathWithError(poolPath)
	if err != nil {
		panic(err)
	}

	return token0, token1, fee
}

// getDataForSinglePathWithError extracts token addresses and fee from a single pool path with error handling.
func getDataForSinglePathWithError(poolPath string) (string, string, uint32, error) {
	poolPathSplit := strings.Split(poolPath, ":")
	if len(poolPathSplit) != 3 {
		return "", "", 0, makeErrorWithDetails(
			errInvalidPoolPath,
			ufmt.Sprintf("len(poolPathSplit) != 3, poolPath: %s", poolPath),
		)
	}

	f, err := strconv.Atoi(poolPathSplit[2])
	if err != nil {
		return "", "", 0, makeErrorWithDetails(
			errInvalidPoolPath,
			ufmt.Sprintf("invalid fee: %s", poolPathSplit[2]),
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

	return poolPathSplit[0], poolPathSplit[1], uint32(f), nil
}

// getDataForMultiPath extracts token addresses and fee from a multi-hop path at specified index.
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

// i256MinMax returns the absolute values of x and y in min-max order.
func i256MinMax(x, y *i256.Int) (min, max *u256.Uint) {
	if x.Lt(y) || x.Eq(y) {
		return x.Abs(), y.Abs()
	}
	return y.Abs(), x.Abs()
}

// validateRoutePaths validates multiple route paths to ensure they all start with inputToken and end with outputToken.
// This function processes comma-separated route paths and validates each path individually.
//
// Validates:
// - Each route path starts with the specified inputToken
// - Each route path ends with the specified outputToken
// - Route path format consistency (prevents swap-direction vs alphabetical pool ordering confusion)
//
// Parameters:
// - routePathArrString: comma-separated route paths (e.g., "gno.land/r/demo/wugnot:gno.land/r/demo/usdc:500,gno.land/r/demo/wugnot:gno.land/r/demo/gns:3000*POOL*gno.land/r/demo/gns:gno.land/r/demo/usdc:500")
// - inputToken: expected first token in all route paths
// - outputToken: expected last token in all route paths
//
// Examples:
// - Single route: "tokenA:tokenB:500" with inputToken="tokenA", outputToken="tokenB"
// - Multi-route: "tokenA:tokenB:500,tokenA:tokenC:3000*POOL*tokenC:tokenB:500" with inputToken="tokenA", outputToken="tokenB"
//
// Returns error if any route path validation fails.
func validateRoutePaths(routePathArrString, inputToken, outputToken string) error {
	routePaths := strings.Split(routePathArrString, ",")

	for _, routePath := range routePaths {
		if err := validateRoutePath(routePath, inputToken, outputToken); err != nil {
			return err
		}
	}

	return nil
}

// validateRoutePath validates a single route path to ensure it starts with inputToken and ends with outputToken.
// This function handles both single-hop and multi-hop route paths.
//
// Validates:
// - Route path starts with the specified inputToken
// - Route path ends with the specified outputToken
// - Proper token ordering in swap direction (not alphabetical pool ordering)
//
// Route Path Formats:
// - single-hop: "tokenA:tokenB:fee" (direct swap between two tokens)
// - multi-hop: "tokenA:tokenB:fee1*POOL*tokenB:tokenC:fee2" (swap through intermediate tokens)
//
// Parameters:
// - routePath: single route path string (e.g., "gno.land/r/demo/wugnot:gno.land/r/demo/usdc:500")
// - inputToken: expected first token in the route path
// - outputToken: expected last token in the route path
//
// Examples:
// - single-hop: "tokenA:tokenB:500" with inputToken="tokenA", outputToken="tokenB"
// - multi-hop: "tokenA:tokenB:3000*POOL*tokenB:tokenC:500" with inputToken="tokenA", outputToken="tokenC"
//
// Returns error with specific details if validation fails.
func validateRoutePath(routePath, inputToken, outputToken string) error {
	inputWrappedPath := inputToken
	outputWrappedPath := outputToken

	if common.IsGNOTNativePath(inputToken) {
		inputWrappedPath = common.WUGNOT_PATH
	}

	if common.IsGNOTNativePath(outputToken) {
		outputWrappedPath = common.WUGNOT_PATH
	}

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
	if firstToken != inputWrappedPath {
		return makeErrorWithDetails(errInvalidRouteFirstToken, ufmt.Sprintf("firstToken: %s, inputToken: %s", firstToken, inputWrappedPath))
	}

	if lastToken != outputWrappedPath {
		return makeErrorWithDetails(errInvalidRouteLastToken, ufmt.Sprintf("lastToken: %s, outputToken: %s", lastToken, outputWrappedPath))
	}

	return nil
}

// checkDeadline verifies that the transaction deadline has not passed.
func checkDeadline(deadline int64) error {
	now := time.Now().Unix()
	if now <= deadline {
		return nil
	}

	return ufmt.Errorf(errTxExpired, now, deadline)
}

// splitSingleChar splits a string by a single character separator.
// This function is optimized for splitting strings with a single-byte separator
// and is more memory efficient than strings.Split for this use case.
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

// formatUint formats an unsigned integer to string.
func formatUint(v any) string {
	switch v := v.(type) {
	case uint8:
		return strconv.FormatUint(uint64(v), 10)
	case uint32:
		return strconv.FormatUint(uint64(v), 10)
	case uint64:
		return strconv.FormatUint(v, 10)
	default:
		panic(ufmt.Sprintf("invalid type: %T", v))
	}
}

// formatInt64 formats a signed integer to string.
func formatInt64(v any) string {
	switch v := v.(type) {
	case int8:
		return strconv.FormatInt(int64(v), 10)
	case int16:
		return strconv.FormatInt(int64(v), 10)
	case int32:
		return strconv.FormatInt(int64(v), 10)
	case int64:
		return strconv.FormatInt(v, 10)
	default:
		panic(ufmt.Sprintf("invalid type %T", v))
	}
}

// safeConvertToInt64 safely converts a *u256.Uint value to an int64, ensuring no overflow.
//
// This function attempts to convert the given *u256.Uint value to an int64. If the value exceeds
// the maximum allowable range for int64 (`2^63 - 1`), it triggers a panic with a descriptive error message.
//
// Parameters:
// - value (*u256.Uint): The unsigned 256-bit integer to be converted.
//
// Returns:
// - int64: The converted value if it falls within the int64 range.
//
// Panics:
//   - If the `value` exceeds the range of int64, the function will panic with an error indicating
//     the overflow and the original value.
func safeConvertToInt64(value *u256.Uint) int64 {
	const INT64_MAX = 9223372036854775807
	const MAX_INT64 = "9223372036854775807"

	res, overflow := value.Uint64WithOverflow()
	if overflow || res > uint64(INT64_MAX) {
		panic(ufmt.Sprintf(
			"amount(%s) overflows int64 range (max %s)",
			value.ToString(),
			MAX_INT64,
		))
	}
	return int64(res)
}

// parsePoolPathsByRoutePathArr parses route path array string and returns a slice of pool paths.
// This function converts route paths (which maintain swap direction) into canonical pool paths
// (which use alphabetical token ordering).
//
// The function processes comma-separated route paths and extracts individual pool information
// from each route, ensuring tokens are ordered alphabetically for consistent pool identification.
//
// Parameters:
//   - routePathArr: comma-separated route paths string containing single or multi-hop routes
//     Format examples:
//   - Single route: "tokenA:tokenB:500"
//   - Multiple routes: "tokenA:tokenB:500,tokenC:tokenD:3000"
//   - Multi-hop routes: "tokenA:tokenB:500*POOL*tokenB:tokenC:3000"
//
// Returns:
// - []string: slice of canonical pool paths with alphabetically ordered tokens
// - error: parsing error if any route path is invalid
//
// Example:
//
//	input: "gno.land/r/demo/wugnot:gno.land/r/demo/usdc:500,gno.land/r/demo/usdc:gno.land/r/demo/gns:3000"
//	output: ["gno.land/r/demo/usdc:gno.land/r/demo/wugnot:500", "gno.land/r/demo/gns:gno.land/r/demo/usdc:3000"]
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

// BuildSingleHopPath creates a single-hop route path string.
// Format: "tokenA:tokenB:fee"
//
// Parameters:
// - tokenA: input token address
// - tokenB: output token address
// - fee: pool fee (e.g., 500, 3000, 10000)
//
// Returns:
// - string: formatted single-hop route path
//
// Example:
//   - BuildSingleHopPath("gno.land/r/demo/wugnot", "gno.land/r/demo/usdc", 500)
//     returns "gno.land/r/demo/wugnot:gno.land/r/demo/usdc:500"
func BuildSingleHopRoutePath(tokenA, tokenB string, fee uint32) string {
	if tokenA == "" || tokenB == "" {
		panic("token addresses cannot be empty")
	}
	if tokenA == tokenB {
		panic("tokenA and tokenB cannot be the same")
	}

	return ufmt.Sprintf("%s:%s:%s", tokenA, tokenB, formatUint(fee))
}

// BuildMultiHopPath creates a multi-hop route path string by connecting multiple single hops.
// Format: "tokenA:tokenB:fee1*POOL*tokenB:tokenC:fee2*POOL*tokenC:tokenD:fee3"
//
// Parameters:
// - hops: slice of single-hop path strings
//
// Returns:
// - string: formatted multi-hop route path
//
// Example:
//   - hops := []string{"tokenA:tokenB:500", "tokenB:tokenC:3000"}
//     returns "tokenA:tokenB:500*POOL*tokenB:tokenC:3000"
func BuildMultiHopRoutePath(hops ...string) string {
	if len(hops) < 1 {
		panic("multi-hop path requires at least 2 hops")
	}

	if len(hops) > 3 {
		panic("multi-hop path supports maximum 3 hops")
	}

	return strings.Join(hops, POOL_SEPARATOR)
}
