package v1

import (
	"strings"
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/common"
)

func TestNewPoolParams(t *testing.T) {
	t.Run(
		"success - normal token pair",
		func(t *testing.T) {
			initPoolTest(t)

			params := newPoolParams(
				"token0",
				"token1",
				500,       // 0.05% fee
				"1000000", // example sqrt price
				getMockInstance().GetFeeAmountTickSpacing(500),
				0,
			)

			if params.Token0Path() != "token0" {
				t.Errorf("Expected token0Path to be 'token0', got %s", params.Token0Path())
			}

			if params.TickSpacing() != 10 { // 500 fee should have 10 tick spacing
				t.Errorf("Expected tick spacing 10, got %d", params.TickSpacing())
			}

			if !params.isInOrder() {
				t.Errorf("Expected token0Path(token0) < token1Path(token1)")
			}
		},
	)

	t.Run(
		"Success - native token wrapped ugnot token",
		func(t *testing.T) {
			initPoolTest(t)

			params := newPoolParams(
				GNOT_DENOM,
				"token1",
				500,
				"1000000",
				getMockInstance().GetFeeAmountTickSpacing(500),
				0,
			)
			token0, _ := params.wrap()
			if token0 != WUGNOT_PATH {
				t.Errorf("Expected GNOT to be wrapped to WUGNOT")
			}
		},
	)
}

func TestNewPoolParam(t *testing.T) {
	testCases := []struct {
		name            string
		token0Path      string
		token1Path      string
		fee             uint32
		sqrtPriceX96Str string
		sqrtPriceX96    *u256.Uint
		tickSpacing     int32
		expectedPanic   bool
		expectedMsg     string
	}{
		{
			name:            "success - normal token pair",
			token0Path:      gnsPath,
			token1Path:      wugnotPath,
			fee:             FeeTier3000,
			sqrtPriceX96Str: MAX_PRICE_IMPACT,
			sqrtPriceX96:    u256.MustFromDecimal(MAX_PRICE_IMPACT),
			tickSpacing:     getMockInstance().GetFeeAmountTickSpacing(FeeTier3000),
			expectedPanic:   false,
		},
	}

	for _, tt := range testCases {
		t.Run(tt.name, func(t *testing.T) {
			params := newPoolParams(tt.token0Path, tt.token1Path, tt.fee, tt.sqrtPriceX96Str, tt.tickSpacing, 0)
			uassert.Equal(t, params.token0Path, gnsPath, "Token0Path should match")
			uassert.Equal(t, params.token1Path, wugnotPath, "Token1Path should match")
			uassert.Equal(t, params.fee, FeeTier3000, "Fee should match")
			uassert.Equal(t, params.tickSpacing, params.TickSpacing(), "TickSpacing should match")
			uassert.Equal(t, params.SqrtPriceX96().ToString(), u256.MustFromDecimal(tt.sqrtPriceX96Str).ToString(), "SqrtPriceX96 should match")
		})
	}
}

func TestIsInOrder(t *testing.T) {
	const (
		gnsPath    = "gno.land/r/gnoswap/gns"
		wugnotPath = "gno.land/r/gnoswap/v1/wugnot"
	)

	testCases := []struct {
		name            string
		token0Path      string
		token1Path      string
		fee             uint32
		sqrtPriceX96Str string
		sqrtPriceX96    *u256.Uint
		tickSpacing     int32
		expectedPanic   bool
		expectedMsg     string
	}{
		{
			name:            "success - normal token pair",
			token0Path:      gnsPath,
			token1Path:      wugnotPath,
			fee:             FeeTier3000,
			sqrtPriceX96Str: MAX_PRICE_IMPACT,
			sqrtPriceX96:    u256.MustFromDecimal(MAX_PRICE_IMPACT),
			tickSpacing:     getMockInstance().GetFeeAmountTickSpacing(FeeTier3000),
			expectedPanic:   false,
		},
	}

	for _, tt := range testCases {
		t.Run(tt.name, func(t *testing.T) {
			params := newPoolParams(tt.token0Path, tt.token1Path, tt.fee, tt.sqrtPriceX96Str, tt.tickSpacing, 0)
			poolPath := params.poolPath()
			uassert.Equal(t, poolPath, "gno.land/r/gnoswap/gns:gno.land/r/gnoswap/v1/wugnot:3000", "Pool path should match")
			uassert.Equal(t, params.isInOrder(), true, "Tokens order should match")
		})
	}
}

func TestUpdateWithWrapping(t *testing.T) {
	const (
		gnsPath    = "gno.land/r/gnoswap/gns"
		wugnotPath = "gno.land/r/gnoswap/v1/wugnot"
	)

	tick := int32(-11242)
	sqrtPriceX96FromTick := common.TickMathGetSqrtRatioAtTick(tick)

	tests := []struct {
		name            string
		token0Path      string
		token1Path      string
		fee             uint32
		sqrtPriceX96Str string
		sqrtPriceX96    *u256.Uint
		tickSpacing     int32
		expectedPanic   bool
		expectedMsg     string
	}{
		{
			name:            "success - update with wrapping",
			token0Path:      wugnotPath,
			token1Path:      gnsPath,
			fee:             FeeTier3000,
			sqrtPriceX96Str: MAX_PRICE_IMPACT,
			sqrtPriceX96:    u256.MustFromDecimal(MAX_PRICE_IMPACT),
			tickSpacing:     getMockInstance().GetFeeAmountTickSpacing(FeeTier3000),
			expectedPanic:   false,
		},
		{
			name:            "success - near MIN_SQRT_RATIO",
			token0Path:      wugnotPath,
			token1Path:      gnsPath,
			fee:             FeeTier3000,
			sqrtPriceX96Str: "4295128740", // MIN_SQRT_RATIO + 1
			sqrtPriceX96:    u256.MustFromDecimal("4295128740"),
			tickSpacing:     getMockInstance().GetFeeAmountTickSpacing(FeeTier3000),
			expectedPanic:   false,
		},
		{
			name:            "fail - below MIN_SQRT_RATIO",
			token0Path:      wugnotPath,
			token1Path:      gnsPath,
			fee:             FeeTier3000,
			sqrtPriceX96Str: "4295128738",                       // MIN_SQRT_RATIO - 1
			sqrtPriceX96:    u256.MustFromDecimal("4295128738"), // Fixed to match the string
			tickSpacing:     getMockInstance().GetFeeAmountTickSpacing(FeeTier3000),
			expectedPanic:   true,
			expectedMsg:     "out of range for numeric value",
		},
		{
			name:            "fail - above MAX_SQRT_RATIO",
			token0Path:      wugnotPath,
			token1Path:      gnsPath,
			fee:             FeeTier3000,
			sqrtPriceX96Str: "1461446703485210103287273052203988822378723970342", // MAX_SQRT_RATIO + 1
			sqrtPriceX96:    u256.MustFromDecimal("1461446703485210103287273052203988822378723970342"),
			tickSpacing:     getMockInstance().GetFeeAmountTickSpacing(FeeTier3000),
			expectedPanic:   true,
			expectedMsg:     "out of range for numeric value",
		},
		{
			name:            "success - update with wrapping",
			token0Path:      wugnotPath,
			token1Path:      gnsPath,
			fee:             FeeTier3000,
			sqrtPriceX96Str: sqrtPriceX96FromTick.ToString(),
			sqrtPriceX96:    sqrtPriceX96FromTick,
			tickSpacing:     getMockInstance().GetFeeAmountTickSpacing(FeeTier3000),
			expectedPanic:   false,
		},
		{
			name:            "fail - tokens swapped below MIN_SQRT_RATIO",
			token0Path:      gnsPath,    // swapped: gns first
			token1Path:      wugnotPath, // swapped: wugnot second
			fee:             FeeTier3000,
			sqrtPriceX96Str: "4295128738", // MIN_SQRT_RATIO - 1
			sqrtPriceX96:    u256.MustFromDecimal("4295128738"),
			tickSpacing:     getMockInstance().GetFeeAmountTickSpacing(FeeTier3000),
			expectedPanic:   true,
			expectedMsg:     "out of range for numeric value",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := newPoolParams(tt.token0Path, tt.token1Path, tt.fee, tt.sqrtPriceX96Str, tt.tickSpacing, 0)
			err := params.updateWithWrapping()

			if tt.expectedPanic {
				uassert.NotNil(t, err, "Expected error but got none")
				if err != nil {
					uassert.True(t, strings.Contains(err.Error(), tt.expectedMsg),
						ufmt.Sprintf("Expected error message to contain %s, got %s", tt.expectedMsg, err.Error()))
				}
				return
			}

			uassert.Nil(t, err, "Unexpected error: "+ufmt.Sprintf("%v", err))

			expected0 := params.token0Path
			expected1 := params.token1Path
			if !params.isInOrder() {
				expected0, expected1 = expected1, expected0
			}

			uassert.Equal(t, expected0, params.Token0Path(), "Token0Path should be swapped if needed")
			uassert.Equal(t, expected1, params.Token1Path(), "Token1Path should be swapped if needed")

			// Verify that the inverted price is within valid range
			if !params.isInOrder() {

				newSqrtPriceX96 := params.SqrtPriceX96()

				if newSqrtPriceX96.Lt(minSqrtRatio) || newSqrtPriceX96.Gt(maxSqrtRatio) {
					t.Errorf("Inverted price %s is out of valid range [%s, %s]",
						newSqrtPriceX96.ToString(),
						minSqrtRatio.ToString(),
						maxSqrtRatio.ToString())
				}
			}
		})
	}
}

func TestWrap(t *testing.T) {
	testCases := []struct {
		name            string
		token0Path      string
		token1Path      string
		fee             uint32
		sqrtPriceX96Str string
		sqrtPriceX96    *u256.Uint
		tickSpacing     int32
		expectedPanic   bool
		expectedMsg     string
	}{
		{
			name:            "success - native token wrapped ugnot token",
			token0Path:      GNOT_DENOM,
			token1Path:      gnsPath,
			fee:             FeeTier3000,
			sqrtPriceX96Str: MAX_PRICE_IMPACT,
			sqrtPriceX96:    u256.MustFromDecimal(MAX_PRICE_IMPACT),
			tickSpacing:     getMockInstance().GetFeeAmountTickSpacing(FeeTier3000),
			expectedPanic:   false,
		},
	}

	for _, tt := range testCases {
		t.Run(tt.name, func(t *testing.T) {
			params := newPoolParams(tt.token0Path, tt.token1Path, tt.fee, tt.sqrtPriceX96Str, tt.tickSpacing, 0)
			wrapped0, wrapped1 := params.wrap()

			expected0 := params.token0Path
			expected1 := params.token1Path

			if params.token0Path == GNOT_DENOM {
				expected0 = WUGNOT_PATH
			}
			if params.token1Path == GNOT_DENOM {
				expected1 = WUGNOT_PATH
			}

			uassert.Equal(t, expected0, wrapped0, "Token0 should be wrapped if GNOT")
			uassert.Equal(t, expected1, wrapped1, "Token1 should be wrapped if GNOT")
		})
	}
}

func TestGeneratePoolPath(t *testing.T) {
	testCases := []struct {
		name            string
		token0Path      string
		token1Path      string
		fee             uint32
		sqrtPriceX96Str string
		sqrtPriceX96    *u256.Uint
		tickSpacing     int32
		expectedPanic   bool
		expectedMsg     string
	}{
		{
			name:            "success - pool path generated correctly",
			token0Path:      gnsPath,
			token1Path:      wugnotPath,
			fee:             FeeTier3000,
			sqrtPriceX96Str: MAX_PRICE_IMPACT,
			sqrtPriceX96:    u256.MustFromDecimal(MAX_PRICE_IMPACT),
			tickSpacing:     getMockInstance().GetFeeAmountTickSpacing(FeeTier3000),
			expectedPanic:   false,
		},
	}

	for _, tt := range testCases {
		t.Run(tt.name, func(t *testing.T) {
			params := newPoolParams(tt.token0Path, tt.token1Path, tt.fee, tt.sqrtPriceX96Str, tt.tickSpacing, 0)
			expected := ufmt.Sprintf("%s:%s:%d", params.token0Path, params.token1Path, params.fee)
			if !params.isInOrder() {
				expected = ufmt.Sprintf("%s:%s:%d", params.token1Path, params.token0Path, params.fee)
			}
			actual := params.poolPath()

			uassert.Equal(t, expected, actual, "Pool path should match expected")
		})
	}
}

// TestIsValidFeeTier tests validation of fee tier values
func TestIsValidFeeTier(t *testing.T) {
	tests := []struct {
		name     string
		feeTier  uint32
		expected bool
	}{
		{
			name:     "valid - FeeTier100",
			feeTier:  FeeTier100,
			expected: true,
		},
		{
			name:     "valid - FeeTier500",
			feeTier:  FeeTier500,
			expected: true,
		},
		{
			name:     "valid - FeeTier3000",
			feeTier:  FeeTier3000,
			expected: true,
		},
		{
			name:     "valid - FeeTier10000",
			feeTier:  FeeTier10000,
			expected: true,
		},
		{
			name:     "invalid - zero",
			feeTier:  0,
			expected: false,
		},
		{
			name:     "invalid - 99",
			feeTier:  99,
			expected: false,
		},
		{
			name:     "invalid - 101",
			feeTier:  101,
			expected: false,
		},
		{
			name:     "invalid - 499",
			feeTier:  499,
			expected: false,
		},
		{
			name:     "invalid - 501",
			feeTier:  501,
			expected: false,
		},
		{
			name:     "invalid - 2999",
			feeTier:  2999,
			expected: false,
		},
		{
			name:     "invalid - 3001",
			feeTier:  3001,
			expected: false,
		},
		{
			name:     "invalid - 9999",
			feeTier:  9999,
			expected: false,
		},
		{
			name:     "invalid - 10001",
			feeTier:  10001,
			expected: false,
		},
		{
			name:     "invalid - max uint32",
			feeTier:  4294967295,
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isValidFeeTier(tt.feeTier)
			uassert.Equal(t, tt.expected, result, "Fee tier validation result should match expected")
		})
	}
}

// TestValidateSqrtPriceX96 tests validation of sqrtPriceX96 values
func TestValidateSqrtPriceX96(t *testing.T) {
	tests := []struct {
		name         string
		sqrtPriceX96 *u256.Uint
		shouldError  bool
	}{
		{
			name:         "valid - at MIN_SQRT_RATIO",
			sqrtPriceX96: u256.MustFromDecimal(MIN_SQRT_RATIO),
			shouldError:  false,
		},
		{
			name:         "valid - just above MIN_SQRT_RATIO",
			sqrtPriceX96: u256.MustFromDecimal("4295128740"),
			shouldError:  false,
		},
		{
			name:         "valid - at MAX_SQRT_RATIO",
			sqrtPriceX96: u256.MustFromDecimal(MAX_SQRT_RATIO),
			shouldError:  false,
		},
		{
			name:         "valid - just below MAX_SQRT_RATIO",
			sqrtPriceX96: u256.MustFromDecimal("1461446703485210103287273052203988822378723970341"),
			shouldError:  false,
		},
		{
			name:         "valid - middle value",
			sqrtPriceX96: u256.MustFromDecimal("79228162514264337593543950336"),
			shouldError:  false,
		},
		{
			name:         "invalid - below MIN_SQRT_RATIO",
			sqrtPriceX96: u256.MustFromDecimal("4295128738"),
			shouldError:  true,
		},
		{
			name:         "invalid - zero",
			sqrtPriceX96: u256.Zero(),
			shouldError:  true,
		},
		{
			name:         "invalid - one",
			sqrtPriceX96: u256.One(),
			shouldError:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateSqrtPriceX96(tt.sqrtPriceX96)
			if tt.shouldError {
				uassert.NotNil(t, err, "Expected error but got none")
			} else {
				uassert.Nil(t, err, "Expected no error but got: "+ufmt.Sprintf("%v", err))
			}
		})
	}
}

// TestIsSameTokenPath tests detection of duplicate token paths
func TestIsSameTokenPath(t *testing.T) {
	tests := []struct {
		name       string
		token0Path string
		token1Path string
		expected   bool
	}{
		{
			name:       "different tokens",
			token0Path: gnsPath,
			token1Path: wugnotPath,
			expected:   false,
		},
		{
			name:       "same token path",
			token0Path: gnsPath,
			token1Path: gnsPath,
			expected:   true,
		},
		{
			name:       "empty strings",
			token0Path: "",
			token1Path: "",
			expected:   true,
		},
		{
			name:       "one empty one valid",
			token0Path: gnsPath,
			token1Path: "",
			expected:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := newPoolParams(tt.token0Path, tt.token1Path, FeeTier3000, MAX_PRICE_IMPACT, 60, 0)
			result := params.isSameTokenPath()
			uassert.Equal(t, tt.expected, result, "Same token path check should match expected")
		})
	}
}

// TestIsSupportedFee tests fee tier support validation
func TestIsSupportedFee(t *testing.T) {
	params := newPoolParams(gnsPath, wugnotPath, FeeTier3000, MAX_PRICE_IMPACT, 60, 0)

	tests := []struct {
		name     string
		feeTier  uint32
		expected bool
	}{
		{
			name:     "supported - 100",
			feeTier:  FeeTier100,
			expected: true,
		},
		{
			name:     "supported - 500",
			feeTier:  FeeTier500,
			expected: true,
		},
		{
			name:     "supported - 3000",
			feeTier:  FeeTier3000,
			expected: true,
		},
		{
			name:     "supported - 10000",
			feeTier:  FeeTier10000,
			expected: true,
		},
		{
			name:     "unsupported - 0",
			feeTier:  0,
			expected: false,
		},
		{
			name:     "unsupported - 200",
			feeTier:  200,
			expected: false,
		},
		{
			name:     "unsupported - 5000",
			feeTier:  5000,
			expected: false,
		},
		{
			name:     "unsupported - max uint32",
			feeTier:  4294967295,
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := params.isSupportedFee(tt.feeTier)
			uassert.Equal(t, tt.expected, result, "Fee support check should match expected")
		})
	}
}
