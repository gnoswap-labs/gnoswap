package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestRouteParser_ParseRoutesWithQuoteInts_HopCalculation tests that ParseRoutesWithQuoteInts
// correctly calculates and returns hop counts for each route
func TestRouteParser_ParseRoutesWithQuoteInts_HopCalculation(t *testing.T) {
	parser := NewRouteParser()

	tests := []struct {
		name         string
		routes       string
		quotes       string
		expectedHops []int
		expectError  bool
		errorMsg     string
	}{
		{
			name:         "single route, single hop",
			routes:       "tokenA:tokenB:500",
			quotes:       "100",
			expectedHops: []int{1},
			expectError:  false,
		},
		{
			name:         "single route, two hops",
			routes:       "tokenA:tokenB:500*POOL*tokenB:tokenC:3000",
			quotes:       "100",
			expectedHops: []int{2},
			expectError:  false,
		},
		{
			name:         "single route, three hops",
			routes:       "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			quotes:       "100",
			expectedHops: []int{3},
			expectError:  false,
		},
		{
			name:         "multiple routes with different hop counts",
			routes:       "tokenA:tokenB:500,tokenC:tokenD:3000*POOL*tokenD:tokenE:500,tokenF:tokenG:10000",
			quotes:       "30,50,20",
			expectedHops: []int{1, 2, 1},
			expectError:  false,
		},
		{
			name:         "complex multi-route scenario",
			routes:       "foo:bar:500,bar:baz:3000*POOL*baz:qux:500,foo:qux:10000*POOL*qux:bar:3000*POOL*bar:baz:500",
			quotes:       "25,25,50",
			expectedHops: []int{1, 2, 3},
			expectError:  false,
		},
		{
			name:        "empty routes",
			routes:      "",
			quotes:      "",
			expectError: true,
			errorMsg:    "routes cannot be empty",
		},
		{
			name:        "mismatched routes and quotes",
			routes:      "tokenA:tokenB:500,tokenC:tokenD:3000",
			quotes:      "100",
			expectError: true,
			errorMsg:    "mismatch",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			routes, quotes, quotesInt, hops, err := parser.ParseRoutesWithQuoteInts(tt.routes, tt.quotes)

			if tt.expectError {
				uassert.Error(t, err, "expected error but got none")
				if tt.errorMsg != "" {
					uassert.ErrorContains(t, err, tt.errorMsg)
				}
			} else {
				uassert.NoError(t, err, "unexpected error")

				// Verify hop counts
				uassert.Equal(t, len(hops), len(tt.expectedHops), "hop count mismatch")
				for i, expectedHop := range tt.expectedHops {
					uassert.Equal(t, hops[i], expectedHop)
				}

				// Verify other return values are consistent
				uassert.Equal(t, len(routes), len(hops), "routes and hops length mismatch")
				uassert.Equal(t, len(quotes), len(hops), "quotes and hops length mismatch")
				uassert.Equal(t, len(quotesInt), len(hops), "quotesInt and hops length mismatch")

				// Verify hop calculation is correct by manually checking
				for i, route := range routes {
					expectedHopCount := countHops(route)
					uassert.Equal(t, hops[i], expectedHopCount)
				}
			}
		})
	}
}

// TestValidateRoutesAndQuotes_HopPropagation tests that validateRoutesAndQuotes
// properly propagates hop counts from ParseRoutesWithQuoteInts
func TestValidateRoutesAndQuotes_HopPropagation(t *testing.T) {
	tests := []struct {
		name         string
		routes       string
		quotes       string
		expectedHops []int
	}{
		{
			name:         "single hop route",
			routes:       "foo:bar:500",
			quotes:       "100",
			expectedHops: []int{1},
		},
		{
			name:         "multi-hop route",
			routes:       "foo:bar:500*POOL*bar:baz:3000",
			quotes:       "100",
			expectedHops: []int{2},
		},
		{
			name:         "mixed hop routes",
			routes:       "foo:bar:500,bar:baz:3000*POOL*baz:qux:500",
			quotes:       "60,40",
			expectedHops: []int{1, 2},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			routes, quotes, quotesInt, hops, err := validateRoutesAndQuotes(tt.routes, tt.quotes)

			uassert.NoError(t, err)
			uassert.NotNil(t, hops, "hops should not be nil")
			uassert.Equal(t, len(hops), len(tt.expectedHops), "hop count mismatch")

			for i, expectedHop := range tt.expectedHops {
				uassert.Equal(t, hops[i], expectedHop)
			}

			// Verify consistency
			uassert.Equal(t, len(routes), len(hops))
			uassert.Equal(t, len(quotes), len(hops))
			uassert.Equal(t, len(quotesInt), len(hops))
		})
	}
}

// TestHopCalculation_EdgeCases tests edge cases for hop calculation
func TestHopCalculation_EdgeCases(t *testing.T) {
	parser := NewRouteParser()

	tests := []struct {
		name         string
		routes       string
		quotes       string
		description  string
		validateHops func(t *testing.T, hops []int)
	}{
		{
			name:        "maximum allowed hops (3)",
			routes:      "a:b:500*POOL*b:c:3000*POOL*c:d:10000",
			quotes:      "100",
			description: "should handle maximum 3 hops",
			validateHops: func(t *testing.T, hops []int) {
				uassert.Equal(t, hops[0], 3, "should be 3 hops")
			},
		},
		{
			name:        "seven routes with varying hops",
			routes:      "a:b:500,b:c:500,c:d:500*POOL*d:e:500,e:f:500,f:g:500*POOL*g:h:500*POOL*h:i:500,i:j:500,j:k:500*POOL*k:l:500",
			quotes:      "14,14,14,15,15,14,14",
			description: "should handle maximum 7 routes with different hop counts",
			validateHops: func(t *testing.T, hops []int) {
				expected := []int{1, 1, 2, 1, 3, 1, 2}
				uassert.Equal(t, len(hops), 7, "should have 7 hop counts")
				for i, exp := range expected {
					uassert.Equal(t, hops[i], exp)
				}
			},
		},
		{
			name:        "routes with identical hop counts",
			routes:      "a:b:500*POOL*b:c:500,d:e:500*POOL*e:f:500,g:h:500*POOL*h:i:500",
			quotes:      "33,33,34",
			description: "all routes have 2 hops",
			validateHops: func(t *testing.T, hops []int) {
				for _, hop := range hops {
					uassert.Equal(t, hop, 2)
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, _, hops, err := parser.ParseRoutesWithQuoteInts(tt.routes, tt.quotes)

			uassert.NoError(t, err)
			tt.validateHops(t, hops)
		})
	}
}
