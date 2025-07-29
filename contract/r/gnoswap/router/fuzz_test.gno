package router

import (
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"

	fuzzer "gno.land/p/gnoswap/fuzztest"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// RouteGenerator generates valid route strings for testing
type RouteGenerator struct {
	minRoutes int
	maxRoutes int
}

func (g *RouteGenerator) Generate() any {
	numRoutes := fuzzer.IntRange(g.minRoutes, g.maxRoutes).Generate().(int)
	routes := make([]string, numRoutes)

	for i := 0; i < numRoutes; i++ {
		// generate a simple route with 1-3 pools
		numPools := fuzzer.IntRange(1, 3).Generate().(int)
		pools := make([]string, numPools)
		for j := 0; j < numPools; j++ {
			pools[j] = "pool" + strconv.Itoa(j)
		}
		routes[i] = strings.Join(pools, "*POOL*")
	}

	return strings.Join(routes, ",")
}

// QuoteGenerator generates valid quote arrays that sum to 100
type QuoteGenerator struct {
	numQuotes int
}

func (g *QuoteGenerator) Generate() any {
	if g.numQuotes == 1 {
		return "100"
	}

	quotes := make([]int, g.numQuotes)
	remaining := 100

	// distribute quotes randomly but ensure they sum to 100
	for i := 0; i < g.numQuotes-1; i++ {
		maxQuote := remaining - (g.numQuotes - i - 1) // leave at least 1 for each remaining
		if maxQuote > 50 {
			maxQuote = 50 // cap individual quotes at 50%
		}
		quote := fuzzer.IntRange(1, maxQuote).Generate().(int)
		quotes[i] = quote
		remaining -= quote
	}
	quotes[g.numQuotes-1] = remaining

	quoteStrs := make([]string, g.numQuotes)
	for i, q := range quotes {
		quoteStrs[i] = strconv.Itoa(q)
	}

	return strings.Join(quoteStrs, ",")
}

// AmountGenerator generates valid amount strings
type AmountGenerator struct {
	minDigits int
	maxDigits int
	allowZero bool
}

func (g *AmountGenerator) Generate() any {
	if g.allowZero && fuzzer.Bool().Generate().(bool) {
		return "0"
	}

	digits := fuzzer.IntRange(g.minDigits, g.maxDigits).Generate().(int)
	amount := ""

	// first digit should not be 0
	amount += strconv.Itoa(fuzzer.IntRange(1, 9).Generate().(int))

	// rest of digits
	for i := 1; i < digits; i++ {
		amount += strconv.Itoa(fuzzer.IntRange(0, 9).Generate().(int))
	}

	return amount
}

func TestFuzzParseRoutes(t *testing.T) {
	parser := &RouteParser{}
	gen := &RouteGenerator{minRoutes: 0, maxRoutes: 10}
	failures := 0

	for i := 0; i < 1000; i++ {
		routeStr := gen.Generate().(string)
		numRoutes := len(strings.Split(routeStr, ","))

		// Generate matching quotes
		quoteGen := &QuoteGenerator{numQuotes: numRoutes}
		quoteStr := quoteGen.Generate().(string)

		routes, quotes, err := parser.ParseRoutes(routeStr, quoteStr)

		// Empty routes should error
		if routeStr == "" {
			if err == nil {
				failures++
				t.Errorf("ParseRoutes should fail for empty route string")
			}
			continue
		}

		// More than 7 routes should error
		if numRoutes > 7 {
			if err == nil {
				failures++
				t.Errorf("ParseRoutes should fail for %d routes (max 7)", numRoutes)
			}
			continue
		}

		// Valid routes should pass
		if numRoutes >= 1 && numRoutes <= 7 {
			if err != nil {
				failures++
				t.Errorf("ParseRoutes failed for valid input: routes=%s, quotes=%s, error=%v", routeStr, quoteStr, err)
			} else {
				// Verify parsed results
				if len(routes) != numRoutes || len(quotes) != numRoutes {
					failures++
					t.Errorf("ParseRoutes returned wrong count: expected %d, got routes=%d, quotes=%d", numRoutes, len(routes), len(quotes))
				}
			}
		}
	}

	if failures > 0 {
		t.Errorf("ParseRoutes fuzzing had %d failures out of 1000 iterations", failures)
	}
}

func TestFuzzValidateQuoteSum(t *testing.T) {
	parser := &RouteParser{}

	// Test valid quotes that sum to 100
	for numQuotes := 1; numQuotes <= 7; numQuotes++ {
		gen := &QuoteGenerator{numQuotes: numQuotes}

		for i := 0; i < 100; i++ {
			quoteStr := gen.Generate().(string)
			quotes := strings.Split(quoteStr, ",")

			err := parser.ValidateQuoteSum(quotes)
			if err != nil {
				t.Errorf("ValidateQuoteSum failed for valid quotes: %v, error: %v", quotes, err)
			}
		}
	}

	// Test invalid quotes
	invalidQuotesTests := [][]string{
		{"50", "50", "1"},  /* sum to 101 */
		{"30", "30", "30"}, /* sum to 90 */
		{"0", "100"},       /* contains 0 */
		{"101"},            /* single quote > 100 */
		{"-10", "110"},     /* negative quote */
	}

	for _, quotes := range invalidQuotesTests {
		err := parser.ValidateQuoteSum(quotes)
		if err == nil {
			t.Errorf("ValidateQuoteSum should fail for invalid quotes: %v", quotes)
		}
	}
}

func TestFuzzSwapValidatorAmount(t *testing.T) {
	validator := &SwapValidator{}
	gen := &AmountGenerator{minDigits: 1, maxDigits: 20, allowZero: true}

	for i := 0; i < 1000; i++ {
		amountStr := gen.Generate().(string)

		parsedAmount, err := validator.amount(amountStr)

		if amountStr == "0" {
			// Zero amounts should fail
			if err == nil {
				t.Errorf("amount() should fail for zero amount")
			}
			continue
		}

		// Positive amounts should pass
		if err != nil {
			t.Errorf("amount() failed for valid amount %s: %v", amountStr, err)
		} else {
			// Verify the amount is positive
			if !parsedAmount.Gt(i256.Zero()) {
				t.Errorf("amount() returned non-positive value for %s", amountStr)
			}
		}
	}

	// Test boundary values
	boundaryTests := []struct {
		input       string
		shouldPanic bool
		shouldFail  bool
	}{
		{"1", false, false}, // Minimum valid
		{"115792089237316195423570985008687907853269984665640564039457584007913129639935", false, false}, // Max uint256
		{"-1", false, true}, // Negative (should fail)
		{"0", false, false}, // Zero (allowed for amount, but not ideal)
		{"abc", true, true}, // Non-numeric (should panic)
		{"", true, true},    // Empty (should panic)
		{"1.5", true, true}, // Decimal (should panic)
	}

	for _, test := range boundaryTests {
		t.Run("boundary_"+test.input, func(t *testing.T) {
			if test.shouldPanic {
				// Use defer/recover to handle expected panics
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("amount() should panic for invalid value %s", test.input)
					}
				}()
			}

			result, err := validator.amount(test.input)

			if !test.shouldPanic {
				if test.shouldFail && err == nil {
					t.Errorf("amount() should fail for value %s", test.input)
				} else if !test.shouldFail && err != nil {
					t.Errorf("amount() failed for valid value %s: %v", test.input, err)
				} else if !test.shouldFail && result.Lt(i256.Zero()) {
					t.Errorf("amount() returned non-positive value for %s", test.input)
				}
			}
		})
	}
}

// TestFuzzAmountLimit tests the amountLimit validation function directly
func TestFuzzAmountLimit(t *testing.T) {
	validator := &SwapValidator{}
	gen := &AmountGenerator{minDigits: 1, maxDigits: 20, allowZero: true}

	for i := 0; i < 1000; i++ {
		amountStr := gen.Generate().(string)

		parsedAmount, err := validator.amountLimit(amountStr)

		if amountStr == "0" {
			// Zero limits should fail
			if err == nil {
				t.Errorf("amountLimit() should fail for zero limit")
			}
			continue
		}

		// Non-zero amounts should pass
		if err != nil {
			t.Errorf("amountLimit() failed for valid limit %s: %v", amountStr, err)
		} else {
			// Verify the amount is not zero
			if parsedAmount.IsZero() {
				t.Errorf("amountLimit() returned zero for %s", amountStr)
			}
		}
	}
}

// TestFuzzCheckDeadline tests the checkDeadline function directly
func TestFuzzCheckDeadline(t *testing.T) {
	currentTime := time.Now().Unix()

	// Generate deadlines around current time
	gen := fuzzer.IntRange(int(currentTime-3600), int(currentTime+3600))

	for i := 0; i < 1000; i++ {
		deadline := int64(gen.Generate().(int))

		err := checkDeadline(deadline)

		if deadline < currentTime {
			// Past deadlines should fail
			if err == nil {
				t.Errorf("checkDeadline() should fail for past deadline %d (current: %d)", deadline, currentTime)
			}
		} else {
			// Current or future deadlines should pass
			if err != nil {
				t.Errorf("checkDeadline() failed for valid deadline %d (current: %d): %v", deadline, currentTime, err)
			}
		}
	}
}

// TestFuzzSwapType tests the swapType validation function directly
func TestFuzzSwapType(t *testing.T) {
	validator := &SwapValidator{}

	// Valid swap types
	validTypes := []string{"EXACT_IN", "EXACT_OUT"}
	for _, swapTypeStr := range validTypes {
		swapType, err := validator.swapType(swapTypeStr)
		if err != nil {
			t.Errorf("swapType() failed for valid type %s: %v", swapTypeStr, err)
		}

		// Verify correct mapping
		if swapTypeStr == "EXACT_IN" && swapType != ExactIn {
			t.Errorf("swapType() returned wrong type for EXACT_IN")
		}
		if swapTypeStr == "EXACT_OUT" && swapType != ExactOut {
			t.Errorf("swapType() returned wrong type for EXACT_OUT")
		}
	}

	// Invalid swap types
	invalidTypes := []string{
		"EXACT_IN_OUT",
		"exact_in", // Wrong case
		"ExactIn",  // Wrong format
		"",         // Empty
		"INVALID",
		"1",
	}

	for _, swapTypeStr := range invalidTypes {
		_, err := validator.swapType(swapTypeStr)
		if err == nil {
			t.Errorf("swapType() should fail for invalid type: %s", swapTypeStr)
		}
	}
}

// TestFuzzValidateRoutesAndQuotes tests the complete validation flow
func TestFuzzValidateRoutesAndQuotes(t *testing.T) {
	for i := 0; i < 1000; i++ {
		numRoutes := fuzzer.IntRange(0, 10).Generate().(int)

		// Generate routes
		routeGen := &RouteGenerator{minRoutes: numRoutes, maxRoutes: numRoutes}
		routeStr := routeGen.Generate().(string)

		// Generate quotes
		quoteGen := &QuoteGenerator{numQuotes: numRoutes}
		quoteStr := quoteGen.Generate().(string)

		// Call the convenience function
		routes, quotes, err := validateRoutesAndQuotes(routeStr, quoteStr)

		// Verify results
		if numRoutes == 0 || numRoutes > 7 {
			// Should fail
			if err == nil {
				t.Errorf("validateRoutesAndQuotes should fail for %d routes", numRoutes)
			}
		} else {
			// Should pass
			if err != nil {
				t.Errorf("validateRoutesAndQuotes failed for valid input: routes=%d, error=%v", numRoutes, err)
			} else {
				if len(routes) != numRoutes || len(quotes) != numRoutes {
					t.Errorf("validateRoutesAndQuotes returned wrong count: expected %d, got routes=%d, quotes=%d",
						numRoutes, len(routes), len(quotes))
				}
			}
		}
	}
}

func TestFuzzGetDataForSinglePath(t *testing.T) {
	// format: "token0:token1:fee"
	validTokens := []string{"gno.land/r/demo/token0", "gno.land/r/demo/token1", "gno.land/r/demo/wugnot"}
	validFees := []uint32{100, 500, 3000, 10000}

	// valid paths
	for i := 0; i < 100; i++ {
		token0 := validTokens[fuzzer.IntRange(0, len(validTokens)-1).Generate().(int)]
		token1 := validTokens[fuzzer.IntRange(0, len(validTokens)-1).Generate().(int)]
		fee := validFees[fuzzer.IntRange(0, len(validFees)-1).Generate().(int)]

		if token0 == token1 {
			continue // skip same token pairs
		}

		poolPath := token0 + ":" + token1 + ":" + strconv.FormatUint(uint64(fee), 10)

		func() {
			defer func() {
				if r := recover(); r != nil {
					t.Errorf("getDataForSinglePath panicked for valid path %s: %v", poolPath, r)
				}
			}()

			token0Out, token1Out, feeOut := getDataForSinglePath(poolPath)

			if token0Out != token0 || token1Out != token1 || feeOut != fee {
				t.Errorf("getDataForSinglePath returned wrong data for %s: got %s:%s:%d",
					poolPath, token0Out, token1Out, feeOut)
			}
		}()
	}

	// invalid paths
	invalidPaths := []string{
		"",                        /* empty */
		"token0:token1",           /* missing fee */
		"token0",                  /* only one component */
		"token0:token1:fee:extra", /* extra component */
		"token0::fee",             /* empty token1 */
		":token1:fee",             /* empty token0 */
		"token0:token1:",          /* empty fee */
		"token0,token1,fee",       /* wrong separator */
	}

	for _, path := range invalidPaths {
		func() {
			defer func() {
				if r := recover(); r == nil {
					t.Errorf("getDataForSinglePath should panic for invalid path: %s", path)
				}
			}()

			getDataForSinglePath(path)
		}()
	}
}

func TestFuzzGetDataForMultiPath(t *testing.T) {
	// format: "token0:token1:fee"
	// the function extracts pool data at the given index

	for i := 0; i < 100; i++ {
		numPools := fuzzer.IntRange(1, 3).Generate().(int)
		pools := make([]string, numPools)

		for j := 0; j < numPools; j++ {
			token0 := "gno.land/r/demo/token" + strconv.Itoa(j)
			token1 := "gno.land/r/demo/token" + strconv.Itoa(j+1)
			fee := strconv.Itoa(fuzzer.IntRange(100, 10000).Generate().(int))
			pools[j] = token0 + ":" + token1 + ":" + fee
		}

		possiblePath := strings.Join(pools, "*POOL*")

		for poolIdx := 0; poolIdx < 3; poolIdx++ {
			func() {
				defer func() {
					if r := recover(); r != nil {
						// should panic for this case
						if poolIdx >= numPools {
							return
						}
						t.Errorf("getDataForMultiPath panicked for valid input: path=%s, idx=%d: %v",
							possiblePath, poolIdx, r)
					}
				}()

				token0Out, token1Out, feeOut := getDataForMultiPath(possiblePath, poolIdx)

				// verify we got valid data if within range
				if poolIdx < numPools {
					if token0Out == "" || token1Out == "" {
						t.Errorf("getDataForMultiPath returned empty tokens for idx=%d", poolIdx)
					}
					if feeOut == 0 {
						t.Errorf("getDataForMultiPath returned zero fee for idx=%d", poolIdx)
					}
				}
			}()
		}
	}

	invalidIndices := []int{-1, 3, 100}
	validPath := "gno.land/r/demo/token0:gno.land/r/demo/token1:500*POOL*gno.land/r/demo/token1:gno.land/r/demo/token2:3000"

	for _, idx := range invalidIndices {
		token0Out, token1Out, feeOut := getDataForMultiPath(validPath, idx)

		if token0Out != "" || token1Out != "" || feeOut != 0 {
			t.Errorf("getDataForMultiPath should return empty values for invalid index %d, got: %s, %s, %d",
				idx, token0Out, token1Out, feeOut)
		}
	}

	// out of bounds
	shortPath := "gno.land/r/demo/token0:gno.land/r/demo/token1:500"

	for poolIdx := 1; poolIdx <= 2; poolIdx++ {
		func() {
			defer func() {
				if r := recover(); r == nil {
					t.Errorf("getDataForMultiPath should panic for out of bounds access: path has 1 pool, accessing index %d", poolIdx)
				}
			}()

			getDataForMultiPath(shortPath, poolIdx)
		}()
	}
}

func TestFuzzAssertHopsInRange(t *testing.T) {
	// number of hops
	gen := fuzzer.IntRange(-10, 10)

	for i := 0; i < 100; i++ {
		hops := gen.Generate().(int)

		func() {
			defer func() {
				if r := recover(); r != nil {
					if hops >= 1 && hops <= 3 {
						t.Errorf("assertHopsInRange panicked for valid hop count %d: %v", hops, r)
					}
				} else {
					if hops < 1 || hops > 3 {
						t.Errorf("assertHopsInRange should panic for invalid hop count %d", hops)
					}
				}
			}()

			assertHopsInRange(hops)
		}()
	}
}

func TestFuzzSwapValidatorSlippage(t *testing.T) {
	validator := &SwapValidator{}

	// ExactIn slippage validation
	for i := 0; i < 100; i++ {
		amountIn := u256.NewUint(uint64(fuzzer.IntRange(100, 10000).Generate().(int)))
		amountOut := u256.NewUint(uint64(fuzzer.IntRange(50, 10000).Generate().(int)))
		limit := u256.NewUint(uint64(fuzzer.IntRange(1, 10000).Generate().(int)))

		err := validator.slippage(ExactIn, amountIn, amountOut, limit)

		if amountOut.Lt(limit) {
			// Should fail when output is less than limit
			if err == nil {
				t.Errorf("slippage validation should fail for ExactIn when output < limit: out=%s, limit=%s",
					amountOut.ToString(), limit.ToString())
			}
		} else {
			// Should pass when output >= limit
			if err != nil {
				t.Errorf("slippage validation failed for valid ExactIn: out=%s, limit=%s, err=%v",
					amountOut.ToString(), limit.ToString(), err)
			}
		}
	}

	// ExactOut slippage validation
	for i := 0; i < 100; i++ {
		amountIn := u256.NewUint(uint64(fuzzer.IntRange(100, 10000).Generate().(int)))
		amountOut := u256.NewUint(uint64(fuzzer.IntRange(50, 10000).Generate().(int)))
		limit := u256.NewUint(uint64(fuzzer.IntRange(1, 10000).Generate().(int)))

		err := validator.slippage(ExactOut, amountIn, amountOut, limit)

		if amountIn.Gt(limit) {
			// Should fail when input is greater than limit
			if err == nil {
				t.Errorf("slippage validation should fail for ExactOut when input > limit: in=%s, limit=%s",
					amountIn.ToString(), limit.ToString())
			}
		} else {
			// Should pass when input <= limit
			if err != nil {
				t.Errorf("slippage validation failed for valid ExactOut: in=%s, limit=%s, err=%v",
					amountIn.ToString(), limit.ToString(), err)
			}
		}
	}
}

func TestFuzzSwapValidatorExactOutAmount(t *testing.T) {
	validator := &SwapValidator{}

	for i := 0; i < 100; i++ {
		resultVal := uint64(fuzzer.IntRange(1, 10000).Generate().(int))
		specifiedVal := uint64(fuzzer.IntRange(1, 10000).Generate().(int))

		resultAmount := u256.NewUint(resultVal)
		specifiedAmount := u256.NewUint(specifiedVal)

		err := validator.exactOutAmount(resultAmount, specifiedAmount)

		if resultAmount.Lt(specifiedAmount) {
			// Should fail when result < specified
			if err == nil {
				t.Errorf("exactOutAmount should fail when result < specified: result=%d, specified=%d",
					resultVal, specifiedVal)
			}
		} else {
			// Should pass when result >= specified
			if err != nil {
				t.Errorf("exactOutAmount failed for valid amounts: result=%d, specified=%d, err=%v",
					resultVal, specifiedVal, err)
			}
		}
	}
}

func TestFuzzSplitSingleChar(t *testing.T) {
	// separator candidates (only `:` is valid)
	separators := []byte{',', ':', '*', '|'}

	for _, sep := range separators {
		for i := 0; i < 50; i++ {
			numParts := fuzzer.IntRange(1, 5).Generate().(int)
			parts := make([]string, numParts)

			for j := 0; j < numParts; j++ {
				parts[j] = "part" + strconv.Itoa(j)
			}

			input := strings.Join(parts, string(sep))
			result := splitSingleChar(input, sep)

			if len(result) != numParts {
				t.Errorf("splitSingleChar returned wrong number of parts: expected %d, got %d for input %s",
					numParts, len(result), input)
			}

			for j, part := range result {
				if part != parts[j] {
					t.Errorf("splitSingleChar returned wrong part at index %d: expected %s, got %s",
						j, parts[j], part)
				}
			}
		}
	}

	edgeCases := []struct {
		input    string
		sep      byte
		expected []string
	}{
		{"", ',', []string{""}},                /* empty string */
		{"single", ',', []string{"single"}},    /* no separator */
		{",", ',', []string{"", ""}},           /* only separator */
		{"a,,b", ',', []string{"a", "", "b"}},  /* consecutive separators */
		{",start", ',', []string{"", "start"}}, /* leading separator */
		{"end,", ',', []string{"end", ""}},     /* trailing separator */
	}

	for _, tc := range edgeCases {
		result := splitSingleChar(tc.input, tc.sep)

		if len(result) != len(tc.expected) {
			t.Errorf("splitSingleChar(%q, %c) returned wrong length: expected %d, got %d",
				tc.input, tc.sep, len(tc.expected), len(result))
			continue
		}

		for i, part := range result {
			if part != tc.expected[i] {
				t.Errorf("splitSingleChar(%q, %c) wrong part at index %d: expected %q, got %q",
					tc.input, tc.sep, i, tc.expected[i], part)
			}
		}
	}
}

func isValidNumber(s string) bool {
	if s == "" {
		return false
	}
	matched, _ := regexp.MatchString(`^-?\d+$`, s)
	return matched
}
