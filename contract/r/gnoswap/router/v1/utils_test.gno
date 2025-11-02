package v1

import (
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

// TestFormatUint tests formatUint function with edge cases
func TestFormatUint(t *testing.T) {
	tests := []struct {
		name        string
		input       any
		expected    string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "uint8 zero",
			input:       uint8(0),
			expected:    "0",
			shouldPanic: false,
		},
		{
			name:        "uint8 max",
			input:       uint8(255),
			expected:    "255",
			shouldPanic: false,
		},
		{
			name:        "uint32 zero",
			input:       uint32(0),
			expected:    "0",
			shouldPanic: false,
		},
		{
			name:        "uint32 max",
			input:       uint32(4294967295),
			expected:    "4294967295",
			shouldPanic: false,
		},
		{
			name:        "uint64 zero",
			input:       uint64(0),
			expected:    "0",
			shouldPanic: false,
		},
		{
			name:        "uint64 max",
			input:       uint64(18446744073709551615),
			expected:    "18446744073709551615",
			shouldPanic: false,
		},
		{
			name:        "invalid type int",
			input:       int(123),
			shouldPanic: true,
			errorMsg:    "invalid type: int",
		},
		{
			name:        "invalid type string",
			input:       "123",
			shouldPanic: true,
			errorMsg:    "invalid type: string",
		},
		{
			name:        "invalid type float64",
			input:       float64(3.14),
			shouldPanic: true,
			errorMsg:    "invalid type: unknown",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					formatUint(tt.input)
				})
			} else {
				result := formatUint(tt.input)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

// TestFormatInt64 tests formatInt64 function with edge cases
func TestFormatInt64(t *testing.T) {
	tests := []struct {
		name        string
		input       any
		expected    string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "int8 zero",
			input:       int8(0),
			expected:    "0",
			shouldPanic: false,
		},
		{
			name:        "int8 positive",
			input:       int8(127),
			expected:    "127",
			shouldPanic: false,
		},
		{
			name:        "int8 negative",
			input:       int8(-128),
			expected:    "-128",
			shouldPanic: false,
		},
		{
			name:        "int16 max",
			input:       int16(32767),
			expected:    "32767",
			shouldPanic: false,
		},
		{
			name:        "int16 min",
			input:       int16(-32768),
			expected:    "-32768",
			shouldPanic: false,
		},
		{
			name:        "int32 max",
			input:       int32(2147483647),
			expected:    "2147483647",
			shouldPanic: false,
		},
		{
			name:        "int32 min",
			input:       int32(-2147483648),
			expected:    "-2147483648",
			shouldPanic: false,
		},
		{
			name:        "int64 max",
			input:       int64(9223372036854775807),
			expected:    "9223372036854775807",
			shouldPanic: false,
		},
		{
			name:        "int64 min",
			input:       int64(-9223372036854775808),
			expected:    "-9223372036854775808",
			shouldPanic: false,
		},
		{
			name:        "invalid type uint",
			input:       uint(123),
			shouldPanic: true,
			errorMsg:    "invalid type uint",
		},
		{
			name:        "invalid type string",
			input:       "123",
			shouldPanic: true,
			errorMsg:    "invalid type string",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					formatInt64(tt.input)
				})
			} else {
				result := formatInt64(tt.input)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

// TestAssertHopsInRange tests assertHopsInRange function
func TestAssertHopsInRange(t *testing.T) {
	tests := []struct {
		name        string
		hops        int
		shouldPanic bool
	}{
		{
			name:        "valid - 1 hop",
			hops:        1,
			shouldPanic: false,
		},
		{
			name:        "valid - 2 hops",
			hops:        2,
			shouldPanic: false,
		},
		{
			name:        "valid - 3 hops",
			hops:        3,
			shouldPanic: false,
		},
		{
			name:        "invalid - 0 hops",
			hops:        0,
			shouldPanic: true,
		},
		{
			name:        "invalid - 4 hops",
			hops:        4,
			shouldPanic: true,
		},
		{
			name:        "invalid - negative hops",
			hops:        -1,
			shouldPanic: true,
		},
		{
			name:        "invalid - large number",
			hops:        100,
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Error("Expected panic but got none")
					}
				}()
				assertHopsInRange(tt.hops)
			} else {
				uassert.NotPanics(t, func() {
					assertHopsInRange(tt.hops)
				})
			}
		})
	}
}

// TestBuildSingleHopRoutePath tests BuildSingleHopRoutePath function
func TestBuildSingleHopRoutePath(t *testing.T) {
	tests := []struct {
		name        string
		tokenA      string
		tokenB      string
		fee         uint32
		expected    string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "valid route",
			tokenA:      "tokenA",
			tokenB:      "tokenB",
			fee:         500,
			expected:    "tokenA:tokenB:500",
			shouldPanic: false,
		},
		{
			name:        "valid with different fee",
			tokenA:      "gno.land/r/demo/wugnot",
			tokenB:      "gno.land/r/demo/usdc",
			fee:         3000,
			expected:    "gno.land/r/demo/wugnot:gno.land/r/demo/usdc:3000",
			shouldPanic: false,
		},
		{
			name:        "valid with large fee",
			tokenA:      "tokenX",
			tokenB:      "tokenY",
			fee:         10000,
			expected:    "tokenX:tokenY:10000",
			shouldPanic: false,
		},
		{
			name:        "invalid - empty tokenA",
			tokenA:      "",
			tokenB:      "tokenB",
			fee:         500,
			shouldPanic: true,
			errorMsg:    "token addresses cannot be empty",
		},
		{
			name:        "invalid - empty tokenB",
			tokenA:      "tokenA",
			tokenB:      "",
			fee:         500,
			shouldPanic: true,
			errorMsg:    "token addresses cannot be empty",
		},
		{
			name:        "invalid - both empty",
			tokenA:      "",
			tokenB:      "",
			fee:         500,
			shouldPanic: true,
			errorMsg:    "token addresses cannot be empty",
		},
		{
			name:        "invalid - same tokens",
			tokenA:      "tokenA",
			tokenB:      "tokenA",
			fee:         500,
			shouldPanic: true,
			errorMsg:    "tokenA and tokenB cannot be the same",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					BuildSingleHopRoutePath(tt.tokenA, tt.tokenB, tt.fee)
				})
			} else {
				result := BuildSingleHopRoutePath(tt.tokenA, tt.tokenB, tt.fee)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

// TestBuildMultiHopRoutePath tests BuildMultiHopRoutePath function
func TestBuildMultiHopRoutePath(t *testing.T) {
	tests := []struct {
		name        string
		hops        []string
		expected    string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "valid - 2 hops",
			hops:        []string{"tokenA:tokenB:500", "tokenB:tokenC:3000"},
			expected:    "tokenA:tokenB:500*POOL*tokenB:tokenC:3000",
			shouldPanic: false,
		},
		{
			name:        "valid - 3 hops",
			hops:        []string{"tokenA:tokenB:500", "tokenB:tokenC:3000", "tokenC:tokenD:10000"},
			expected:    "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			shouldPanic: false,
		},
		{
			name:        "valid - 1 hop (edge case)",
			hops:        []string{"tokenA:tokenB:500"},
			expected:    "tokenA:tokenB:500",
			shouldPanic: false,
		},
		{
			name:        "invalid - 0 hops",
			hops:        []string{},
			shouldPanic: true,
			errorMsg:    "multi-hop path requires at least 2 hops",
		},
		{
			name:        "invalid - 4 hops",
			hops:        []string{"a:b:1", "b:c:2", "c:d:3", "d:e:4"},
			shouldPanic: true,
			errorMsg:    "multi-hop path supports maximum 3 hops",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					BuildMultiHopRoutePath(tt.hops...)
				})
			} else {
				result := BuildMultiHopRoutePath(tt.hops...)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

// TestGetDataForSinglePathWithError tests getDataForSinglePathWithError edge cases
func TestGetDataForSinglePathWithError(t *testing.T) {
	tests := []struct {
		name       string
		poolPath   string
		wantToken0 string
		wantToken1 string
		wantFee    uint32
		wantError  bool
		errorMsg   string
	}{
		{
			name:       "valid path",
			poolPath:   "tokenA:tokenB:500",
			wantToken0: "tokenA",
			wantToken1: "tokenB",
			wantFee:    500,
			wantError:  false,
		},
		{
			name:       "valid path with spaces",
			poolPath:   " tokenA : tokenB :500",
			wantToken0: "tokenA",
			wantToken1: "tokenB",
			wantFee:    500,
			wantError:  false,
		},
		{
			name:      "invalid - missing parts",
			poolPath:  "tokenA:tokenB",
			wantError: true,
			errorMsg:  "len(poolPathSplit) != 3",
		},
		{
			name:      "invalid - too many parts",
			poolPath:  "tokenA:tokenB:500:extra",
			wantError: true,
			errorMsg:  "len(poolPathSplit) != 3",
		},
		{
			name:      "invalid - non-numeric fee",
			poolPath:  "tokenA:tokenB:abc",
			wantError: true,
			errorMsg:  "invalid fee",
		},
		{
			name:      "invalid - empty first token",
			poolPath:  ":tokenB:500",
			wantError: true,
			errorMsg:  "token addresses cannot be empty",
		},
		{
			name:      "invalid - empty second token",
			poolPath:  "tokenA::500",
			wantError: true,
			errorMsg:  "token addresses cannot be empty",
		},
		{
			name:      "invalid - both tokens empty",
			poolPath:  "::500",
			wantError: true,
			errorMsg:  "token addresses cannot be empty",
		},
		{
			name:       "edge case - zero fee",
			poolPath:   "tokenA:tokenB:0",
			wantToken0: "tokenA",
			wantToken1: "tokenB",
			wantFee:    0,
			wantError:  false,
		},
		{
			name:       "edge case - large fee",
			poolPath:   "tokenA:tokenB:4294967295",
			wantToken0: "tokenA",
			wantToken1: "tokenB",
			wantFee:    4294967295,
			wantError:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			token0, token1, fee, err := getDataForSinglePathWithError(tt.poolPath)

			if tt.wantError {
				uassert.True(t, err != nil, "expected error but got none")
				if tt.errorMsg != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.errorMsg),
						"error message should contain: "+tt.errorMsg)
				}
			} else {
				uassert.Nil(t, err)
				uassert.Equal(t, tt.wantToken0, token0)
				uassert.Equal(t, tt.wantToken1, token1)
				uassert.Equal(t, tt.wantFee, fee)
			}
		})
	}
}
