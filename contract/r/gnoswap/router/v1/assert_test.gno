package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/uassert"
)

// Test assertIsNotExpired
func TestAssertIsNotExpired(t *testing.T) {
	tests := []struct {
		name        string
		deadline    int64
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "valid deadline in future",
			deadline:    time.Now().Unix() + 1000,
			shouldPanic: false,
		},
		{
			name:        "valid deadline exactly now",
			deadline:    time.Now().Unix(),
			shouldPanic: false,
		},
		{
			name:        "expired deadline by 1 second",
			deadline:    time.Now().Unix() - 1,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-003]",
		},
		{
			name:        "expired deadline long ago",
			deadline:    time.Now().Unix() - 100000,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-003]",
		},
		{
			name:        "far future deadline",
			deadline:    time.Now().Unix() + 999999999,
			shouldPanic: false,
		},
		{
			name:        "zero deadline",
			deadline:    0,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-003]",
		},
		{
			name:        "negative deadline",
			deadline:    -1,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-003]",
		},
		{
			name:        "max int64 deadline",
			deadline:    9223372036854775807,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.errorMsg, func() {
					assertIsNotExpired(tt.deadline)
				})
			} else {
				assertIsNotExpired(tt.deadline)
			}
		})
	}
}

// Test assertIsValidUserCoinSend
func TestAssertIsValidUserCoinSend(t *testing.T) {
	tests := []struct {
		name        string
		tokenPath   string
		amount      string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "valid non-native token with zero amount",
			tokenPath:   "gno.land/r/demo/gns",
			amount:      "0",
			shouldPanic: false,
		},
		{
			name:        "valid non-native token with positive amount",
			tokenPath:   "gno.land/r/demo/gns",
			amount:      "1000",
			shouldPanic: false,
		},
		{
			name:        "invalid amount format - non-numeric",
			tokenPath:   "ugnot",
			amount:      "abc",
			shouldPanic: true,
			errorMsg:    "invalid syntax",
		},
		{
			name:        "invalid amount format - empty string",
			tokenPath:   "ugnot",
			amount:      "",
			shouldPanic: true,
			errorMsg:    "invalid syntax",
		},
		{
			name:        "invalid amount format - decimal number",
			tokenPath:   "ugnot",
			amount:      "100.5",
			shouldPanic: true,
			errorMsg:    "invalid syntax",
		},
		{
			name:        "valid large amount",
			tokenPath:   "gno.land/r/demo/gns",
			amount:      "999999999999999",
			shouldPanic: false,
		},
		{
			name:        "negative amount",
			tokenPath:   "gno.land/r/demo/gns",
			amount:      "-100",
			shouldPanic: false, // ParseInt will succeed, validation happens in common package
		},
		{
			name:        "amount with leading zeros",
			tokenPath:   "gno.land/r/demo/gns",
			amount:      "0001000",
			shouldPanic: false,
		},
		{
			name:        "amount with spaces",
			tokenPath:   "ugnot",
			amount:      " 1000 ",
			shouldPanic: true,
			errorMsg:    "invalid syntax",
		},
		{
			name:        "amount overflow int64",
			tokenPath:   "ugnot",
			amount:      "9223372036854775808", // int64 max + 1
			shouldPanic: true,
			errorMsg:    "value out of range",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.errorMsg, func() {
					assertIsValidUserCoinSend(tt.tokenPath, tt.amount)
				})
			} else {
				assertIsValidUserCoinSend(tt.tokenPath, tt.amount)
			}
		})
	}
}

// Test assertIsValidSqrtPriceLimitX96
func TestAssertIsValidSqrtPriceLimitX96(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "valid positive number",
			input:       "79228162514264337593543950336",
			shouldPanic: false,
		},
		{
			name:        "valid small positive number",
			input:       "1",
			shouldPanic: false,
		},
		{
			name:        "valid large number",
			input:       "999999999999999999999999999999",
			shouldPanic: false,
		},
		{
			name:        "empty string",
			input:       "",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-004]",
		},
		{
			name:        "invalid format - non-numeric",
			input:       "abc",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-004]",
		},
		{
			name:        "invalid format - negative number",
			input:       "-100",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-004]",
		},
		{
			name:        "invalid format - decimal number",
			input:       "100.5",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-004]",
		},
		{
			name:        "invalid format - hex number",
			input:       "0x100",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-004]",
		},
		{
			name:        "invalid format - spaces",
			input:       " 100 ",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-004]",
		},
		{
			name:        "zero value",
			input:       "0",
			shouldPanic: false,
		},
		{
			name:        "number with leading zeros",
			input:       "0001000",
			shouldPanic: false,
		},
		{
			name:        "special characters",
			input:       "100@#$",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-004]",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.errorMsg, func() {
					assertIsValidSqrtPriceLimitX96(tt.input)
				})
			} else {
				assertIsValidSqrtPriceLimitX96(tt.input)
			}
		})
	}
}

// Test assertIsValidSingleSwapRouteArrPath
func TestAssertIsValidSingleSwapRouteArrPath(t *testing.T) {
	tests := []struct {
		name        string
		routePaths  string
		inputToken  string
		outputToken string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "valid single-hop route",
			routePaths:  "tokenA:tokenB:500",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: false,
		},
		{
			name:        "empty route path",
			routePaths:  "",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-004]",
		},
		{
			name:        "route with comma separator",
			routePaths:  "tokenA:tokenB:500,tokenA:tokenC:3000",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-004]",
		},
		{
			name:        "route with POOL_SEPARATOR",
			routePaths:  "tokenA:tokenB:500*POOL*tokenB:tokenC:3000",
			inputToken:  "tokenA",
			outputToken: "tokenC",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-004]",
		},
		{
			name:        "invalid first token",
			routePaths:  "tokenX:tokenB:500",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-014]",
		},
		{
			name:        "invalid last token",
			routePaths:  "tokenA:tokenX:500",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-015]",
		},
		{
			name:        "valid real token addresses",
			routePaths:  "gno.land/r/demo/wugnot:gno.land/r/demo/usdc:500",
			inputToken:  "gno.land/r/demo/wugnot",
			outputToken: "gno.land/r/demo/usdc",
			shouldPanic: false,
		},
		{
			name:        "invalid pool path format - missing fee",
			routePaths:  "tokenA:tokenB",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-008]",
		},
		{
			name:        "invalid pool path format - empty token",
			routePaths:  ":tokenB:500",
			inputToken:  "",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-008]",
		},
		{
			name:        "route with multiple commas",
			routePaths:  "tokenA:tokenB:500,tokenA:tokenC:3000,tokenA:tokenD:10000",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-004]",
		},
		{
			name:        "route with multiple POOL_SEPARATORs",
			routePaths:  "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			inputToken:  "tokenA",
			outputToken: "tokenD",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-004]",
		},
		{
			name:        "same input and output token",
			routePaths:  "tokenA:tokenA:500",
			inputToken:  "tokenA",
			outputToken: "tokenA",
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.errorMsg, func() {
					assertIsValidSingleSwapRouteArrPath(tt.routePaths, tt.inputToken, tt.outputToken)
				})
			} else {
				assertIsValidSingleSwapRouteArrPath(tt.routePaths, tt.inputToken, tt.outputToken)
			}
		})
	}
}

// Test assertIsValidRoutePaths
func TestAssertIsValidRoutePaths(t *testing.T) {
	tests := []struct {
		name        string
		routePaths  string
		inputToken  string
		outputToken string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "valid single route",
			routePaths:  "tokenA:tokenB:500",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: false,
		},
		{
			name:        "valid multiple routes",
			routePaths:  "tokenA:tokenB:500,tokenA:tokenC:3000*POOL*tokenC:tokenB:500",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: false,
		},
		{
			name:        "valid three routes",
			routePaths:  "tokenA:tokenB:500,tokenA:tokenC:3000*POOL*tokenC:tokenB:500,tokenA:tokenD:10000*POOL*tokenD:tokenE:500*POOL*tokenE:tokenB:3000",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: false,
		},
		{
			name:        "invalid first token in first route",
			routePaths:  "tokenX:tokenB:500,tokenA:tokenB:3000",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-014]",
		},
		{
			name:        "invalid last token in second route",
			routePaths:  "tokenA:tokenB:500,tokenA:tokenX:3000",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-015]",
		},
		{
			name:        "valid multi-hop route",
			routePaths:  "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			inputToken:  "tokenA",
			outputToken: "tokenD",
			shouldPanic: false,
		},
		{
			name:        "invalid pool path format - missing fee",
			routePaths:  "tokenA:tokenB",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-008]",
		},
		{
			name:        "empty route path",
			routePaths:  "",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-008]",
		},
		{
			name:        "route with empty segment",
			routePaths:  "tokenA:tokenB:500,,tokenA:tokenC:3000",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-008]",
		},
		{
			name:        "all routes with wrong input token",
			routePaths:  "tokenX:tokenB:500,tokenY:tokenB:3000",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-014]",
		},
		{
			name:        "all routes with wrong output token",
			routePaths:  "tokenA:tokenX:500,tokenA:tokenY:3000",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-ROUTER-015]",
		},
		{
			name:        "valid real token addresses",
			routePaths:  "gno.land/r/demo/wugnot:gno.land/r/demo/usdc:500,gno.land/r/demo/wugnot:gno.land/r/demo/gns:3000*POOL*gno.land/r/demo/gns:gno.land/r/demo/usdc:500",
			inputToken:  "gno.land/r/demo/wugnot",
			outputToken: "gno.land/r/demo/usdc",
			shouldPanic: false,
		},
		{
			name:        "same input and output token",
			routePaths:  "tokenA:tokenA:500",
			inputToken:  "tokenA",
			outputToken: "tokenA",
			shouldPanic: false,
		},
		{
			name:        "invalid token in multi-hop middle section",
			routePaths:  "tokenA:tokenB:500*POOL*tokenX:tokenC:3000",
			inputToken:  "tokenA",
			outputToken: "tokenC",
			shouldPanic: false, // validateRoutePaths only checks first and last tokens
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.errorMsg, func() {
					assertIsValidRoutePaths(tt.routePaths, tt.inputToken, tt.outputToken)
				})
			} else {
				assertIsValidRoutePaths(tt.routePaths, tt.inputToken, tt.outputToken)
			}
		})
	}
}

// Test assertIsExistsPools
func TestAssertIsExistsPools(t *testing.T) {
	tests := []struct {
		name         string
		routePathArr string
		shouldPanic  bool
		errorMsg     string
	}{
		{
			name:         "invalid route path format - missing fee",
			routePathArr: "tokenA:tokenB",
			shouldPanic:  true,
			errorMsg:     "[GNOSWAP-ROUTER-008]",
		},
		{
			name:         "invalid route path format - empty token",
			routePathArr: ":tokenB:3000",
			shouldPanic:  true,
			errorMsg:     "[GNOSWAP-ROUTER-008]",
		},
		{
			name:         "invalid route path format - non-numeric fee",
			routePathArr: "tokenA:tokenB:abc",
			shouldPanic:  true,
			errorMsg:     "invalid fee",
		},
		{
			name:         "empty route path array",
			routePathArr: "",
			shouldPanic:  true,
			errorMsg:     "[GNOSWAP-ROUTER-008]",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.errorMsg, func() {
					assertIsExistsPools(tt.routePathArr)
				})
			} else {
				assertIsExistsPools(tt.routePathArr)
			}
		})
	}
}
