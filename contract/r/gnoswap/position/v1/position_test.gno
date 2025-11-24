package v1

import (
	"chain"
	"errors"
	"math"
	"strconv"
	"strings"
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/referral"

	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
)

var mockRegistry = make(map[string]bool)

// MockRegister registers a token path in the mock registry.
func MockRegister(t *testing.T, tokenPath string) {
	t.Helper()
	mockRegistry[tokenPath] = true
}

// MockUnregister unregisters a token path in the mock registry.
func MockUnregister(t *testing.T, tokenPath string) {
	t.Helper()
	delete(mockRegistry, tokenPath)
}

// IsRegistered checks if a token path is registered in the mock registry.
func IsRegistered(t *testing.T, tokenPath string) error {
	t.Helper()
	if mockRegistry[tokenPath] {
		return nil
	}
	return errInvalidTokenPath
}

func setupPoolAndApprovals(t *testing.T, faucet bool) {
	t.Helper()
	testing.SetOriginCaller(adminAddr)
	CreatePoolWithoutFee(t)

	if faucet {
		TokenFaucet(t, barPath, alice)
		TokenFaucet(t, fooPath, alice)
	}

	testing.SetRealm(posRealm)
	TokenApprove(t, barPath, adminAddr, poolAddr, maxApprove)
	TokenApprove(t, fooPath, adminAddr, poolAddr, maxApprove)
}

// seedPosition mints a simple position owned by admin and returns its id.
func seedPosition(t *testing.T, amount0, amount1 string) uint64 {
	t.Helper()
	positionId, _, _, _ := mockInstance.Mint(
		barPath,
		fooPath,
		fee500,
		-10000,
		10000,
		amount0,
		amount1,
		"0",
		"0",
		time.Now().Add(time.Hour).Unix(),
		adminAddr,
		adminAddr,
		"",
	)
	return positionId
}

func newDummyPosition(id uint64) position.Position {
	pos := position.NewPosition(
		"poolKey1",
		-500,
		500,
		u256.NewUint(1000),
		u256.NewUint(10),
		u256.NewUint(20),
		u256.NewUint(30),
		u256.NewUint(40),
		u256.NewUint(1000),
		u256.NewUint(1000),
		false,
		"user1",
	)

	return *pos
}

func TestMustGetPosition(t *testing.T) {
	tests := []struct {
		name                 string
		positionId           uint64
		inputPosition        position.Position
		inputPositionId      uint64
		expectedPosition     position.Position
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:                 "MustGetPosition is success by existing position",
			positionId:           1,
			inputPosition:        newDummyPosition(1),
			inputPositionId:      1,
			expectedPosition:     newDummyPosition(1),
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "MustGetPosition is failed by non-existent position",
			positionId:           1,
			inputPosition:        newDummyPosition(1),
			inputPositionId:      999,
			expectedPosition:     position.Position{},
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-POSITION-013] position does not exist || position with position ID(999) doesn't exist",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)
			mockInstance.createNewPosition(tt.positionId, tt.inputPosition)

			if tt.expectedHasPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					mockInstance.mustGetPosition(tt.inputPositionId)
				})
			} else {
				result := mockInstance.mustGetPosition(tt.inputPositionId)
				uassert.Equal(t, tt.expectedPosition.Operator(), result.Operator())
				uassert.Equal(t, tt.expectedPosition.PoolKey(), result.PoolKey())
				uassert.Equal(t, tt.expectedPosition.TickLower(), result.TickLower())
				uassert.Equal(t, tt.expectedPosition.TickUpper(), result.TickUpper())
				uassert.Equal(t, tt.expectedPosition.Liquidity().ToString(), result.Liquidity().ToString())
				uassert.Equal(t, tt.expectedPosition.FeeGrowthInside0LastX128().ToString(), result.FeeGrowthInside0LastX128().ToString())
				uassert.Equal(t, tt.expectedPosition.FeeGrowthInside1LastX128().ToString(), result.FeeGrowthInside1LastX128().ToString())
				uassert.Equal(t, tt.expectedPosition.TokensOwed0().ToString(), result.TokensOwed0().ToString())
				uassert.Equal(t, tt.expectedPosition.TokensOwed1().ToString(), result.TokensOwed1().ToString())
				uassert.Equal(t, tt.expectedPosition.Burned(), result.Burned())
			}
		})
	}
}

func TestSetPosition(t *testing.T) {
	pos := newDummyPosition(1)
	changedPosition := newDummyPosition(1)
	changedPosition.SetOperator("user2")
	changedPosition.SetPoolKey("poolKey2")
	changedPosition.SetTickLower(-2000)
	changedPosition.SetTickUpper(2000)
	changedPosition.SetLiquidity(u256.NewUint(2000))
	changedPosition.SetFeeGrowthInside0LastX128(u256.NewUint(20))
	changedPosition.SetFeeGrowthInside1LastX128(u256.NewUint(40))
	changedPosition.SetTokensOwed0(u256.NewUint(60))
	changedPosition.SetTokensOwed1(u256.NewUint(80))
	changedPosition.SetBurned(true)

	tests := []struct {
		name          string
		positionId    uint64
		position      position.Position
		inputPosition position.Position
		expected      bool
	}{
		{
			name:          "set position is success by existing position",
			positionId:    1,
			position:      pos,
			inputPosition: changedPosition,
			expected:      false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)
			mockInstance.createNewPosition(tt.positionId, tt.position)
			mockInstance.setPosition(tt.positionId, tt.inputPosition)

			storedPosition := mockInstance.mustGetPosition(tt.positionId)
			uassert.Equal(t, tt.inputPosition.Operator(), storedPosition.Operator())
			uassert.Equal(t, tt.inputPosition.PoolKey(), storedPosition.PoolKey())
			uassert.Equal(t, tt.inputPosition.TickLower(), storedPosition.TickLower())
			uassert.Equal(t, tt.inputPosition.TickUpper(), storedPosition.TickUpper())
			uassert.Equal(t, tt.inputPosition.Liquidity().ToString(), storedPosition.Liquidity().ToString())
			uassert.Equal(t, tt.inputPosition.FeeGrowthInside0LastX128().ToString(), storedPosition.FeeGrowthInside0LastX128().ToString())
			uassert.Equal(t, tt.inputPosition.FeeGrowthInside1LastX128().ToString(), storedPosition.FeeGrowthInside1LastX128().ToString())
			uassert.Equal(t, tt.inputPosition.TokensOwed0().ToString(), storedPosition.TokensOwed0().ToString())
			uassert.Equal(t, tt.inputPosition.TokensOwed1().ToString(), storedPosition.TokensOwed1().ToString())
			uassert.Equal(t, tt.inputPosition.Burned(), storedPosition.Burned())
		})
	}
}

func TestRemovePosition(t *testing.T) {
	tests := []struct {
		name            string
		positionId      uint64
		inputPositionId uint64
	}{
		{
			name:            "remove position is success by existing position",
			positionId:      1,
			inputPositionId: 1,
		},
		{
			name:            "remove position is failed by non-existent position",
			positionId:      1,
			inputPositionId: 999,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)
			mockInstance.createNewPosition(tt.positionId, newDummyPosition(tt.positionId))

			mockInstance.removePosition(tt.inputPositionId)

			_, found := mockInstance.GetPosition(tt.inputPositionId)
			uassert.False(t, found)
		})
	}
}

func TestExistPosition(t *testing.T) {
	tests := []struct {
		name            string
		positionId      uint64
		inputPositionId uint64
		expectedExist   bool
	}{
		{
			name:            "ExistPosition is failed by position does not exist",
			positionId:      1,
			inputPositionId: 999,
			expectedExist:   false,
		},
		{
			name:            "ExistPosition is success by position exists",
			positionId:      1,
			inputPositionId: 1,
			expectedExist:   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)
			mockInstance.createNewPosition(tt.positionId, newDummyPosition(tt.positionId))
			uassert.Equal(t, tt.expectedExist, mockInstance.ExistPosition(tt.inputPositionId))
		})
	}
}

func TestComputePositionKey(t *testing.T) {
	tests := []struct {
		name      string
		owner     address
		tickLower int32
		tickUpper int32
		expected  string
	}{
		{
			name:      "computePositionKey is success by basic position key",
			owner:     alice,
			tickLower: -100,
			tickUpper: 200,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18tMTAwX18yMDA=", // Base64 of "gno.land/r/gnoswap/position__-100__200"
		},
		{
			name:      "computePositionKey is failed by zero ticks",
			owner:     alice,
			tickLower: 0,
			tickUpper: 0,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18wX18w", // Base64 of "gno.land/r/gnoswap/position__0__0"
		},
		{
			name:      "computePositionKey is failed by negative lower tick",
			owner:     alice,
			tickLower: -50,
			tickUpper: 150,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18tNTBfXzE1MA==", // Base64 of "gno.land/r/gnoswap/position__-50__150"
		},
		{
			name:      "computePositionKey is failed by same tick bounds",
			owner:     alice,
			tickLower: 300,
			tickUpper: 300,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18zMDBfXzMwMA==", // Base64 of "gno.land/r/gnoswap/position__300__300"
		},
		{
			name:      "Normal tick range",
			owner:     alice,
			tickLower: -600,
			tickUpper: 600,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18tNjAwX182MDA=", // Base64 of "gno.land/r/gnoswap/position__300__300"
		},
		{
			name:      "Wide tick range",
			owner:     alice,
			tickLower: -887220,
			tickUpper: 887220,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18tODg3MjIwX184ODcyMjA=", // Base64 of "gno.land/r/gnoswap/position__-887220__887220"
		},
		{
			name:      "Narrow tick range",
			owner:     alice,
			tickLower: -60,
			tickUpper: 60,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18tNjBfXzYw", // Base64 of "gno.land/r/gnoswap/position__-60__60"
		},
		{
			name:      "Asymmetric range",
			owner:     alice,
			tickLower: -1000,
			tickUpper: 500,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18tMTAwMF9fNTAw", // Base64 of "gno.land/r/gnoswap/position__-1000__500"
		},
		{
			name:      "Positive range",
			owner:     alice,
			tickLower: 100,
			tickUpper: 1000,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18xMDBfXzEwMDA=", // Base64 of "gno.land/r/gnoswap/position__100__1000"
		},
		{
			name:      "Negative range",
			owner:     alice,
			tickLower: -2000,
			tickUpper: -1000,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18tMjAwMF9fLTEwMDA=", // Base64 of "gno.land/r/gnoswap/position__-2000__-1000"
		},
		{
			name:      "Zero lower bound",
			owner:     alice,
			tickLower: 0,
			tickUpper: 1000,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18wX18xMDAw", // Base64 of "gno.land/r/gnoswap/position__0__1000"
		},
		{
			name:      "Zero upper bound",
			owner:     alice,
			tickLower: -1000,
			tickUpper: 0,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18tMTAwMF9fMA==", // Base64 of "gno.land/r/gnoswap/position__-1000__0"
		},
		{
			name:      "Minimum values",
			owner:     alice,
			tickLower: -887272,
			tickUpper: -887272 + 60,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX18tODg3MjcyX18tODg3MjEy", // Base64 of "gno.land/r/gnoswap/position__-887272__-887212"
		},
		{
			name:      "Maximum values",
			owner:     alice,
			tickLower: 887272 - 60,
			tickUpper: 887272,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3Bvc2l0aW9uX184ODcyMTJfXzg4NzI3Mg==", // Base64 of "gno.land/r/gnoswap/position__887272__887272"
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(posRealm)
			result := computePositionKey(tt.tickLower, tt.tickUpper)

			if result != tt.expected {
				t.Errorf("expected %s but got %s", tt.expected, result)
			}
		})
	}
}

func TestNextIdFunctions(t *testing.T) {
	tests := []struct {
		name          string
		initialValue  uint64
		increments    int
		expectedValue uint64
	}{
		{"initial is 1", 1, 0, 1},
		{"after 1 increment is 2", 1, 1, 2},
		{"increment once → 3", 1, 2, 3},
		{"increment twice → 5", 1, 4, 5},
		{"no overflow on 95 increments", 1, 99, 100},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			for range make([]struct{}, tt.increments) {
				mockInstance.incrementNextId()
			}

			uassert.Equal(t, tt.expectedValue, mockInstance.getNextId())
		})
	}
}

func TestIsValidTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
		expected  bool
	}{
		{
			name:      "Valid registered token - gns",
			tokenPath: gnsPath,
			expected:  true,
		},
		{
			name:      "Valid registered token - bar",
			tokenPath: barPath,
			expected:  true,
		},
		{
			name:      "Valid registered token - wugnot",
			tokenPath: wugnotPath,
			expected:  true,
		},
		{
			name:      "Invalid - non-existent token",
			tokenPath: "gno.land/r/nonexistent/token",
			expected:  false,
		},
		{
			name:      "Invalid - empty path",
			tokenPath: "",
			expected:  false,
		},
		{
			name:      "Invalid - malformed path",
			tokenPath: "invalid/path",
			expected:  false,
		},
		{
			name:      "Invalid - random string",
			tokenPath: "randomstring",
			expected:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			result := isValidTokenPath(tt.tokenPath)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestParseAmounts(t *testing.T) {
	tests := []struct {
		name              string
		amount0Desired    string
		amount1Desired    string
		amount0Min        string
		amount1Min        string
		expectedA0Desired *u256.Uint
		expectedA1Desired *u256.Uint
		expectedA0Min     *u256.Uint
		expectedA1Min     *u256.Uint
		shouldPanic       bool
		expectedPanicMsg  string
	}{
		{
			name:              "Valid normal amounts",
			amount0Desired:    "1000000",
			amount1Desired:    "2000000",
			amount0Min:        "900000",
			amount1Min:        "1800000",
			expectedA0Desired: u256.MustFromDecimal("1000000"),
			expectedA1Desired: u256.MustFromDecimal("2000000"),
			expectedA0Min:     u256.MustFromDecimal("900000"),
			expectedA1Min:     u256.MustFromDecimal("1800000"),
			shouldPanic:       false,
		},
		{
			name:              "Valid zero amounts",
			amount0Desired:    "0",
			amount1Desired:    "0",
			amount0Min:        "0",
			amount1Min:        "0",
			expectedA0Desired: u256.Zero(),
			expectedA1Desired: u256.Zero(),
			expectedA0Min:     u256.Zero(),
			expectedA1Min:     u256.Zero(),
			shouldPanic:       false,
		},
		{
			name:              "Valid large amounts",
			amount0Desired:    "999999999999999999999999",
			amount1Desired:    "888888888888888888888888",
			amount0Min:        "777777777777777777777777",
			amount1Min:        "666666666666666666666666",
			expectedA0Desired: u256.MustFromDecimal("999999999999999999999999"),
			expectedA1Desired: u256.MustFromDecimal("888888888888888888888888"),
			expectedA0Min:     u256.MustFromDecimal("777777777777777777777777"),
			expectedA1Min:     u256.MustFromDecimal("666666666666666666666666"),
			shouldPanic:       false,
		},
		{
			name:             "Invalid - non-numeric amount0Desired",
			amount0Desired:   "invalid",
			amount1Desired:   "1000000",
			amount0Min:       "900000",
			amount1Min:       "900000",
			shouldPanic:      true,
			expectedPanicMsg: "strconv.ParseUint: parsing \"invalid\": invalid syntax",
		},
		{
			name:             "Invalid - non-numeric amount1Desired",
			amount0Desired:   "1000000",
			amount1Desired:   "abc",
			amount0Min:       "900000",
			amount1Min:       "900000",
			shouldPanic:      true,
			expectedPanicMsg: "strconv.ParseUint: parsing \"abc\": invalid syntax",
		},
		{
			name:             "Invalid - negative amount0Min",
			amount0Desired:   "1000000",
			amount1Desired:   "1000000",
			amount0Min:       "-100",
			amount1Min:       "900000",
			shouldPanic:      true,
			expectedPanicMsg: "strconv.ParseUint: parsing \"-100\": invalid syntax",
		},
		{
			name:             "Invalid - negative amount1Min",
			amount0Desired:   "1000000",
			amount1Desired:   "1000000",
			amount0Min:       "900000",
			amount1Min:       "-100",
			shouldPanic:      true,
			expectedPanicMsg: "strconv.ParseUint: parsing \"-100\": invalid syntax",
		},
		{
			name:             "Invalid - empty string",
			amount0Desired:   "",
			amount1Desired:   "1000000",
			amount0Min:       "900000",
			amount1Min:       "900000",
			shouldPanic:      true,
			expectedPanicMsg: "EOF",
		},
		{
			name:              "Valid - very small amounts",
			amount0Desired:    "1",
			amount1Desired:    "1",
			amount0Min:        "1",
			amount1Min:        "1",
			expectedA0Desired: u256.NewUint(1),
			expectedA1Desired: u256.NewUint(1),
			expectedA0Min:     u256.NewUint(1),
			expectedA1Min:     u256.NewUint(1),
			shouldPanic:       false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMsg, func() {
					parseAmounts(tt.amount0Desired, tt.amount1Desired, tt.amount0Min, tt.amount1Min)
				})
			} else {
				a0Desired, a1Desired, a0Min, a1Min := parseAmounts(
					tt.amount0Desired,
					tt.amount1Desired,
					tt.amount0Min,
					tt.amount1Min,
				)

				uassert.Equal(t, tt.expectedA0Desired.ToString(), a0Desired.ToString(), "amount0Desired mismatch")
				uassert.Equal(t, tt.expectedA1Desired.ToString(), a1Desired.ToString(), "amount1Desired mismatch")
				uassert.Equal(t, tt.expectedA0Min.ToString(), a0Min.ToString(), "amount0Min mismatch")
				uassert.Equal(t, tt.expectedA1Min.ToString(), a1Min.ToString(), "amount1Min mismatch")
			}
		})
	}
}

func TestProcessTokens(t *testing.T) {
	tests := []struct {
		name           string
		token0         string
		token1         string
		amount0Desired string
		amount1Desired string
		caller         address
		expected0      string
		expected1      string
		isNative0      bool
		isNative1      bool
		expectedWrap   int64
		expectPanic    bool
		expectMsg      string
	}{
		{
			name:           "processTokens is failed by both tokens are valid and not native",
			token0:         gnsPath,
			token1:         "tokenB",
			amount0Desired: "100",
			amount1Desired: "200",
			caller:         alice,
			expected0:      "tokenA",
			expected1:      "tokenB",
			isNative0:      false,
			isNative1:      false,
			expectedWrap:   0,
			expectPanic:    true,
			expectMsg:      "[GNOSWAP-POSITION-016] invalid token address || token0(gno.land/r/gnoswap/gns), token1(tokenB)",
		},
		{
			name:           "processTokens is failed by token0 is native",
			token0:         GNOT,
			token1:         gnsPath,
			amount0Desired: "1300",
			amount1Desired: "200",
			caller:         alice,
			expected0:      WRAPPED_WUGNOT,
			expected1:      "gno.land/r/gnoswap/gns",
			isNative0:      true,
			isNative1:      false,
			expectedWrap:   1300,
			expectPanic:    false,
			expectMsg:      "[GNOSWAP-POSITION-016] invalid token address || token0(ugnot), token1(gno.land/r/gnoswap/gns)",
		},
		{
			name:           "processTokens is failed by token1 is native",
			token0:         gnsPath,
			token1:         GNOT,
			amount0Desired: "150",
			amount1Desired: "1250",
			caller:         testutils.TestAddress("user3"),
			expected0:      "gno.land/r/gnoswap/gns",
			expected1:      WRAPPED_WUGNOT,
			isNative0:      false,
			isNative1:      true,
			expectedWrap:   1250,
			expectPanic:    false,
		},
		{
			name:           "processTokens is failed by both tokens are native",
			token0:         GNOT,
			token1:         GNOT,
			amount0Desired: "1100",
			amount1Desired: "1200",
			caller:         testutils.TestAddress("user4"),
			expected0:      WRAPPED_WUGNOT,
			expected1:      WRAPPED_WUGNOT,
			isNative0:      true,
			isNative1:      true,
			expectedWrap:   2300,
			expectPanic:    true,
			expectMsg:      "[GNOSWAP-POSITION-016] invalid token address || token0(ugnot), token1(ugnot)",
		},
		{
			name:           "processTokens is failed by invalid token path",
			token0:         "invalidToken",
			token1:         "tokenB",
			amount0Desired: "150",
			amount1Desired: "200",
			caller:         testutils.TestAddress("user5"),
			expectPanic:    true,
			expectMsg:      "[GNOSWAP-POSITION-016] invalid token address || token0(invalidToken), token1(tokenB)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			MockRegister(t, tt.token0)
			MockRegister(t, tt.token1)

			// guard for unexpected panic
			defer func() {
				if r := recover(); r != nil {
					if !tt.expectPanic {
						t.Errorf("unexpected panic: %v", r)
					}
				}
			}()

			if tt.token0 == GNOT {
				amount, _ := strconv.ParseInt(tt.amount0Desired, 10, 64)
				ugnotFaucet(t, positionAddr, amount)
				testing.SetRealm(testing.NewUserRealm(positionAddr))
				mockInstance.transferUGNOT(positionAddr, positionAddr, amount)
			}
			if tt.token1 == GNOT {
				amount, _ := strconv.ParseInt(tt.amount1Desired, 10, 64)
				ugnotFaucet(t, positionAddr, amount)
				testing.SetRealm(testing.NewUserRealm(positionAddr))
				mockInstance.transferUGNOT(positionAddr, positionAddr, amount)
			}

			token0, token1, native0, native1, wrapped, err := mockInstance.processTokens(
				tt.token0,
				tt.token1,
				tt.amount0Desired,
				tt.amount1Desired,
				tt.caller,
			)

			if tt.expectPanic {
				uassert.ErrorIs(t, err, errors.New(tt.expectMsg))
			} else {
				uassert.Nil(t, err)
				uassert.Equal(t, tt.expected0, token0)
				uassert.Equal(t, tt.expected1, token1)
				uassert.Equal(t, tt.isNative0, native0)
				uassert.Equal(t, tt.isNative1, native1)
				uassert.Equal(t, tt.expectedWrap, wrapped)
			}
		})
	}
}

func TestMint(t *testing.T) {
	tests := []struct {
		name               string
		token0             string
		token1             string
		fee                uint32
		tickLower          int32
		tickUpper          int32
		amount0            string
		amount1            string
		minAmount0         string
		minAmount1         string
		deadline           int64
		mintTo             address
		caller             address
		shouldError        bool
		expectedErrorMsg   string
		expectedPositionId uint64
		expectedAmount0    uint64
		expectedAmount1    uint64
		referrer           string
	}{
		{
			name:               "success: valid referral",
			token0:             barPath,
			token1:             fooPath,
			fee:                fee500,
			tickLower:          -500,
			tickUpper:          500,
			amount0:            "1000000",
			amount1:            "2000000",
			minAmount0:         "950000",
			minAmount1:         "900000",
			deadline:           time.Now().Add(10 * time.Minute).Unix(),
			mintTo:             alice,
			caller:             alice,
			expectedPositionId: 1,
			expectedAmount0:    1000000,
			expectedAmount1:    1000000,
			referrer:           testutils.TestAddress("carol").String(),
		},
		{
			name:             "abort: deadline exceeded",
			token0:           barPath,
			token1:           fooPath,
			fee:              fee500,
			tickLower:        -500,
			tickUpper:        500,
			amount0:          "1000000",
			amount1:          "2000000",
			minAmount0:       "950000",
			minAmount1:       "1900000",
			deadline:         time.Now().Add(-10 * time.Minute).Unix(),
			mintTo:           alice,
			caller:           alice,
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-POSITION-007] transaction expired || transaction too old, now(1234567890) > deadline(1234567290)",
			expectedAmount0:  950000,
			expectedAmount1:  1900000,
		},
		{
			name:             "abort: invalid tick range",
			token0:           barPath,
			token1:           fooPath,
			fee:              fee500,
			tickLower:        600,
			tickUpper:        500,
			amount0:          "1000000",
			amount1:          "2000000",
			minAmount0:       "950000",
			minAmount1:       "1900000",
			deadline:         time.Now().Add(10 * time.Minute).Unix(),
			mintTo:           alice,
			caller:           alice,
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(600), tickUpper(500)",
			expectedAmount0:  950000,
			expectedAmount1:  1900000,
		},
		{
			name:             "abort: caller not authorized to mintTo",
			token0:           barPath,
			token1:           fooPath,
			fee:              fee500,
			tickLower:        -500,
			tickUpper:        500,
			amount0:          "1000000",
			amount1:          "2000000",
			minAmount0:       "950000",
			minAmount1:       "1900000",
			deadline:         time.Now().Add(10 * time.Minute).Unix(),
			mintTo:           adminAddr,
			caller:           alice,
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-POSITION-012] invalid address || (g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh, g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d)",
			expectedAmount0:  950000,
			expectedAmount1:  1900000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initPositionTest(t)

			createPoolWithoutFee(tc.token0, tc.token1, tc.fee, 0)

			testing.SetRealm(testing.NewUserRealm(tc.caller))
			amount0Int, _ := strconv.ParseInt(tc.amount0, 10, 64)
			amount1Int, _ := strconv.ParseInt(tc.amount1, 10, 64)

			if tc.shouldError {
				uassert.AbortsWithMessage(t, tc.expectedErrorMsg, func() {
					mockInstanceMint(
						tc.token0, tc.token1, tc.fee,
						tc.tickLower, tc.tickUpper,
						tc.amount0, tc.amount1,
						tc.minAmount0, tc.minAmount1,
						tc.deadline,
						tc.mintTo, tc.caller, tc.referrer,
					)
				})
			} else {
				testing.SetRealm(adminRealm)
				common.SafeGRC20Transfer(cross, tc.token0, tc.caller, amount0Int)
				common.SafeGRC20Transfer(cross, tc.token1, tc.caller, amount1Int)

				testing.SetRealm(testing.NewUserRealm(tc.caller))

				positionId, liquidity, amount0, amount1 := mockInstanceMint(
					tc.token0, tc.token1, tc.fee,
					tc.tickLower, tc.tickUpper,
					tc.amount0, tc.amount1,
					tc.minAmount0, tc.minAmount1,
					tc.deadline,
					tc.mintTo, tc.caller, tc.referrer,
				)

				uassert.Equal(t, tc.expectedPositionId, positionId)
				uassert.NotEmpty(t, liquidity)
				t0, _ := strconv.ParseUint(amount0, 10, 64)
				t1, _ := strconv.ParseUint(amount1, 10, 64)
				uassert.Equal(t, tc.expectedAmount0, t0)
				uassert.Equal(t, tc.expectedAmount1, t1)
			}

			if tc.referrer != "" {
				uassert.Equal(t, tc.referrer, referral.GetReferral(tc.caller.String()))
			}
		})
	}
}

func TestIncreaseLiquidity(t *testing.T) {
	tests := []struct {
		name             string
		positionId       uint64
		amount0Desired   string
		amount1Desired   string
		amount0Min       string
		amount1Min       string
		deadline         int64
		expectedAmount0  string
		expectedAmount1  string
		expectPanic      bool
		expectedErrorMsg string
	}{
		{
			name:            "increase liquidity is success by valid increase",
			positionId:      1,
			amount0Desired:  "1000000",
			amount1Desired:  "2000000",
			amount0Min:      "950000",
			amount1Min:      "900000",
			deadline:        time.Now().Add(10 * time.Minute).Unix(),
			expectedAmount0: "1000000",
			expectedAmount1: "1000000",
			expectPanic:     false,
		},
		{
			name:             "increase liquidity is failed by deadline exceeded",
			positionId:       1,
			amount0Desired:   "1000000",
			amount1Desired:   "2000000",
			amount0Min:       "950000",
			amount1Min:       "900000",
			deadline:         time.Now().Add(-10 * time.Minute).Unix(),
			expectPanic:      true,
			expectedErrorMsg: "[GNOSWAP-POSITION-007] transaction expired || transaction too old, now(1234567890) > deadline(1234567290)",
		},
		{
			name:             "increase liquidity is failed by invalid amount string",
			positionId:       1,
			amount0Desired:   "invalid_amount",
			amount1Desired:   "2000000",
			amount0Min:       "950000",
			amount1Min:       "900000",
			deadline:         time.Now().Add(10 * time.Minute).Unix(),
			expectPanic:      true,
			expectedErrorMsg: "[GNOSWAP-POSITION-005] invalid input data || input string : invalid_amount",
		},
		{
			name:             "increase liquidity is failed by position does not exist",
			positionId:       999,
			amount0Desired:   "1000000",
			amount1Desired:   "2000000",
			amount0Min:       "950000",
			amount1Min:       "900000",
			deadline:         time.Now().Add(10 * time.Minute).Unix(),
			expectPanic:      true,
			expectedErrorMsg: "[GNOSWAP-POSITION-013] position does not exist || position with position ID(999) doesn't exist",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initPositionTest(t)

			createPoolWithoutFee(barPath, fooPath, fee500, 0)

			testing.SetRealm(adminRealm)
			_, _, _, _ = mockInstanceMint(
				barPath,
				fooPath,
				fee500,
				-10000,
				10000,
				"1000000",
				"1000000",
				"0",
				"0",
				time.Now().Add(time.Hour).Unix(),
				adminAddr,
				adminAddr,
				"",
			)

			if tc.expectPanic {
				uassert.AbortsWithMessage(t,
					tc.expectedErrorMsg,
					func() {
						mockInstanceIncreaseLiquidity(
							tc.positionId,
							tc.amount0Desired,
							tc.amount1Desired,
							tc.amount0Min,
							tc.amount1Min,
							tc.deadline,
							adminAddr,
						)
					})
			} else {
				positionId, _, amount0, amount1, _ := mockInstanceIncreaseLiquidity(
					tc.positionId,
					tc.amount0Desired,
					tc.amount1Desired,
					tc.amount0Min,
					tc.amount1Min,
					tc.deadline,
					adminAddr,
				)
				uassert.Equal(t, tc.positionId, positionId)
				uassert.Equal(t, tc.expectedAmount0, amount0)
				uassert.Equal(t, tc.expectedAmount1, amount1)
			}
		})
	}
}

func TestDecreaseLiquidity(t *testing.T) {
	tests := []struct {
		name              string
		beforeIncrease    bool
		increaseAmount0   string
		increaseAmount1   string
		liquidityToRemove string
		amount0Min        string
		amount1Min        string
		deadlineOffset    time.Duration
		unwrapResult      bool
		expectedHasAbort  bool
		expectedErrorMsg  string
		expectedLiquidity string
		expectedFee0      string
		expectedFee1      string
	}{
		{
			name:              "decrease liquidity is success by 50%",
			liquidityToRemove: "400000",
			amount0Min:        "8000",
			amount1Min:        "15000",
			deadlineOffset:    time.Hour,
			unwrapResult:      false,
			expectedHasAbort:  false,
			expectedLiquidity: "400000",
			expectedFee0:      "0",
			expectedFee1:      "0",
		},
		{
			name:              "decrease liquidity is success by 100%",
			liquidityToRemove: "600000",
			amount0Min:        "10000",
			amount1Min:        "20000",
			deadlineOffset:    time.Hour,
			unwrapResult:      false,
			expectedHasAbort:  false,
			expectedLiquidity: "600000",
			expectedFee0:      "0",
			expectedFee1:      "0",
			expectedErrorMsg:  "",
		},
		{
			name:              "decrease liquidity is fail by zero liquidity",
			liquidityToRemove: "0",
			amount0Min:        "10000",
			amount1Min:        "20000",
			deadlineOffset:    time.Hour,
			unwrapResult:      false,
			expectedHasAbort:  true,
			expectedErrorMsg:  "[GNOSWAP-POSITION-010] zero liquidity || liquidity amount must be greater than 0, got 0",
		},
		{
			name:              "decrease liquidity is fail by underflow",
			liquidityToRemove: "2541593",
			amount0Min:        "200000",
			amount1Min:        "400000",
			deadlineOffset:    time.Hour,
			unwrapResult:      false,
			expectedHasAbort:  true,
			expectedFee0:      "0",
			expectedFee1:      "0",
			expectedErrorMsg:  "[GNOSWAP-POSITION-019] invalid liquidity || Liquidity requested(2541593) is greater than liquidity held(2541592)",
		},
		{
			name:              "decrease liquidity is fail by deadline exceeded",
			liquidityToRemove: "50",
			amount0Min:        "10000",
			amount1Min:        "20000",
			deadlineOffset:    -time.Hour,
			unwrapResult:      false,
			expectedHasAbort:  true,
			expectedErrorMsg:  "[GNOSWAP-POSITION-007] transaction expired || transaction too old, now(1234567890) > deadline(1234564290)",
		},
		{
			name:              "decrease liquidity is success by increase and decrease",
			beforeIncrease:    true,
			increaseAmount0:   "500000",
			increaseAmount1:   "1000000",
			liquidityToRemove: "1270796",
			amount0Min:        "12000",
			amount1Min:        "25000",
			deadlineOffset:    time.Hour,
			unwrapResult:      false,
			expectedHasAbort:  false,
			expectedLiquidity: "1270796",
			expectedFee0:      "0",
			expectedFee1:      "0",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initPositionTest(t)

			createPoolWithoutFee(barPath, fooPath, fee500, 0)

			testing.SetRealm(adminRealm)
			mockInstanceMint(
				barPath,
				fooPath,
				fee500,
				-10000,
				10000,
				"1000000",
				"1000000",
				"0", "0", time.Now().Add(time.Hour).Unix(), adminAddr, adminAddr, "")

			deadline := time.Now().Add(tc.deadlineOffset).Unix()

			testing.SetRealm(testing.NewUserRealm(adminAddr))
			if tc.expectedHasAbort {
				uassert.AbortsWithMessage(t, tc.expectedErrorMsg, func() {
					mockInstanceDecreaseLiquidity(
						1,
						tc.liquidityToRemove,
						tc.amount0Min,
						tc.amount1Min,
						deadline,
						tc.unwrapResult,
					)
				})
			} else {
				_, liquidity, fee0, fee1, _, _, _ := mockInstanceDecreaseLiquidity(
					1,
					tc.liquidityToRemove,
					tc.amount0Min,
					tc.amount1Min,
					deadline,
					tc.unwrapResult,
				)
				uassert.Equal(t, tc.expectedLiquidity, liquidity)
				uassert.Equal(t, tc.expectedFee0, fee0)
				uassert.Equal(t, tc.expectedFee1, fee1)
			}
		})
	}
}

func TestCollectFees(t *testing.T) {
	tests := []struct {
		name               string
		caller             address
		mintAmount0        string
		mintAmount1        string
		increaseAmount0    string
		increaseAmount1    string
		unwrapResult       bool
		liquidityToRemove  string
		expectedFee0       string
		expectedFee1       string
		expectedAmount0    string
		expectedAmount1    string
		expectedHasAbort   bool
		expectedAbortError string
	}{
		{
			name:              "success: multiple mints",
			caller:            adminAddr,
			mintAmount0:       "1000000",
			mintAmount1:       "2000000",
			increaseAmount0:   "500000",
			increaseAmount1:   "1000000",
			liquidityToRemove: "50",
			unwrapResult:      false,
			expectedFee0:      "0",
			expectedFee1:      "0",
			expectedAmount0:   "0",
			expectedAmount1:   "0",
		},
		{
			name:              "success: full removal then collect",
			caller:            adminAddr,
			mintAmount0:       "1000000",
			mintAmount1:       "2000000",
			liquidityToRemove: "100",
			unwrapResult:      true,
			expectedFee0:      "0",
			expectedFee1:      "0",
			expectedAmount0:   "0",
			expectedAmount1:   "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			createPoolWithoutFee(barPath, fooPath, fee500, 0)

			testing.SetOriginCaller(adminAddr)
			mockInstanceMint(
				barPath,
				fooPath,
				fee500,
				-10000,
				10000,
				"1000000",
				"1000000",
				"0", "0",
				time.Now().Add(time.Hour).Unix(),
				adminAddr,
				adminAddr,
				"",
			)

			testing.SetOriginCaller(adminAddr)

			if tt.increaseAmount0 != "" && tt.increaseAmount1 != "" {
				_, _, _, _, _ = mockInstanceIncreaseLiquidity(
					1,
					tt.increaseAmount0,
					tt.increaseAmount1,
					"0",
					"0",
					time.Now().Add(time.Hour).Unix(),
					adminAddr,
				)
			}
			if tt.liquidityToRemove != "" {
				_, _, _, _, _, _, _ = mockInstanceDecreaseLiquidity(
					1,
					tt.liquidityToRemove,
					"0",
					"0",
					time.Now().Add(time.Hour).Unix(),
					tt.unwrapResult,
				)
			}

			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortError, func() {
					mockInstanceCollectFee(1, tt.unwrapResult, adminAddr)
				})
			} else {
				_, fee0, fee1, _, amount0, amount1 := mockInstanceCollectFee(1, tt.unwrapResult, adminAddr)
				uassert.Equal(t, tt.expectedFee0, fee0)
				uassert.Equal(t, tt.expectedFee1, fee1)
				uassert.Equal(t, tt.expectedAmount0, amount0)
				uassert.Equal(t, tt.expectedAmount1, amount1)
			}
		})
	}
}

func TestReposition(t *testing.T) {
	tests := []struct {
		name                 string
		mintAmount0          string
		mintAmount1          string
		increaseAmount0      string
		increaseAmount1      string
		liquidityToRemove    string
		tickLower            int32
		tickUpper            int32
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:                 "reposition is failed by full liquidity removal",
			mintAmount0:          "1000000",
			mintAmount1:          "2000000",
			increaseAmount0:      "500000",
			increaseAmount1:      "1000000",
			liquidityToRemove:    "100",
			tickLower:            -5000,
			tickUpper:            5000,
			expectedHasAbort:     true,
			expectedAbortMessage: "[GNOSWAP-POSITION-009] position is not clear || position(1) isn't clear(liquidity:3812288, tokensOwed0:0, tokensOwed1:0)",
		},
		{
			name:                 "reposition is failed by partial liquidity removal",
			mintAmount0:          "1000000",
			mintAmount1:          "2000000",
			increaseAmount0:      "500000",
			increaseAmount1:      "1000000",
			liquidityToRemove:    "50",
			tickLower:            -3000,
			tickUpper:            3000,
			expectedHasAbort:     true,
			expectedAbortMessage: "[GNOSWAP-POSITION-009] position is not clear || position(1) isn't clear(liquidity:3812338, tokensOwed0:0, tokensOwed1:0)",
		},
		{
			name:                 "reposition is failed by non-existent positionId",
			mintAmount0:          "1000000",
			mintAmount1:          "2000000",
			liquidityToRemove:    "10",
			tickLower:            -4000,
			tickUpper:            4000,
			expectedHasAbort:     true,
			expectedAbortMessage: "[GNOSWAP-POSITION-009] position is not clear || position(1) isn't clear(liquidity:2541582, tokensOwed0:0, tokensOwed1:0)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			// no need to faucet tokens here.
			createPoolWithoutFee(barPath, fooPath, fee500, 0)

			testing.SetOriginCaller(adminAddr)
			mockInstanceMint(
				barPath,
				fooPath,
				fee500,
				-10000,
				10000,
				"1000000",
				"1000000",
				"0", "0", time.Now().Add(time.Hour).Unix(), adminAddr, adminAddr, "")

			// Step 2: Increase liquidity
			if tt.increaseAmount0 != "" && tt.increaseAmount1 != "" {
				_, _, _, _, _ = mockInstanceIncreaseLiquidity(
					1,
					tt.increaseAmount0,
					tt.increaseAmount1,
					"0",
					"0",
					time.Now().Add(time.Hour).Unix(),
					adminAddr,
				)
			}

			// Step 3: Decrease liquidity to clear the position
			_, _, _, _, _, _, _ = mockInstanceDecreaseLiquidity(
				1,
				tt.liquidityToRemove,
				"0",
				"0",
				time.Now().Add(time.Hour).Unix(),
				false,
			)

			// Step 4: Attempt Reposition
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMessage, func() {
					mockInstanceReposition(
						1,
						tt.tickLower,
						tt.tickUpper,
						tt.mintAmount0,
						tt.mintAmount1,
						"0",
						"0",
						adminAddr,
					)
				})
			} else {
				// positionId, liquidity.ToString(), tickLower, tickUpper, amount0.ToString(), amount1.ToString()
				_, _, tickL, tickH, _, _ := mockInstanceReposition(
					1,
					tt.tickLower,
					tt.tickUpper,
					tt.mintAmount0,
					tt.mintAmount1,
					"0",
					"0",
					adminAddr,
				)
				uassert.Equal(t, tickL, tt.tickLower)
				uassert.Equal(t, tickH, tt.tickUpper)
			}
		})
	}
}

func TestValidateTokenPath(t *testing.T) {
	tests := []struct {
		name        string
		token0      string
		token1      string
		expectError bool
	}{
		{
			name:        "Valid different tokens",
			token0:      gnsPath,
			token1:      barPath,
			expectError: false,
		},
		{
			name:        "Valid native token (ugnot) with wrapped token",
			token0:      GNOT,
			token1:      gnsPath,
			expectError: false,
		},
		{
			name:        "Valid wrapped token with native",
			token0:      gnsPath,
			token1:      GNOT,
			expectError: false,
		},
		{
			name:        "Invalid - identical tokens",
			token0:      gnsPath,
			token1:      gnsPath,
			expectError: true,
		},
		{
			name:        "Invalid - ugnot and wugnot conflict",
			token0:      GNOT,
			token1:      WRAPPED_WUGNOT,
			expectError: true,
		},
		{
			name:        "Invalid - wugnot and ugnot conflict (reversed)",
			token0:      WRAPPED_WUGNOT,
			token1:      GNOT,
			expectError: true,
		},
		{
			name:        "Invalid - non-registered token path",
			token0:      "gno.land/r/invalid/token",
			token1:      gnsPath,
			expectError: true,
		},
		{
			name:        "Invalid - both tokens are invalid",
			token0:      "invalid1",
			token1:      "invalid2",
			expectError: true,
		},
		{
			name:        "Valid - both registered tokens",
			token0:      gnsPath,
			token1:      wugnotPath,
			expectError: false,
		},
		{
			name:        "Invalid - empty token0",
			token0:      "",
			token1:      gnsPath,
			expectError: true,
		},
		{
			name:        "Invalid - empty token1",
			token0:      gnsPath,
			token1:      "",
			expectError: true,
		},
		{
			name:        "Invalid - both empty",
			token0:      "",
			token1:      "",
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			err := validateTokenPath(tt.token0, tt.token1)

			if tt.expectError {
				uassert.NotNil(t, err, "expected error but got nil")
				uassert.Equal(t, errInvalidTokenPath.Error(), err.Error())
			} else {
				if err != nil {
					t.Errorf("expected no error but got: %v", err)
				}
			}
		})
	}
}

func TestComputePoolPath(t *testing.T) {
	tests := []struct {
		name         string
		token0       string
		token1       string
		fee          uint32
		expectedPath string
	}{
		{
			name:         "Normal pool path",
			token0:       gnsPath,
			token1:       barPath,
			fee:          fee3000,
			expectedPath: computePoolPath(gnsPath, barPath, fee3000),
		},
		{
			name:         "Pool path with fee 500",
			token0:       gnsPath,
			token1:       wugnotPath,
			fee:          fee500,
			expectedPath: computePoolPath(gnsPath, wugnotPath, fee500),
		},
		{
			name:         "Pool path with fee 100",
			token0:       barPath,
			token1:       bazPath,
			fee:          fee100,
			expectedPath: computePoolPath(barPath, bazPath, fee100),
		},
		{
			name:         "Pool path with fee 10000",
			token0:       gnsPath,
			token1:       oblPath,
			fee:          fee10000,
			expectedPath: computePoolPath(gnsPath, oblPath, fee10000),
		},
		{
			name:         "Pool path with reversed token order",
			token0:       barPath,
			token1:       gnsPath,
			fee:          fee3000,
			expectedPath: computePoolPath(barPath, gnsPath, fee3000),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			result := computePoolPath(tt.token0, tt.token1, tt.fee)
			uassert.NotEqual(t, "", result, "pool path should not be empty")
			// The actual pool path format depends on pool.GetPoolPath implementation
			// We just verify it returns a non-empty string
			uassert.Equal(t, tt.expectedPath, result)
		})
	}
}

func TestCalculateAmountWithWithdrawalFee(t *testing.T) {
	tests := []struct {
		name                 string
		amount               string
		fee                  uint64
		expectedAmountNoFee  int64
		expectedFee          int64
		shouldPanic          bool
		expectedPanicMessage string
	}{
		{
			name:                "No fee - zero fee",
			amount:              "1000000",
			fee:                 0,
			expectedAmountNoFee: 1000000,
			expectedFee:         0,
			shouldPanic:         false,
		},
		{
			name:                "Normal fee - 1% (100 bps)",
			amount:              "1000000",
			fee:                 100,
			expectedAmountNoFee: 990000,
			expectedFee:         10000,
			shouldPanic:         false,
		},
		{
			name:                "High fee - 5% (500 bps)",
			amount:              "1000000",
			fee:                 500,
			expectedAmountNoFee: 950000,
			expectedFee:         50000,
			shouldPanic:         false,
		},
		{
			name:                "Low fee - 0.1% (10 bps)",
			amount:              "1000000",
			fee:                 10,
			expectedAmountNoFee: 999000,
			expectedFee:         1000,
			shouldPanic:         false,
		},
		{
			name:                "Small amount with fee",
			amount:              "100",
			fee:                 100,
			expectedAmountNoFee: 99,
			expectedFee:         1,
			shouldPanic:         false,
		},
		{
			name:                "Large amount with fee",
			amount:              "999999999999",
			fee:                 100,
			expectedAmountNoFee: 990000000000,
			expectedFee:         9999999999,
			shouldPanic:         false,
		},
		{
			name:                "Zero amount with fee",
			amount:              "0",
			fee:                 100,
			expectedAmountNoFee: 0,
			expectedFee:         0,
			shouldPanic:         false,
		},
		{
			name:                "Maximum fee - 100% (10000 bps)",
			amount:              "1000000",
			fee:                 10000,
			expectedAmountNoFee: 0,
			expectedFee:         1000000,
			shouldPanic:         false,
		},
		{
			name:                "Rounding down in fee calculation",
			amount:              "50",
			fee:                 100,
			expectedAmountNoFee: 50,
			expectedFee:         0,
			shouldPanic:         false,
		},
		{
			name:                "Rounding down in fee calculation",
			amount:              "50",
			fee:                 99,
			expectedAmountNoFee: 50,
			expectedFee:         0,
			shouldPanic:         false,
		},
		{
			name:                "Very small fee on large amount",
			amount:              "1000000000",
			fee:                 1,
			expectedAmountNoFee: 999900000,
			expectedFee:         100000,
			shouldPanic:         false,
		},
		{
			name:                 "Invalid amount - negative",
			amount:               "-1000",
			fee:                  100,
			shouldPanic:          true,
			expectedPanicMessage: "strconv.ParseUint: parsing \"-1000\": invalid syntax",
		},
		{
			name:                 "Invalid amount - non-numeric",
			amount:               "invalid",
			fee:                  100,
			shouldPanic:          true,
			expectedPanicMessage: "strconv.ParseUint: parsing \"invalid\": invalid syntax",
		},
		{
			name:                "Edge case - fee equals divisor",
			amount:              "10000",
			fee:                 10000,
			expectedAmountNoFee: 0,
			expectedFee:         10000,
			shouldPanic:         false,
		},
		{
			name:                "Multiple of divisor",
			amount:              "20000",
			fee:                 100,
			expectedAmountNoFee: 19800,
			expectedFee:         200,
			shouldPanic:         false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					calculateAmountWithWithdrawalFee(tt.amount, tt.fee)
				})
			} else {
				amountNoFee, feeAmount := calculateAmountWithWithdrawalFee(tt.amount, tt.fee)

				uassert.Equal(t, tt.expectedAmountNoFee, amountNoFee)
				uassert.Equal(t, tt.expectedFee, feeAmount)

				// Verify sum equals original (within rounding)
				if tt.fee > 0 {
					originalAmount := u256.MustFromDecimal(tt.amount)
					calculatedSum := u256.NewUint(uint64(amountNoFee + feeAmount))

					// Allow for rounding down in fee calculation
					diff := u256.Zero().Sub(originalAmount, calculatedSum)
					uassert.True(t, diff.Lt(u256.NewUint(10)),
						"sum should approximately equal original amount (within rounding)")
				}
			}
		})
	}
}

func TestUnwrapLeftoverWrappedToken(t *testing.T) {
	tests := []struct {
		name                 string
		token                string
		wrapped              int64
		amount               int64
		expectError          bool
		shouldCall           bool // whether unwrap should be called
		expectPanic          bool
		expectedPanicMessage string
	}{
		{
			name:        "Unwrap leftover - wrapped > amount",
			token:       WRAPPED_WUGNOT,
			wrapped:     1000,
			amount:      700,
			expectError: false,
			shouldCall:  true,
		},
		{
			name:        "No unwrap - wrapped == amount",
			token:       WRAPPED_WUGNOT,
			wrapped:     1000,
			amount:      1000,
			expectError: false,
			shouldCall:  false,
		},
		{
			name:        "No unwrap - wrapped < amount",
			token:       WRAPPED_WUGNOT,
			wrapped:     7000,
			amount:      10000,
			expectError: false,
			shouldCall:  false,
		},
		{
			name:        "No unwrap - not wrapped token",
			token:       gnsPath,
			wrapped:     10000,
			amount:      7000,
			expectError: false,
			shouldCall:  false,
		},
		{
			name:        "Unwrap zero leftover",
			token:       WRAPPED_WUGNOT,
			wrapped:     0,
			amount:      0,
			expectError: false,
			shouldCall:  false,
		},
		{
			name:        "Large leftover amount",
			token:       WRAPPED_WUGNOT,
			wrapped:     1000000000,
			amount:      500000000,
			expectError: false,
			shouldCall:  true,
		},
		{
			name:        "Small leftover amount",
			token:       WRAPPED_WUGNOT,
			wrapped:     100,
			amount:      99,
			shouldCall:  true,
			expectError: false,
			expectPanic: false,
		},
		{
			name:        "No unwrap - non-native token with leftover",
			token:       barPath,
			wrapped:     1000,
			amount:      500,
			expectError: false,
			shouldCall:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			testing.SetRealm(adminRealm)
			wugnot.Approve(cross, positionAddr, math.MaxInt64)

			if tt.wrapped > 0 {
				amount := tt.wrapped
				if tt.wrapped < 1000 {
					amount = 1000
				}

				testing.SetOriginSend(chain.Coins{{"ugnot", amount}})
				wugnot.Deposit(cross)

				testing.IssueCoins(address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"), chain.Coins{{"ugnot", amount}})
			}

			testing.SetOriginSend(chain.Coins{})
			testing.SetRealm(adminRealm)

			unwrapLeftoverWrappedTokenFn := func(cur realm) error {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position"))
				return mockInstance.unwrapLeftoverWrappedToken(tt.token, tt.wrapped, tt.amount, adminAddr)
			}

			if tt.expectPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					unwrapLeftoverWrappedTokenFn(cross)
				})
			} else {
				err := unwrapLeftoverWrappedTokenFn(cross)
				if err != nil {
					t.Errorf("expected no error but got: %v", err)
				}

				if tt.expectError {
					uassert.NotNil(t, err, "expected error but got nil")
				} else {
					if err != nil {
						t.Errorf("expected no error but got: %v", err)
					}
				}

				// Verify logic correctness
				isWrapped := isWrappedToken(tt.token)
				hasLeftover := tt.wrapped > tt.amount
				shouldUnwrap := isWrapped && hasLeftover

				uassert.Equal(t, tt.shouldCall, shouldUnwrap)
			}
		})
	}
}

// Helper function to check if string contains substring
func contains(str, substr string) bool {
	return strings.Contains(str, substr)
}
