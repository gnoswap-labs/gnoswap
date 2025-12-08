package v1

import (
	"math"
	"strconv"
	"strings"
	"testing"

	"gno.land/p/nt/uassert"
)

func TestGetDataForSinglePath(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		wantToken0  string
		wantToken1  string
		wantFee     int
		shouldPanic bool
	}{
		{
			name:        "valid path",
			input:       "tokenA:tokenB:500",
			wantToken0:  "tokenA",
			wantToken1:  "tokenB",
			wantFee:     int(500),
			shouldPanic: false,
		},
		{
			name:        "invalid path format",
			input:       "tokenA:tokenB",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if (r != nil) != tt.shouldPanic {
					t.Errorf("getDataForSinglePath() panic = %v, shouldPanic = %v", r != nil, tt.shouldPanic)
				}
			}()

			token0, token1, fee := getDataForSinglePath(tt.input)
			if !tt.shouldPanic {
				if token0 != tt.wantToken0 {
					t.Errorf("token0 = %v, want %v", token0, tt.wantToken0)
				}
				if token1 != tt.wantToken1 {
					t.Errorf("token1 = %v, want %v", token1, tt.wantToken1)
				}
				if int(fee) != tt.wantFee {
					t.Errorf("fee = %v, want %v", fee, tt.wantFee)
				}
			}
		})
	}
}

func TestGetDataForMultiPath(t *testing.T) {
	tests := []struct {
		name       string
		input      string
		poolIdx    int
		wantToken0 string
		wantToken1 string
		wantFee    uint32
	}{
		{
			name:       "first pool",
			input:      "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			poolIdx:    0,
			wantToken0: "tokenA",
			wantToken1: "tokenB",
			wantFee:    500,
		},
		{
			name:       "second pool",
			input:      "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			poolIdx:    1,
			wantToken0: "tokenB",
			wantToken1: "tokenC",
			wantFee:    3000,
		},
		{
			name:       "third pool",
			input:      "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			poolIdx:    2,
			wantToken0: "tokenC",
			wantToken1: "tokenD",
			wantFee:    10000,
		},
		{
			name:       "invalid pool index",
			input:      "tokenA:tokenB:500*POOL*tokenB:tokenC:3000",
			poolIdx:    3,
			wantToken0: "",
			wantToken1: "",
			wantFee:    0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			token0, token1, fee := getDataForMultiPath(tt.input, tt.poolIdx)

			if token0 != tt.wantToken0 {
				t.Errorf("token0 = %v, want %v", token0, tt.wantToken0)
			}
			if token1 != tt.wantToken1 {
				t.Errorf("token1 = %v, want %v", token1, tt.wantToken1)
			}
			if fee != tt.wantFee {
				t.Errorf("fee = %v, want %v", fee, tt.wantFee)
			}
		})
	}
}

func TestSplitSingleChar(t *testing.T) {
	testCases := []struct {
		name     string
		input    string
		sep      byte
		expected []string
	}{
		{
			name:     "plain split",
			input:    "a,b,c",
			sep:      ',',
			expected: []string{"a", "b", "c"},
		},
		{
			name:     "empty string",
			input:    "",
			sep:      ',',
			expected: []string{""},
		},
		{
			name:     "no separator",
			input:    "abc",
			sep:      ',',
			expected: []string{"abc"},
		},
		{
			name:     "consecutive separators",
			input:    "a,,b,,c",
			sep:      ',',
			expected: []string{"a", "", "b", "", "c"},
		},
		{
			name:     "separator at the beginning and end",
			input:    ",a,b,c,",
			sep:      ',',
			expected: []string{"", "a", "b", "c", ""},
		},
		{
			name:     "space separator",
			input:    "a b c",
			sep:      ' ',
			expected: []string{"a", "b", "c"},
		},
		{
			name:     "single character string",
			input:    "a",
			sep:      ',',
			expected: []string{"a"},
		},
		{
			name:     "only separators",
			input:    ",,,,",
			sep:      ',',
			expected: []string{"", "", "", "", ""},
		},
		{
			name:     "unicode characters",
			input:    "한글,English,日本語",
			sep:      ',',
			expected: []string{"한글", "English", "日本語"},
		},
		{
			name:     "special characters",
			input:    "!@#$,%^&*,()_+",
			sep:      ',',
			expected: []string{"!@#$", "%^&*", "()_+"},
		},
		{
			name:     "routes path",
			input:    "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500",
			sep:      ',',
			expected: []string{"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500", "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500"},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := splitSingleChar(tc.input, tc.sep)

			uassert.Equal(t, len(result), len(tc.expected))

			for i := 0; i < len(tc.expected); i++ {
				uassert.Equal(t, result[i], tc.expected[i])
			}
		})
	}
}

func TestValidateRoutePath(t *testing.T) {
	tests := []struct {
		name        string
		routePath   string
		inputToken  string
		outputToken string
		wantError   bool
		errorMsg    string
	}{
		{
			name:        "valid single-hop route",
			routePath:   "tokenA:tokenB:500",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			wantError:   false,
		},
		{
			name:        "valid multi-hop route",
			routePath:   "tokenA:tokenB:500*POOL*tokenB:tokenC:3000",
			inputToken:  "tokenA",
			outputToken: "tokenC",
			wantError:   false,
		},
		{
			name:        "valid three-hop route",
			routePath:   "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			inputToken:  "tokenA",
			outputToken: "tokenD",
			wantError:   false,
		},
		{
			name:        "invalid first token",
			routePath:   "tokenX:tokenB:500",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			wantError:   true,
			errorMsg:    "invalid route first token",
		},
		{
			name:        "invalid last token",
			routePath:   "tokenA:tokenX:500",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			wantError:   true,
			errorMsg:    "invalid route last token",
		},
		{
			name:        "invalid multi-hop first token",
			routePath:   "tokenX:tokenB:500*POOL*tokenB:tokenC:3000",
			inputToken:  "tokenA",
			outputToken: "tokenC",
			wantError:   true,
			errorMsg:    "invalid route first token",
		},
		{
			name:        "invalid multi-hop last token",
			routePath:   "tokenA:tokenB:500*POOL*tokenB:tokenX:3000",
			inputToken:  "tokenA",
			outputToken: "tokenC",
			wantError:   true,
			errorMsg:    "invalid route last token",
		},
		{
			name:        "real token addresses single-hop",
			routePath:   "gno.land/r/demo/wugnot:gno.land/r/demo/usdc:500",
			inputToken:  "gno.land/r/demo/wugnot",
			outputToken: "gno.land/r/demo/usdc",
			wantError:   false,
		},
		{
			name:        "real token addresses multi-hop",
			routePath:   "gno.land/r/demo/wugnot:gno.land/r/demo/gns:3000*POOL*gno.land/r/demo/gns:gno.land/r/demo/usdc:500",
			inputToken:  "gno.land/r/demo/wugnot",
			outputToken: "gno.land/r/demo/usdc",
			wantError:   false,
		},
		{
			name:        "empty first token",
			routePath:   ":tokenB:500",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			wantError:   true,
			errorMsg:    "invalid pool path",
		},
		{
			name:        "empty last token",
			routePath:   "tokenA::500",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			wantError:   true,
			errorMsg:    "invalid pool path",
		},
		{
			name:        "same input and output token",
			routePath:   "tokenA:tokenA:500",
			inputToken:  "tokenA",
			outputToken: "tokenA",
			wantError:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateRoutePath(tt.routePath, tt.inputToken, tt.outputToken)

			if tt.wantError {
				uassert.True(t, err != nil, "expected error but got none")
				if tt.errorMsg != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.errorMsg), "error message should contain: "+tt.errorMsg)
				}
			} else {
				if err != nil {
					t.Errorf("expected no error but got: %s", err.Error())
				}
				uassert.Nil(t, err)
			}
		})
	}
}

func TestValidateRoutePaths(t *testing.T) {
	tests := []struct {
		name               string
		routePathArrString string
		inputToken         string
		outputToken        string
		wantError          bool
		errorMsg           string
	}{
		{
			name:               "valid single route",
			routePathArrString: "tokenA:tokenB:500",
			inputToken:         "tokenA",
			outputToken:        "tokenB",
			wantError:          false,
		},
		{
			name:               "valid multiple routes",
			routePathArrString: "tokenA:tokenB:500,tokenA:tokenC:3000*POOL*tokenC:tokenB:500",
			inputToken:         "tokenA",
			outputToken:        "tokenB",
			wantError:          false,
		},
		{
			name:               "valid three routes",
			routePathArrString: "tokenA:tokenB:500,tokenA:tokenC:3000*POOL*tokenC:tokenB:500,tokenA:tokenD:10000*POOL*tokenD:tokenE:500*POOL*tokenE:tokenB:3000",
			inputToken:         "tokenA",
			outputToken:        "tokenB",
			wantError:          false,
		},
		{
			name:               "first route invalid - wrong first token",
			routePathArrString: "tokenX:tokenB:500,tokenA:tokenB:3000",
			inputToken:         "tokenA",
			outputToken:        "tokenB",
			wantError:          true,
			errorMsg:           "invalid route first token",
		},
		{
			name:               "second route invalid - wrong last token",
			routePathArrString: "tokenA:tokenB:500,tokenA:tokenX:3000",
			inputToken:         "tokenA",
			outputToken:        "tokenB",
			wantError:          true,
			errorMsg:           "invalid route last token",
		},
		{
			name:               "mixed single and multi-hop routes",
			routePathArrString: "tokenA:tokenB:500,tokenA:tokenC:3000*POOL*tokenC:tokenB:500,tokenA:tokenD:10000*POOL*tokenD:tokenB:3000",
			inputToken:         "tokenA",
			outputToken:        "tokenB",
			wantError:          false,
		},
		{
			name:               "real token addresses multiple routes",
			routePathArrString: "gno.land/r/demo/wugnot:gno.land/r/demo/usdc:500,gno.land/r/demo/wugnot:gno.land/r/demo/gns:3000*POOL*gno.land/r/demo/gns:gno.land/r/demo/usdc:500",
			inputToken:         "gno.land/r/demo/wugnot",
			outputToken:        "gno.land/r/demo/usdc",
			wantError:          false,
		},
		{
			name:               "empty route path",
			routePathArrString: "",
			inputToken:         "tokenA",
			outputToken:        "tokenB",
			wantError:          true,
			errorMsg:           "invalid pool path",
		},
		{
			name:               "route with empty segment",
			routePathArrString: "tokenA:tokenB:500,,tokenA:tokenC:3000",
			inputToken:         "tokenA",
			outputToken:        "tokenB",
			wantError:          true,
			errorMsg:           "invalid pool path",
		},
		{
			name:               "all routes have different input token",
			routePathArrString: "tokenX:tokenB:500,tokenY:tokenB:3000",
			inputToken:         "tokenA",
			outputToken:        "tokenB",
			wantError:          true,
			errorMsg:           "invalid route first token",
		},
		{
			name:               "all routes have different output token",
			routePathArrString: "tokenA:tokenX:500,tokenA:tokenY:3000",
			inputToken:         "tokenA",
			outputToken:        "tokenB",
			wantError:          true,
			errorMsg:           "invalid route last token",
		},
		{
			name:               "complex multi-hop with valid path",
			routePathArrString: "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			inputToken:         "tokenA",
			outputToken:        "tokenD",
			wantError:          false,
		},
		{
			name:               "complex multi-hop with invalid intermediate connection",
			routePathArrString: "tokenA:tokenB:500*POOL*tokenX:tokenC:3000*POOL*tokenC:tokenD:10000",
			inputToken:         "tokenA",
			outputToken:        "tokenD",
			wantError:          false, // This should pass validation as we only check first and last tokens
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateRoutePaths(tt.routePathArrString, tt.inputToken, tt.outputToken)

			if tt.wantError {
				uassert.True(t, err != nil, "expected error but got none")
				if tt.errorMsg != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.errorMsg), "error message should contain: "+tt.errorMsg)
				}
			} else {
				uassert.Nil(t, err)
			}
		})
	}
}

func TestSafeAddInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		// Normal cases
		{
			name:     "positive + positive",
			a:        100,
			b:        200,
			expected: 300,
		},
		{
			name:     "negative + negative",
			a:        -100,
			b:        -200,
			expected: -300,
		},
		{
			name:     "positive + negative",
			a:        100,
			b:        -50,
			expected: 50,
		},
		{
			name:     "negative + positive",
			a:        -100,
			b:        150,
			expected: 50,
		},
		{
			name:     "zero + zero",
			a:        0,
			b:        0,
			expected: 0,
		},
		{
			name:     "zero + positive",
			a:        0,
			b:        100,
			expected: 100,
		},
		{
			name:     "zero + negative",
			a:        0,
			b:        -100,
			expected: -100,
		},
		// Boundary cases - MaxInt64
		{
			name:     "MaxInt64 + 0",
			a:        9223372036854775807,
			b:        0,
			expected: 9223372036854775807,
		},
		{
			name:     "MaxInt64 - 1 + 1",
			a:        9223372036854775806,
			b:        1,
			expected: 9223372036854775807,
		},
		{
			name:        "MaxInt64 + 1 overflow",
			a:           9223372036854775807,
			b:           1,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:        "MaxInt64 + MaxInt64 overflow",
			a:           9223372036854775807,
			b:           9223372036854775807,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:     "MaxInt64 + MinInt64",
			a:        9223372036854775807,
			b:        -9223372036854775808,
			expected: -1,
		},
		// Boundary cases - MinInt64
		{
			name:     "MinInt64 + 0",
			a:        -9223372036854775808,
			b:        0,
			expected: -9223372036854775808,
		},
		{
			name:     "MinInt64 + 1 + (-1)",
			a:        -9223372036854775807,
			b:        -1,
			expected: -9223372036854775808,
		},
		{
			name:        "MinInt64 + (-1) underflow",
			a:           -9223372036854775808,
			b:           -1,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
		{
			name:        "MinInt64 + MinInt64 underflow",
			a:           -9223372036854775808,
			b:           -9223372036854775808,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
		{
			name:     "MinInt64 + MaxInt64",
			a:        -9223372036854775808,
			b:        9223372036854775807,
			expected: -1,
		},
		// Large values near boundary
		{
			name:        "large positive overflow",
			a:           9223372036854775800,
			b:           100,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:        "large negative underflow",
			a:           -9223372036854775800,
			b:           -100,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					r := recover()
					if r == nil {
						t.Errorf("expected panic but got none")
						return
					}
					if r != tt.panicMsg {
						t.Errorf("expected panic message %q, got %q", tt.panicMsg, r)
					}
				}()
				safeAddInt64(tt.a, tt.b)
			} else {
				result := safeAddInt64(tt.a, tt.b)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

func TestSafeSubInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		// Normal cases
		{
			name:     "positive - positive",
			a:        200,
			b:        100,
			expected: 100,
		},
		{
			name:     "negative - negative",
			a:        -100,
			b:        -200,
			expected: 100,
		},
		{
			name:     "positive - negative",
			a:        100,
			b:        -50,
			expected: 150,
		},
		{
			name:     "negative - positive",
			a:        -100,
			b:        50,
			expected: -150,
		},
		{
			name:     "zero - zero",
			a:        0,
			b:        0,
			expected: 0,
		},
		{
			name:     "zero - positive",
			a:        0,
			b:        100,
			expected: -100,
		},
		{
			name:     "zero - negative",
			a:        0,
			b:        -100,
			expected: 100,
		},
		// Boundary cases - MaxInt64
		{
			name:     "MaxInt64 - 0",
			a:        9223372036854775807,
			b:        0,
			expected: 9223372036854775807,
		},
		{
			name:     "MaxInt64 - 1",
			a:        9223372036854775807,
			b:        1,
			expected: 9223372036854775806,
		},
		{
			name:     "MaxInt64 - MaxInt64",
			a:        9223372036854775807,
			b:        9223372036854775807,
			expected: 0,
		},
		{
			name:        "MaxInt64 - (-1) overflow",
			a:           9223372036854775807,
			b:           -1,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
		{
			name:        "MaxInt64 - MinInt64 overflow",
			a:           9223372036854775807,
			b:           -9223372036854775808,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
		// Boundary cases - MinInt64
		{
			name:     "MinInt64 - 0",
			a:        -9223372036854775808,
			b:        0,
			expected: -9223372036854775808,
		},
		{
			name:     "MinInt64 - (-1)",
			a:        -9223372036854775808,
			b:        -1,
			expected: -9223372036854775807,
		},
		{
			name:     "MinInt64 - MinInt64",
			a:        -9223372036854775808,
			b:        -9223372036854775808,
			expected: 0,
		},
		{
			name:        "MinInt64 - 1 underflow",
			a:           -9223372036854775808,
			b:           1,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		{
			name:        "MinInt64 - MaxInt64 underflow",
			a:           -9223372036854775808,
			b:           9223372036854775807,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		// Large values near boundary
		{
			name:        "large negative - positive underflow",
			a:           -9223372036854775800,
			b:           100,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		{
			name:        "large positive - negative overflow",
			a:           9223372036854775800,
			b:           -100,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
		// Edge case: 0 - MinInt64
		{
			name:        "0 - MinInt64 overflow",
			a:           0,
			b:           -9223372036854775808,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					r := recover()
					if r == nil {
						t.Errorf("expected panic but got none")
						return
					}
					if r != tt.panicMsg {
						t.Errorf("expected panic message %q, got %q", tt.panicMsg, r)
					}
				}()
				safeSubInt64(tt.a, tt.b)
			} else {
				result := safeSubInt64(tt.a, tt.b)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

func TestSafeMulDivInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		c           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		// Normal cases
		{
			name:     "simple multiplication and division",
			a:        1000,
			b:        50,
			c:        100, // PERCENTAGE_DENOMINATOR
			expected: 500,
		},
		{
			name:     "100% of value",
			a:        1000,
			b:        100,
			c:        100,
			expected: 1000,
		},
		{
			name:     "10% of value",
			a:        1000,
			b:        10,
			c:        100,
			expected: 100,
		},
		// Zero cases
		{
			name:     "a is zero",
			a:        0,
			b:        100,
			c:        100,
			expected: 0,
		},
		{
			name:     "b is zero",
			a:        100,
			b:        0,
			c:        100,
			expected: 0,
		},
		{
			name:     "both a and b are zero",
			a:        0,
			b:        0,
			c:        100,
			expected: 0,
		},
		// Division by zero
		{
			name:        "division by zero",
			a:           100,
			b:           50,
			c:           0,
			shouldPanic: true,
			panicMsg:    "division by zero in safeMulDivInt64",
		},
		// Result is zero after division (too small)
		{
			name:        "result too small - becomes zero",
			a:           1,
			b:           1,
			c:           100,
			shouldPanic: false,
		},
		// Negative values
		{
			name:     "negative a",
			a:        -1000,
			b:        50,
			c:        100,
			expected: -500,
		},
		{
			name:     "negative b",
			a:        1000,
			b:        -50,
			c:        100,
			expected: -500,
		},
		{
			name:     "both negative",
			a:        -1000,
			b:        -50,
			c:        100,
			expected: 500,
		},
		// Large values
		{
			name:     "large values within range",
			a:        1000000000000,
			b:        50,
			c:        100,
			expected: 500000000000,
		},
		{
			name:        "int64 overflow on final conversion",
			a:           math.MaxInt64,
			b:           200,
			c:           100,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-ROUTER-016] overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					r := recover()
					if r == nil {
						t.Errorf("expected panic but got none")
						return
					}
					panicStr, ok := r.(string)
					if !ok {
						// Handle error type
						if err, isErr := r.(error); isErr {
							panicStr = err.Error()
						}
					}
					if panicStr != tt.panicMsg {
						t.Errorf("expected panic message %q, got %q", tt.panicMsg, panicStr)
					}
				}()
				safeMulDivInt64(tt.a, tt.b, tt.c)
			} else {
				result := safeMulDivInt64(tt.a, tt.b, tt.c)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

func TestAbsInt64(t *testing.T) {
	tests := []struct {
		name     string
		input    int64
		expected int64
	}{
		// Normal cases
		{
			name:     "positive number",
			input:    100,
			expected: 100,
		},
		{
			name:     "negative number",
			input:    -100,
			expected: 100,
		},
		{
			name:     "zero",
			input:    0,
			expected: 0,
		},
		// Boundary cases
		{
			name:     "MaxInt64",
			input:    9223372036854775807,
			expected: 9223372036854775807,
		},
		{
			name:     "negative one",
			input:    -1,
			expected: 1,
		},
		{
			name:     "positive one",
			input:    1,
			expected: 1,
		},
		// Large values
		{
			name:     "large positive",
			input:    9223372036854775800,
			expected: 9223372036854775800,
		},
		{
			name:     "large negative",
			input:    -9223372036854775800,
			expected: 9223372036854775800,
		},
		// Note: MinInt64 (-9223372036854775808) would overflow when negated
		// as MaxInt64 is 9223372036854775807, but the function doesn't handle this
		{
			name:     "MinInt64 + 1",
			input:    -9223372036854775807,
			expected: 9223372036854775807,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := absInt64(tt.input)
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestParsePoolPathsByRoutePathArr(t *testing.T) {
	tests := []struct {
		name          string
		routePathArr  string
		expected      []string
		wantError     bool
		errorContains string
	}{
		{
			name:         "single route single hop",
			routePathArr: "gno.land/r/demo/wugnot:gno.land/r/demo/usdc:500",
			expected:     []string{"gno.land/r/demo/usdc:gno.land/r/demo/wugnot:500"}, // alphabetically ordered
			wantError:    false,
		},
		{
			name:         "single route multi hop",
			routePathArr: "gno.land/r/demo/wugnot:gno.land/r/demo/gns:3000*POOL*gno.land/r/demo/gns:gno.land/r/demo/usdc:500",
			expected: []string{
				"gno.land/r/demo/gns:gno.land/r/demo/wugnot:3000", // alphabetically ordered
				"gno.land/r/demo/gns:gno.land/r/demo/usdc:500",    // alphabetically ordered
			},
			wantError: false,
		},
		{
			name:         "multiple routes single hop each",
			routePathArr: "gno.land/r/demo/wugnot:gno.land/r/demo/usdc:500,gno.land/r/demo/wugnot:gno.land/r/demo/gns:3000",
			expected: []string{
				"gno.land/r/demo/usdc:gno.land/r/demo/wugnot:500", // alphabetically ordered
				"gno.land/r/demo/gns:gno.land/r/demo/wugnot:3000", // alphabetically ordered
			},
			wantError: false,
		},
		{
			name:         "multiple routes with multi hop",
			routePathArr: "gno.land/r/demo/wugnot:gno.land/r/demo/usdc:500,gno.land/r/demo/wugnot:gno.land/r/demo/gns:3000*POOL*gno.land/r/demo/gns:gno.land/r/demo/usdc:500",
			expected: []string{
				"gno.land/r/demo/usdc:gno.land/r/demo/wugnot:500", // first route
				"gno.land/r/demo/gns:gno.land/r/demo/wugnot:3000", // second route first hop
				"gno.land/r/demo/gns:gno.land/r/demo/usdc:500",    // second route second hop
			},
			wantError: false,
		},
		{
			name:         "three hop route",
			routePathArr: "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			expected: []string{
				"tokenA:tokenB:500",   // already alphabetically ordered
				"tokenB:tokenC:3000",  // already alphabetically ordered
				"tokenC:tokenD:10000", // already alphabetically ordered
			},
			wantError: false,
		},
		{
			name:         "tokens need reordering",
			routePathArr: "tokenZ:tokenA:500,tokenY:tokenB:3000",
			expected: []string{
				"tokenA:tokenZ:500",  // reordered alphabetically
				"tokenB:tokenY:3000", // reordered alphabetically
			},
			wantError: false,
		},
		{
			name:         "complex mixed routes",
			routePathArr: "tokenA:tokenB:500,tokenC:tokenD:3000*POOL*tokenD:tokenE:10000,tokenF:tokenG:100*POOL*tokenG:tokenH:200*POOL*tokenH:tokenI:300",
			expected: []string{
				"tokenA:tokenB:500",   // single hop
				"tokenC:tokenD:3000",  // first hop of second route
				"tokenD:tokenE:10000", // second hop of second route
				"tokenF:tokenG:100",   // first hop of third route
				"tokenG:tokenH:200",   // second hop of third route
				"tokenH:tokenI:300",   // third hop of third route
			},
			wantError: false,
		},
		{
			name:          "invalid route path format - missing fee",
			routePathArr:  "tokenA:tokenB",
			expected:      nil,
			wantError:     true,
			errorContains: "invalid pool path",
		},
		{
			name:          "invalid route path format - empty token",
			routePathArr:  ":tokenB:500",
			expected:      nil,
			wantError:     true,
			errorContains: "invalid pool path",
		},
		{
			name:          "invalid route path format - non-numeric fee",
			routePathArr:  "tokenA:tokenB:invalid",
			expected:      nil,
			wantError:     true,
			errorContains: "invalid fee",
		},
		{
			name:          "empty route path array",
			routePathArr:  "",
			expected:      nil,
			wantError:     true,
			errorContains: "invalid pool path",
		},
		{
			name:         "same token addresses (edge case)",
			routePathArr: "tokenA:tokenA:500",
			expected:     []string{"tokenA:tokenA:500"}, // same token, no reordering needed
			wantError:    false,
		},
		{
			name:         "real gnoswap token paths",
			routePathArr: "gno.land/r/demo/wugnot:gno.land/r/onbloc/usdc:500,gno.land/r/demo/wugnot:gno.land/r/onbloc/gns:3000*POOL*gno.land/r/onbloc/gns:gno.land/r/onbloc/usdc:500",
			expected: []string{
				"gno.land/r/demo/wugnot:gno.land/r/onbloc/usdc:500", // first route (already ordered)
				"gno.land/r/demo/wugnot:gno.land/r/onbloc/gns:3000", // second route first hop (already ordered)
				"gno.land/r/onbloc/gns:gno.land/r/onbloc/usdc:500",  // second route second hop (already ordered)
			},
			wantError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := parsePoolPathsByRoutePathArr(tt.routePathArr)

			if tt.wantError {
				uassert.True(t, err != nil, "expected error but got none")
				if tt.errorContains != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.errorContains),
						"error message should contain: "+tt.errorContains+", but got: "+err.Error())
				}
				return
			}

			uassert.Nil(t, err)
			uassert.Equal(t, len(result), len(tt.expected))

			for i, expected := range tt.expected {
				uassert.Equal(t, result[i], expected,
					"at index %d: expected %s, got %s", strconv.FormatInt(int64(i), 10), expected, result[i])
			}
		})
	}
}
