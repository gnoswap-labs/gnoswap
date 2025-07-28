package router

import (
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"

	fuzzer "gno.land/p/gnoswap/fuzztest"
	i256 "gno.land/p/gnoswap/int256"
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

// TestFuzzParseRoutes tests the ParseRoutes validation function directly
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

// TestFuzzValidateQuoteSum tests the ValidateQuoteSum function directly
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
		{"50", "50", "1"},  // Sum to 101
		{"30", "30", "30"}, // Sum to 90
		{"0", "100"},       // Contains 0
		{"101"},            // Single quote > 100
		{"-10", "110"},     // Negative quote
	}

	for _, quotes := range invalidQuotesTests {
		err := parser.ValidateQuoteSum(quotes)
		if err == nil {
			t.Errorf("ValidateQuoteSum should fail for invalid quotes: %v", quotes)
		}
	}
}

// TestFuzzSwapValidatorAmount tests the amount validation function directly
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

func isValidNumber(s string) bool {
	if s == "" {
		return false
	}
	matched, _ := regexp.MatchString(`^-?\d+$`, s)
	return matched
}
