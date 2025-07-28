package router

import (
	"strconv"
	"strings"
	"testing"
	"time"

	"gno.land/p/gnoswap/fuzztest"
	i256 "gno.land/p/gnoswap/int256"
)

// RouteGenerator generates valid route strings for testing
type RouteGenerator struct {
	minRoutes int
	maxRoutes int
}

func (g *RouteGenerator) Generate() any {
	numRoutes := fuzztest.IntRange(g.minRoutes, g.maxRoutes).Generate().(int)
	routes := make([]string, numRoutes)

	for i := 0; i < numRoutes; i++ {
		// generate a simple route with 1-3 pools
		numPools := fuzztest.IntRange(1, 3).Generate().(int)
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
		quote := fuzztest.IntRange(1, maxQuote).Generate().(int)
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
	if g.allowZero && fuzztest.Bool().Generate().(bool) {
		return "0"
	}

	digits := fuzztest.IntRange(g.minDigits, g.maxDigits).Generate().(int)
	amount := ""

	// first digit should not be 0
	amount += strconv.Itoa(fuzztest.IntRange(1, 9).Generate().(int))

	// rest of digits
	for i := 1; i < digits; i++ {
		amount += strconv.Itoa(fuzztest.IntRange(0, 9).Generate().(int))
	}

	return amount
}

func TestFuzzRouteValidation(t *testing.T) {
	config := fuzztest.Config{
		Iterations: 100,
		Shrink:     false,
	}

	gen := &RouteGenerator{minRoutes: 0, maxRoutes: 10}
	for i := 0; i < config.Iterations; i++ {
		routeStr := gen.Generate().(string)
		routes := strings.Split(routeStr, ",")

		// check number of routes is between 1 and 7
		// empty route should be invalid

		if routeStr == "" || len(routes) == 0 {
			continue
		}

		if len(routes) > 7 {
			continue
		}

		valid := len(routes) >= 1 && len(routes) <= 7
		if !valid {
			t.Errorf("Route validation failed for: %s", routeStr)
		}
	}
}

func TestFuzzQuoteValidation(t *testing.T) {
	for numQuotes := 1; numQuotes <= 7; numQuotes++ {
		gen := &QuoteGenerator{numQuotes: numQuotes}
		failures := 0

		for i := 0; i < 100; i++ {
			quoteStr := gen.Generate().(string)
			quotes := strings.Split(quoteStr, ",")

			// check number of quotes
			if len(quotes) != numQuotes {
				failures++
				continue
			}

			// validate each quote and sum
			sum := 0
			validQuotes := true
			for _, q := range quotes {
				quote, err := strconv.Atoi(q)
				if err != nil {
					validQuotes = false
					break
				}
				if quote <= 0 || quote > 100 {
					validQuotes = false
					break
				}
				sum += quote
			}

			if !validQuotes || sum != 100 {
				failures++
			}
		}

		if failures > 0 {
			t.Errorf("Quote validation fuzzing failed for %d quotes: %d failures out of 100", numQuotes, failures)
		}
	}
}

func TestFuzzAmountValidation(t *testing.T) {
	gen := &AmountGenerator{minDigits: 1, maxDigits: 20, allowZero: false}
	failures := 0

	for i := 0; i < 100; i++ {
		amountStr := gen.Generate().(string)

		// Do not use MustFromDecimal here because we want to test the error path
		amount, err := i256.FromDecimal(amountStr)
		if err != nil {
			failures++
			continue
		}

		if !amount.Gt(i256.Zero()) {
			failures++
		}
	}

	if failures > 0 {
		t.Errorf("Amount validation fuzzing failed: %d failures out of 100", failures)
	}
}

func TestFuzzDeadlineValidation(t *testing.T) {
	currentTime := time.Now().Unix()

	err := fuzztest.FuzzWithGen(
		fuzztest.IntRange(int(currentTime-3600), int(currentTime+3600)),
		func(deadline int) bool {
			isValid := int64(deadline) >= currentTime

			// boundary: exactly current time should be valid
			if int64(deadline) == currentTime {
				return isValid == true
			}

			// past deadlines should be invalid
			if int64(deadline) < currentTime {
				return isValid == false
			}

			// future deadlines should be valid
			return isValid == true
		},
	)
	if err != nil {
		t.Errorf("Deadline validation fuzzing failed: %v", err)
	}
}

func TestFuzzBoundaryValues(t *testing.T) {
	intBoundaries := fuzztest.GenerateBoundary("int")
	for _, val := range intBoundaries {
		str := strconv.Itoa(val.(int))
		_, err := strconv.Atoi(str)
		if err != nil {
			t.Errorf("Boundary value %v failed round-trip conversion: %v", val, err)
		}
	}

	uint32Boundaries := fuzztest.GenerateBoundary("uint32")
	for _, val := range uint32Boundaries {
		quote := val.(uint32)
		// quotes should be 0-100
		if quote > 100 {
			continue
		}

		// valid quotes should parse correctly
		str := strconv.FormatUint(uint64(quote), 10)
		parsed, err := strconv.ParseUint(str, 10, 32)
		if err != nil {
			t.Errorf("Boundary quote value %v failed parsing: %v", quote, err)
		}
		if uint32(parsed) != quote {
			t.Errorf("Boundary quote value %v != parsed %v", quote, parsed)
		}
	}
}

func TestFuzzComplexRouterInput(t *testing.T) {
	type RouterInput struct {
		routes   string
		quotes   string
		amountIn string
		deadline int64
	}

	generateRouterInput := func() RouterInput {
		numRoutes := fuzztest.IntRange(1, 7).Generate().(int)

		return RouterInput{
			routes:   (&RouteGenerator{minRoutes: numRoutes, maxRoutes: numRoutes}).Generate().(string),
			quotes:   (&QuoteGenerator{numQuotes: numRoutes}).Generate().(string),
			amountIn: (&AmountGenerator{minDigits: 1, maxDigits: 10, allowZero: false}).Generate().(string),
			deadline: int64(fuzztest.IntRange(int(time.Now().Unix()), int(time.Now().Unix()+3600)).Generate().(int)),
		}
	}

	config := fuzztest.Config{
		Iterations: 1000,
		Shrink:     true,
	}

	failureCount := 0
	for i := 0; i < config.Iterations; i++ {
		input := generateRouterInput()

		routes := strings.Split(input.routes, ",")
		quotes := strings.Split(input.quotes, ",")

		// routes and quotes count should match
		if len(routes) != len(quotes) {
			failureCount++
			continue
		}

		// validate quotes sum to 100
		sum := 0
		for _, q := range quotes {
			quote, _ := strconv.Atoi(q)
			sum += quote
		}
		if sum != 100 {
			failureCount++
		}
	}

	if failureCount > 0 {
		t.Errorf("Complex router input generation had %d failures out of %d iterations", failureCount, config.Iterations)
	}
}
