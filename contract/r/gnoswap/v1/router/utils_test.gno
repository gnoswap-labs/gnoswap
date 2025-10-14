package router

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
