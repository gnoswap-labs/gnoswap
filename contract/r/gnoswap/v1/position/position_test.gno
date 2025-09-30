package position

import (
	"errors"
	"strconv"
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/referral"
	"gno.land/r/gnoswap/v1/gnft"
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
	positionId, _, _, _ := Mint(
		cross,
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

func newDummyPosition(id uint64) Position {
	return Position{
		operator:                 "user1",
		poolKey:                  "poolKey1",
		tickLower:                -500,
		tickUpper:                500,
		liquidity:                u256.NewUint(1000),
		feeGrowthInside0LastX128: u256.NewUint(10),
		feeGrowthInside1LastX128: u256.NewUint(20),
		tokensOwed0:              u256.NewUint(30),
		tokensOwed1:              u256.NewUint(40),
		burned:                   false,
	}
}

func TestMustGetPosition(t *testing.T) {
	tests := []struct {
		name                 string
		positionId           uint64
		inputPosition        Position
		inputPositionId      uint64
		expectedPosition     Position
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
			expectedPosition:     Position{},
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-POSITION-013] position does not exist || position with position ID(999) doesn't exist",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)
			createNewPosition(tt.positionId, tt.inputPosition)

			if tt.expectedHasPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					MustGetPosition(tt.inputPositionId)
				})
			} else {
				result := MustGetPosition(tt.inputPositionId)
				uassert.Equal(t, tt.expectedPosition.operator, result.operator)
				uassert.Equal(t, tt.expectedPosition.poolKey, result.poolKey)
				uassert.Equal(t, tt.expectedPosition.tickLower, result.tickLower)
				uassert.Equal(t, tt.expectedPosition.tickUpper, result.tickUpper)
				uassert.Equal(t, tt.expectedPosition.liquidity.ToString(), result.liquidity.ToString())
				uassert.Equal(t, tt.expectedPosition.feeGrowthInside0LastX128.ToString(), result.feeGrowthInside0LastX128.ToString())
				uassert.Equal(t, tt.expectedPosition.feeGrowthInside1LastX128.ToString(), result.feeGrowthInside1LastX128.ToString())
				uassert.Equal(t, tt.expectedPosition.tokensOwed0.ToString(), result.tokensOwed0.ToString())
				uassert.Equal(t, tt.expectedPosition.tokensOwed1.ToString(), result.tokensOwed1.ToString())
				uassert.Equal(t, tt.expectedPosition.burned, result.burned)
			}
		})
	}
}

func TestSetPosition(t *testing.T) {
	position := newDummyPosition(1)
	changedPosition := newDummyPosition(1)
	changedPosition.operator = "user2"
	changedPosition.poolKey = "poolKey2"
	changedPosition.tickLower = -2000
	changedPosition.tickUpper = 2000
	changedPosition.liquidity = u256.NewUint(2000)
	changedPosition.feeGrowthInside0LastX128 = u256.NewUint(20)
	changedPosition.feeGrowthInside1LastX128 = u256.NewUint(40)
	changedPosition.tokensOwed0 = u256.NewUint(60)
	changedPosition.tokensOwed1 = u256.NewUint(80)
	changedPosition.burned = true

	tests := []struct {
		name          string
		positionId    uint64
		position      Position
		inputPosition Position
		expected      bool
	}{
		{
			name:          "set position is success by existing position",
			positionId:    1,
			position:      position,
			inputPosition: changedPosition,
			expected:      false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)
			createNewPosition(tt.positionId, tt.position)

			setPosition(tt.positionId, tt.inputPosition)

			storedPosition, _ := GetPosition(tt.positionId)
			uassert.Equal(t, tt.inputPosition.operator, storedPosition.operator)
			uassert.Equal(t, tt.inputPosition.poolKey, storedPosition.poolKey)
			uassert.Equal(t, tt.inputPosition.tickLower, storedPosition.tickLower)
			uassert.Equal(t, tt.inputPosition.tickUpper, storedPosition.tickUpper)
			uassert.Equal(t, tt.inputPosition.liquidity.ToString(), storedPosition.liquidity.ToString())
			uassert.Equal(t, tt.inputPosition.feeGrowthInside0LastX128.ToString(), storedPosition.feeGrowthInside0LastX128.ToString())
			uassert.Equal(t, tt.inputPosition.feeGrowthInside1LastX128.ToString(), storedPosition.feeGrowthInside1LastX128.ToString())
			uassert.Equal(t, tt.inputPosition.tokensOwed0.ToString(), storedPosition.tokensOwed0.ToString())
			uassert.Equal(t, tt.inputPosition.tokensOwed1.ToString(), storedPosition.tokensOwed1.ToString())
			uassert.Equal(t, tt.inputPosition.burned, storedPosition.burned)
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
			createNewPosition(tt.positionId, newDummyPosition(tt.positionId))

			removePosition(tt.inputPositionId)

			_, found := GetPosition(tt.inputPositionId)
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
			createNewPosition(tt.positionId, newDummyPosition(tt.positionId))
			uassert.Equal(t, tt.expectedExist, ExistPosition(tt.inputPositionId))
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
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3YxL3Bvc2l0aW9uX18tMTAwX18yMDA=", // Base64 of "gno.land/r/gnoswap/v1/position__-100__200"
		},
		{
			name:      "computePositionKey is failed by zero ticks",
			owner:     alice,
			tickLower: 0,
			tickUpper: 0,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3YxL3Bvc2l0aW9uX18wX18w", // Base64 of "gno.land/r/gnoswap/v1/position__0__0"
		},
		{
			name:      "computePositionKey is failed by negative lower tick",
			owner:     alice,
			tickLower: -50,
			tickUpper: 150,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3YxL3Bvc2l0aW9uX18tNTBfXzE1MA==", // Base64 of "gno.land/r/gnoswap/v1/position__-50__150"
		},
		{
			name:      "computePositionKey is failed by same tick bounds",
			owner:     alice,
			tickLower: 300,
			tickUpper: 300,
			expected:  "Z25vLmxhbmQvci9nbm9zd2FwL3YxL3Bvc2l0aW9uX18zMDBfXzMwMA==", // Base64 of "gno.land/r/gnoswap/v1/position__300__300"
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := computePositionKey(tt.tickLower, tt.tickUpper)

			if result != tt.expected {
				t.Errorf("expected %s but got %s", tt.expected, result)
			}
		})
	}
}

func TestNextIdFunctions(t *testing.T) {
	prevNextId := GetNextId()
	nextId = uint64(1)

	tests := []struct {
		name          string
		initialValue  uint64
		increments    int
		expectedValue uint64
	}{
		{"initial is 1", 1, 0, 1},
		{"after 1 increment is 2", 1, 1, 2},
		{"increment once → 3", 2, 1, 3},
		{"increment twice → 5", 3, 2, 5},
		{"no overflow on 95 increments", 5, 95, 100},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			nextId = tt.initialValue
			for range make([]struct{}, tt.increments) {
				incrementNextId()
			}
			uassert.Equal(t, tt.expectedValue, GetNextId())
		})
	}
	nextId = prevNextId
}

func TestIsValidTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
		register  bool
		expected  bool
	}{
		{"valid path", gnsPath, true, true},
		{"invalid path", "invalid/path", false, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isValidTokenPath(tt.tokenPath)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestValidateTokenPath(t *testing.T) {
	initPositionTest(t)

	tests := []struct {
		name      string
		token0    string
		token1    string
		register0 bool
		register1 bool
		expected  error
	}{
		{"both valid", gnsPath, barPath, true, true, nil},
		{"same token path", "tokenA", "tokenA", true, true, errInvalidTokenPath},
		{"conflicting tokens (GNOT ↔ WUGNOT)", GNOT, WRAPPED_WUGNOT, true, true, errInvalidTokenPath},
		{"invalid token0", "tokenX", "tokenY", false, true, errInvalidTokenPath},
		{"both invalid", "invalidA", "invalidB", false, false, errInvalidTokenPath},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.register0 {
				MockRegister(t, tt.token0)
			} else {
				MockUnregister(t, tt.token0)
			}
			if tt.register1 {
				MockRegister(t, tt.token1)
			} else {
				MockUnregister(t, tt.token1)
			}

			err := validateTokenPath(tt.token0, tt.token1)
			if tt.expected != nil {
				uassert.Equal(t, tt.expected.Error(), err.Error())
			} else {
				uassert.Nil(t, err)
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
			expectMsg:      "[GNOSWAP-POSITION-016] invalid token address || token0(gnot), token1(gno.land/r/gnoswap/gns)",
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
			expectMsg:      "[GNOSWAP-POSITION-016] invalid token address || token0(gnot), token1(gnot)",
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
				transferUGNOT(positionAddr, positionAddr, amount)
			}
			if tt.token1 == GNOT {
				amount, _ := strconv.ParseInt(tt.amount1Desired, 10, 64)
				ugnotFaucet(t, positionAddr, amount)
				testing.SetRealm(testing.NewUserRealm(positionAddr))
				transferUGNOT(positionAddr, positionAddr, amount)
			}

			token0, token1, native0, native1, wrapped, err := processTokens(
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
			NewEnv(t).
				GivenPoolCreated(barPath, fooPath, fee500, "79228162514264337593543950336").
				AndUserFundedAndApproved(alice, barPath, fooPath)

			testing.SetRealm(testing.NewUserRealm(tc.caller))

			if tc.shouldError {
				uassert.AbortsWithMessage(t, tc.expectedErrorMsg, func() {
					Mint(
						cross,
						tc.token0, tc.token1, tc.fee,
						tc.tickLower, tc.tickUpper,
						tc.amount0, tc.amount1,
						tc.minAmount0, tc.minAmount1,
						tc.deadline,
						tc.mintTo, tc.caller, tc.referrer,
					)
				})
			} else {
				positionId, liquidity, amount0, amount1 := Mint(
					cross,
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

			testing.SetRealm(adminRealm)
			setupPoolAndApprovals(t, true)
			_, _, _, _ = Mint(
				cross,
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
						IncreaseLiquidity(
							cross,
							tc.positionId,
							tc.amount0Desired,
							tc.amount1Desired,
							tc.amount0Min,
							tc.amount1Min,
							tc.deadline,
						)
					})
			} else {
				positionId, _, amount0, amount1, _ := IncreaseLiquidity(
					cross,
					tc.positionId,
					tc.amount0Desired,
					tc.amount1Desired,
					tc.amount0Min,
					tc.amount1Min,
					tc.deadline,
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

			testing.SetRealm(adminRealm)
			setupPoolAndApprovals(t, true)

			positionId := seedPosition(t, "1000000", "1000000")
			gnft.Approve(cross, posRealm.Address(), positionIdFrom(positionId))

			deadline := time.Now().Add(tc.deadlineOffset).Unix()
			if tc.beforeIncrease {
				_, _, _, _, _ = IncreaseLiquidity(
					cross,
					positionId,
					tc.increaseAmount0,
					tc.increaseAmount1,
					"0",
					"0",
					deadline,
				)
			}

			if tc.expectedHasAbort {
				uassert.AbortsWithMessage(t, tc.expectedErrorMsg, func() {
					DecreaseLiquidity(
						cross,
						positionId,
						tc.liquidityToRemove,
						tc.amount0Min,
						tc.amount1Min,
						deadline,
						tc.unwrapResult,
					)
				})
			} else {
				_, liquidity, fee0, fee1, _, _, _ := DecreaseLiquidity(
					cross,
					positionId,
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
			setupPoolAndApprovals(t, false)

			testing.SetOriginCaller(adminAddr)
			positionId := seedPosition(t, tt.mintAmount0, tt.mintAmount1)

			testing.SetOriginCaller(adminAddr)
			gnft.Approve(cross, posRealm.Address(), positionIdFrom(positionId))

			if tt.increaseAmount0 != "" && tt.increaseAmount1 != "" {
				_, _, _, _, _ = IncreaseLiquidity(
					cross,
					positionId,
					tt.increaseAmount0,
					tt.increaseAmount1,
					"0",
					"0",
					time.Now().Add(time.Hour).Unix(),
				)
			}
			if tt.liquidityToRemove != "" {
				_, _, _, _, _, _, _ = DecreaseLiquidity(
					cross,
					positionId,
					tt.liquidityToRemove,
					"0",
					"0",
					time.Now().Add(time.Hour).Unix(),
					tt.unwrapResult,
				)
			}

			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortError, func() {
					CollectFee(cross, positionId, tt.unwrapResult)
				})
			} else {
				_, fee0, fee1, _, amount0, amount1 := CollectFee(cross, positionId, tt.unwrapResult)
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
			setupPoolAndApprovals(t, false)

			testing.SetOriginCaller(adminAddr)
			positionId := seedPosition(t, "1000000", "1000000")
			gnft.Approve(cross, posRealm.Address(), positionIdFrom(positionId))

			// Step 2: Increase liquidity
			if tt.increaseAmount0 != "" && tt.increaseAmount1 != "" {
				_, _, _, _, _ = IncreaseLiquidity(
					cross,
					positionId,
					tt.increaseAmount0,
					tt.increaseAmount1,
					"0",
					"0",
					time.Now().Add(time.Hour).Unix(),
				)
			}

			// Step 3: Decrease liquidity to clear the position
			_, _, _, _, _, _, _ = DecreaseLiquidity(
				cross,
				positionId,
				tt.liquidityToRemove,
				"0",
				"0",
				time.Now().Add(time.Hour).Unix(),
				false,
			)

			// Step 4: Attempt Reposition
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMessage, func() {
					Reposition(
						cross,
						positionId,
						tt.tickLower,
						tt.tickUpper,
						tt.mintAmount0,
						tt.mintAmount1,
						"0",
						"0",
					)
				})
			} else {
				// positionId, liquidity.ToString(), tickLower, tickUpper, amount0.ToString(), amount1.ToString()
				tid, _, tickL, tickH, _, _ := Reposition(
					cross,
					positionId,
					tt.tickLower,
					tt.tickUpper,
					tt.mintAmount0,
					tt.mintAmount1,
					"0",
					"0",
				)
				uassert.Equal(t, tid, positionId)
				uassert.Equal(t, tickL, tt.tickLower)
				uassert.Equal(t, tickH, tt.tickUpper)
			}
		})
	}
}
