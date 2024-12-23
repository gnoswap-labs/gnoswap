package position

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/demo/users"
	"gno.land/r/gnoswap/v1/consts"
)

var (
	mockRegistry = make(map[string]bool)
)

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

func TestMustGetPosition(t *testing.T) {
	t.Skip("TODO: Implement")
}

func TestGetPosition(t *testing.T) {
	t.Skip("TODO: Implement")
}

func TestSetPosition(t *testing.T) {
	t.Skip("TODO: Implement")
}

func TestRemovePosition(t *testing.T) {
	t.Skip("TODO: Implement")
}

func TestExistPosition(t *testing.T) {
	t.Skip("TODO: Implement")
}

func TestComputePositionKey(t *testing.T) {
	tests := []struct {
		name      string
		owner     std.Address
		tickLower int32
		tickUpper int32
		expected  string
	}{
		{
			name:      "Basic Position Key",
			owner:     users.Resolve(alice),
			tickLower: -100,
			tickUpper: 200,
			expected:  "ZzF2OWt4amNtOXRhMDQ3aDZsdGEwNDdoNmx0YTA0N2g2bHpkNDBnaF9fLTEwMF9fMjAw", // Base64 of "g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh__-100__200"
		},
		{
			name:      "Zero Ticks",
			owner:     users.Resolve(alice),
			tickLower: 0,
			tickUpper: 0,
			expected:  "ZzF2OWt4amNtOXRhMDQ3aDZsdGEwNDdoNmx0YTA0N2g2bHpkNDBnaF9fMF9fMA==", // Base64 of "g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh__0__0"
		},
		{
			name:      "Negative Lower Tick",
			owner:     users.Resolve(alice),
			tickLower: -50,
			tickUpper: 150,
			expected:  "ZzF2OWt4amNtOXRhMDQ3aDZsdGEwNDdoNmx0YTA0N2g2bHpkNDBnaF9fLTUwX18xNTA=", // Base64 of "g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh__-50__150"
		},
		{
			name:      "Same Tick Bounds",
			owner:     users.Resolve(alice),
			tickLower: 300,
			tickUpper: 300,
			expected:  "ZzF2OWt4amNtOXRhMDQ3aDZsdGEwNDdoNmx0YTA0N2g2bHpkNDBnaF9fMzAwX18zMDA=", // Base64 of "g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh__300__300"
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := computePositionKey(tt.owner, tt.tickLower, tt.tickUpper)

			if result != tt.expected {
				t.Errorf("expected %s but got %s", tt.expected, result)
			}
		})
	}
}

func TestNextIdFunctions(t *testing.T) {
	nextId = uint64(1)
	t.Run("Initial nextId should return 1", func(t *testing.T) {
		uassert.Equal(t, uint64(1), getNextId(), "expected nextId to start at 1")
	})

	t.Run("After mint nextId should return 2", func(t *testing.T) {
		MakeMintPositionWithoutFee(t)
		uassert.Equal(t, uint64(2), getNextId(), "expected nextId to be 2 after mint")
	})

	t.Run("Increment nextId once", func(t *testing.T) {
		incrementNextId()
		uassert.Equal(t, uint64(3), getNextId(), "expected nextId to increment to 2")
	})

	t.Run("Increment nextId multiple times", func(t *testing.T) {
		for i := 0; i < 2; i++ {
			incrementNextId()
		}
		uassert.Equal(t, uint64(5), getNextId(), "expected nextId to increment to 5 after 3 more increments")
	})

	t.Run("Ensure no overflow on normal increments", func(t *testing.T) {
		for i := uint64(5); i < 100; i++ {
			incrementNextId()
		}
		uassert.Equal(t, uint64(100), getNextId(), "expected nextId to reach 100 after continuous increments")
	})
}

func TestIsValidTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
		register  bool
		expected  bool
	}{
		{
			name:      "Valid Token Path",
			tokenPath: gnsPath,
			register:  true,
			expected:  true,
		},
		{
			name:      "Invalid Token Path",
			tokenPath: "invalid/path",
			register:  false,
			expected:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isValidTokenPath(tt.tokenPath)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestValidateTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		token0    string
		token1    string
		register0 bool
		register1 bool
		expected  error
	}{
		{
			name:      "Valid Token Path",
			token0:    gnsPath,
			token1:    barPath,
			register0: true,
			register1: true,
			expected:  nil,
		},
		{
			name:      "Same Token Path",
			token0:    "tokenA",
			token1:    "tokenA",
			register0: true,
			register1: true,
			expected:  errInvalidTokenPath,
		},
		{
			name:      "Conflicting Tokens (GNOT ↔ WUGNOT)",
			token0:    consts.GNOT,
			token1:    consts.WRAPPED_WUGNOT,
			register0: true,
			register1: true,
			expected:  errInvalidTokenPath,
		},
		{
			name:      "Invalid Token Path",
			token0:    "tokenX",
			token1:    "tokenY",
			register0: false,
			register1: true,
			expected:  errInvalidTokenPath,
		},
		{
			name:      "Both Invalid Tokens",
			token0:    "invalidA",
			token1:    "invalidB",
			register0: false,
			register1: false,
			expected:  errInvalidTokenPath,
		},
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

			if tt.expected != nil {
				err := validateTokenPath(tt.token0, tt.token1)
				uassert.Equal(t, tt.expected.Error(), err.Error())
			} else {
				uassert.NotPanics(t, func() {
					err := validateTokenPath(tt.token0, tt.token1)
					if err != nil {
						t.Errorf("expected no error but got %s", err.Error())
					}
				})
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
		caller         std.Address
		expected0      string
		expected1      string
		isNative0      bool
		isNative1      bool
		expectedWrap   uint64
		expectPanic    bool
		expectMsg      string
	}{
		{
			name:           "Both tokens valid and not native",
			token0:         gnsPath,
			token1:         "tokenB",
			amount0Desired: "100",
			amount1Desired: "200",
			caller:         users.Resolve(alice),
			expected0:      "tokenA",
			expected1:      "tokenB",
			isNative0:      false,
			isNative1:      false,
			expectedWrap:   0,
			expectPanic:    true,
			expectMsg:      "[GNOSWAP-POSITION-016] invalid token address || token0(gno.land/r/gnoswap/v1/gns), token1(tokenB)",
		},
		{
			name:           "token0 is native",
			token0:         consts.GNOT,
			token1:         gnsPath,
			amount0Desired: "1300",
			amount1Desired: "200",
			caller:         users.Resolve(alice),
			expected0:      consts.WRAPPED_WUGNOT,
			expected1:      "gno.land/r/gnoswap/v1/gns",
			isNative0:      true,
			isNative1:      false,
			expectedWrap:   1300,
			expectPanic:    false,
			expectMsg:      "[GNOSWAP-POSITION-016] invalid token address || token0(gnot), token1(gno.land/r/gnoswap/v1/gns)",
		},
		{
			name:           "token1 is native",
			token0:         gnsPath,
			token1:         consts.GNOT,
			amount0Desired: "150",
			amount1Desired: "1250",
			caller:         testutils.TestAddress("user3"),
			expected0:      "gno.land/r/gnoswap/v1/gns",
			expected1:      consts.WRAPPED_WUGNOT,
			isNative0:      false,
			isNative1:      true,
			expectedWrap:   1250,
			expectPanic:    false,
		},
		{
			name:           "Both tokens are native",
			token0:         consts.GNOT,
			token1:         consts.GNOT,
			amount0Desired: "1100",
			amount1Desired: "1200",
			caller:         testutils.TestAddress("user4"),
			expected0:      consts.WRAPPED_WUGNOT,
			expected1:      consts.WRAPPED_WUGNOT,
			isNative0:      true,
			isNative1:      true,
			expectedWrap:   2300,
			expectPanic:    true,
			expectMsg:      "[GNOSWAP-POSITION-016] invalid token address || token0(gnot), token1(gnot)",
		},
		{
			name:           "Invalid token path",
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

			defer func() {
				if r := recover(); r != nil {
					if !tt.expectPanic {
						t.Errorf("unexpected panic: %v", r)
					}
				}
			}()

			if tt.token0 == consts.GNOT {
				amount, _ := strconv.ParseUint(tt.amount0Desired, 10, 64)
				ugnotFaucet(t, consts.POSITION_ADDR, amount)
				std.TestSetRealm(std.NewUserRealm(consts.POSITION_ADDR))
				transferUGNOT(consts.POSITION_ADDR, consts.POSITION_ADDR, amount)
			}
			if tt.token1 == consts.GNOT {
				amount, _ := strconv.ParseUint(tt.amount1Desired, 10, 64)
				ugnotFaucet(t, consts.POSITION_ADDR, amount)
				std.TestSetRealm(std.NewUserRealm(consts.POSITION_ADDR))
				transferUGNOT(consts.POSITION_ADDR, consts.POSITION_ADDR, amount)
			}

			if !tt.expectPanic {
				token0, token1, native0, native1, wrapped := processTokens(
					tt.token0,
					tt.token1,
					tt.amount0Desired,
					tt.amount1Desired,
					tt.caller,
				)

				uassert.Equal(t, tt.expected0, token0)
				uassert.Equal(t, tt.expected1, token1)
				uassert.Equal(t, tt.isNative0, native0)
				uassert.Equal(t, tt.isNative1, native1)
				uassert.Equal(t, tt.expectedWrap, wrapped)
			} else {
				uassert.PanicsWithMessage(t, tt.expectMsg, func() {
					processTokens(tt.token0, tt.token1, tt.amount0Desired, tt.amount1Desired, tt.caller)
				})
			}
		})
	}
}

func TestProcessMintInput(t *testing.T) {
	tests := []struct {
		name            string
		input           MintInput
		expectedToken0  string
		expectedToken1  string
		expectedAmount0 string
		expectedAmount1 string
		expectedTickL   int32
		expectedTickU   int32
		expectError     bool
	}{
		{
			name: "Standard Mint - Token0 < Token1",
			input: MintInput{
				token0:         gnsPath,
				token1:         barPath,
				amount0Desired: "1000",
				amount1Desired: "2000",
				amount0Min:     "800",
				amount1Min:     "1800",
				tickLower:      -10000,
				tickUpper:      10000,
				caller:         users.Resolve(alice),
			},
			expectedToken0:  gnsPath,
			expectedToken1:  barPath,
			expectedAmount0: "1000",
			expectedAmount1: "2000",
			expectedTickL:   -10000,
			expectedTickU:   10000,
			expectError:     false,
		},
		{
			name: "Token Swap - Token1 < Token0",
			input: MintInput{
				token0:         barPath,
				token1:         gnsPath,
				amount0Desired: "2000",
				amount1Desired: "1000",
				amount0Min:     "1800",
				amount1Min:     "800",
				tickLower:      -20000,
				tickUpper:      20000,
				caller:         users.Resolve(alice),
			},
			expectedToken0:  gnsPath,
			expectedToken1:  barPath,
			expectedAmount0: "1000",
			expectedAmount1: "2000",
			expectedTickL:   -20000,
			expectedTickU:   20000,
			expectError:     false,
		},
		{
			name: "Error Case - Invalid Amounts",
			input: MintInput{
				token0:         gnsPath,
				token1:         barPath,
				amount0Desired: "invalid",
				amount1Desired: "2000",
				amount0Min:     "800",
				amount1Min:     "1800",
				tickLower:      -5000,
				tickUpper:      5000,
				caller:         users.Resolve(alice),
			},
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if !tt.expectError {
						t.Errorf("unexpected panic: %v", r)
					} else {
						uassert.Equal(t, "[GNOSWAP-POSITION-005] invalid input data || input string : invalid", r)
					}
				}
			}()
			processed, err := processMintInput(tt.input)

			if tt.expectError {
				if err == nil {
					t.Errorf("expected error but got nil")
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
				uassert.Equal(t, tt.expectedToken0, processed.tokenPair.token0)
				uassert.Equal(t, tt.expectedToken1, processed.tokenPair.token1)
				uassert.Equal(t, tt.expectedAmount0, processed.amount0Desired.ToString())
				uassert.Equal(t, tt.expectedAmount1, processed.amount1Desired.ToString())
				uassert.Equal(t, tt.expectedTickL, processed.tickLower)
				uassert.Equal(t, tt.expectedTickU, processed.tickUpper)
			}
		})
	}
}

func TestMintInternal(t *testing.T) {
	MakeMintPositionWithoutFee(t)
	TokenFaucet(t, fooPath, alice)
	TokenFaucet(t, barPath, alice)
	TokenApprove(t, fooPath, alice, pool, maxApprove)
	TokenApprove(t, barPath, alice, pool, maxApprove)

	tests := []struct {
		name              string
		params            MintParams
		expectedTokenId   uint64
		expectedLiquidity string
		expectedAmount0   string
		expectedAmount1   string
		expectPanic       bool
		expectedError     string
		tokenId           uint64
	}{
		{
			name: "Successful Mint",
			params: MintParams{
				token0:         barPath,
				token1:         fooPath,
				fee:            fee500,
				tickLower:      -100,
				tickUpper:      100,
				amount0Desired: u256.MustFromDecimal("10000"),
				amount1Desired: u256.MustFromDecimal("10000"),
				amount0Min:     u256.MustFromDecimal("10"),
				amount1Min:     u256.MustFromDecimal("10"),
				caller:         users.Resolve(alice),
				mintTo:         users.Resolve(alice),
			},
			expectedTokenId:   101,
			expectedLiquidity: "2005104",
			expectedAmount0:   "10000",
			expectedAmount1:   "10000",
			expectPanic:       false,
		},
		{
			name: "Position Exists",
			params: MintParams{
				token0:         barPath,
				token1:         fooPath,
				fee:            fee500,
				tickLower:      -100,
				tickUpper:      100,
				amount0Desired: u256.MustFromDecimal("10000"),
				amount1Desired: u256.MustFromDecimal("10000"),
				amount0Min:     u256.MustFromDecimal("10"),
				amount1Min:     u256.MustFromDecimal("10"),
				caller:         users.Resolve(alice),
				mintTo:         users.Resolve(alice),
			},
			expectPanic:   true,
			expectedError: "token id already exists",
			tokenId:       1,
		},
		{
			name: "Zero Liquidity Mint",
			params: MintParams{
				token0:         barPath,
				token1:         fooPath,
				fee:            fee500,
				tickLower:      -200,
				tickUpper:      200,
				amount0Desired: u256.Zero(),
				amount1Desired: u256.Zero(),
				amount0Min:     u256.NewUint(5),
				amount1Min:     u256.NewUint(5),
				caller:         users.Resolve(alice),
				mintTo:         users.Resolve(alice),
			},
			expectPanic:   true,
			expectedError: "[GNOSWAP-POOL-010] zero liquidity",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.tokenId != 0 {
				nextId = tt.tokenId
			}

			if !tt.expectPanic {
				std.TestSetRealm(std.NewUserRealm(tt.params.mintTo))
				tokenId, liquidity, amount0, amount1 := mint(tt.params)
				uassert.Equal(t, tt.expectedTokenId, tokenId)
				uassert.Equal(t, tt.expectedLiquidity, liquidity.ToString())
				uassert.Equal(t, tt.expectedAmount0, amount0.ToString())
				uassert.Equal(t, tt.expectedAmount1, amount1.ToString())
			} else {
				uassert.PanicsWithMessage(t, tt.expectedError, func() {
					mint(tt.params)
				})
			}
		})
	}
}

func TestMint(t *testing.T) {
	t.Skip("TestMint not implemented")
}

func TestIncreaseLiquidityInternal(t *testing.T) {
	t.Skip("TestIncreaseLiquidityInternal not implemented")
}

func TestIncreaseLiquidity(t *testing.T) {
	t.Skip("TestIncreaseLiquidity not implemented")
}

func TestDecreaseLiquidityInternal(t *testing.T) {
	t.Skip("TestDecreaseLiquidityInternal not implemented")
}

func TestDecreaseLiquidity(t *testing.T) {
	t.Skip("TestDecreaseLiquidity not implemented")
}

func TestCollectFees(t *testing.T) {
	t.Skip("TestCollectFees not implemented")
}

func TestReposition(t *testing.T) {
	t.Skip("TestReposition not implemented")
}
