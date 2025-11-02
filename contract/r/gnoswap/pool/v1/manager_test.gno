package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	pl "gno.land/r/gnoswap/pool"
)

func TestGetPoolPath(t *testing.T) {
	path := GetPoolPath(barTokenPath, fooTokenPath, 500)
	expected := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
	if path != expected {
		t.Errorf("Expected path %s, got %s", expected, path)
	}

	path = GetPoolPath(fooTokenPath, barTokenPath, 500)
	if path != expected {
		t.Errorf("Expected tokens to be sorted, expected %s, got %s", expected, path)
	}
}

func TestTickSpacingMap(t *testing.T) {
	tests := []struct {
		fee         uint32
		tickSpacing int32
	}{
		{100, 1},     // 0.01%
		{500, 10},    // 0.05%
		{3000, 60},   // 0.3%
		{10000, 200}, // 1%
	}

	for _, tt := range tests {
		spacing := getMockInstance().GetFeeAmountTickSpacing(tt.fee)
		if spacing != tt.tickSpacing {
			t.Errorf("For fee %d, expected tick spacing %d, got %d",
				tt.fee, tt.tickSpacing, spacing)
		}
	}
}

func TestCreatePool(t *testing.T) {
	tests := []struct {
		name        string
		token0Path  string
		token1Path  string
		fee         uint32
		sqrtPrice   string
		shouldPanic bool
		panicMsg    string
		inOrder     bool
	}{
		{
			name:       "success - normal token pair",
			token0Path: barPath,
			token1Path: fooPath,
			fee:        3000,
			sqrtPrice:  "4295128740",
		},
		{
			name:       "success - wugnot <> gns pool",
			token0Path: "gno.land/r/gnoland/wugnot",
			token1Path: "gno.land/r/gnoswap/gns",
			fee:        3000,
			sqrtPrice:  "79228162514264337593543950337",
		},
		{
			name:        "fail - same tokens",
			token0Path:  barPath,
			token1Path:  barPath,
			fee:         3000,
			sqrtPrice:   "4295128740",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-011] same token used in single pool || expected token0Path(gno.land/r/onbloc/bar) != token1Path(gno.land/r/onbloc/bar)",
		},
		{
			name:        "success - when tokens not in order, reverse order and create pool",
			token0Path:  fooPath,
			token1Path:  bazPath,
			fee:         3000,
			sqrtPrice:   "4295343490",
			shouldPanic: false,
			panicMsg:    "[GNOSWAP-POOL-012] tokens must be in lexicographical order || expected token0Path(gno.land/r/onbloc/foo) < token1Path(gno.land/r/onbloc/baz)",
			inOrder:     true,
		},
		{
			name:        "fail - pool already exists",
			token0Path:  barPath,
			token1Path:  fooPath,
			fee:         3000,
			sqrtPrice:   "4295128740",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-003] pool already created || expected poolPath(gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000) not to exist",
		},
		{
			name:        "fail - invalid fee amount",
			token0Path:  barPath,
			token1Path:  fooPath,
			fee:         1234,
			sqrtPrice:   "4295128740",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-002] unsupported fee tier || expected fee(1234) to be one of 100, 500, 3000, 10000",
		},
		{
			name:        "fail - invalid sqrtPrice (too small)",
			token0Path:  bazPath,
			token1Path:  barPath,
			fee:         3000,
			sqrtPrice:   "0",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-005] out of range for numeric value || sqrtPriceX96(0) is out of range",
		},
	}

	initPoolTest(t)
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	mockInstanceSetPoolCreationFee(0)

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(testing.NewUserRealm(adminAddr))

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					mockInstanceCreatePool(tt.token0Path, tt.token1Path, tt.fee, tt.sqrtPrice)
				})
			} else {
				mockInstanceCreatePool(tt.token0Path, tt.token1Path, tt.fee, tt.sqrtPrice)

				// verify pool was created correctly
				poolPath := GetPoolPath(tt.token0Path, tt.token1Path, tt.fee)
				pool := getMockInstance().mustGetPool(poolPath)

				// check if GNOT was properly wrapped
				expectedToken0 := tt.token0Path
				expectedToken1 := tt.token1Path
				if tt.inOrder {
					expectedToken0, expectedToken1 = expectedToken1, expectedToken0
				}

				if expectedToken0 == GNOT {
					expectedToken0 = WRAPPED_WUGNOT
				}
				if expectedToken1 == GNOT {
					expectedToken1 = WRAPPED_WUGNOT
				}

				if pool.Token0Path() != expectedToken0 || pool.Token1Path() != expectedToken1 {
					t.Errorf("incorrect token paths in pool. got %s,%s want %s,%s",
						pool.Token0Path(), pool.Token1Path(), expectedToken0, expectedToken1)
				}
			}
		})
	}
}

func TestGetPool(t *testing.T) {
	tests := []struct {
		name        string
		setupFn     func(t *testing.T)
		action      func(t *testing.T) *pl.Pool
		shouldPanic bool
		expected    string
		verifyFn    func(t *testing.T, pool *pl.Pool)
	}{
		{
			name: "Panic - unregistered poolPath",
			setupFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)
				mockInstanceSetPoolCreationFee(0)
			},
			action: func(t *testing.T) *pl.Pool {
				return getMockInstance().GetPool(barPath, fooPath, fee500)
			},
			shouldPanic: true,
			expected:    "[GNOSWAP-POOL-008] requested data not found || expected poolPath(gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500) to exist",
		},
		{
			name: "success - get pool (bar:foo:500)",
			setupFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)
				mockInstanceSetPoolCreationFee(0)
				mockInstanceCreatePool(barPath, fooPath, fee500, "4295128740")
			},
			action: func(t *testing.T) *pl.Pool {
				return getMockInstance().GetPool(barPath, fooPath, fee500)
			},
			verifyFn: func(t *testing.T, pool *pl.Pool) {
				if pool.Token0Path() != barPath {
					t.Errorf("expected token0Path %s, got %s", barPath, pool.Token0Path())
				}
				if pool.Token1Path() != fooPath {
					t.Errorf("expected token1Path %s, got %s", fooPath, pool.Token1Path())
				}
				if pool.Fee() != fee500 {
					t.Errorf("expected fee %d, got %d", fee500, pool.Fee())
				}
				if pool.Slot0SqrtPriceX96().ToString() != "4295128740" {
					t.Errorf("expected sqrtPriceX96 %s, got %s", "4295128740", pool.Slot0SqrtPriceX96().ToString())
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r == nil {
					if tt.shouldPanic {
						t.Errorf(">>> %s: expected panic but got none", tt.name)
					}
				} else {
					switch r.(type) {
					case string:
						if r.(string) != tt.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tt.name, r, tt.expected)
						}
					case error:
						if r.(error).Error() != tt.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tt.name, r.(error).Error(), tt.expected)
						}
					default:
						t.Errorf(">>> %s: got panic %v, want %v", tt.name, r, tt.expected)
					}
				}
			}()
			if tt.setupFn != nil {
				tt.setupFn(t)
			}

			if tt.shouldPanic {
				tt.action(t)
			}

			if !tt.shouldPanic {
				pool := tt.action(t)
				if tt.verifyFn != nil {
					tt.verifyFn(t, pool)
				}
			}
		})
	}
}

// TestAssertIsNotEqualsTokens tests duplicate token detection
func TestAssertIsNotEqualsTokens(t *testing.T) {
	tests := []struct {
		name        string
		token0Path  string
		token1Path  string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "same token path",
			token0Path:  barPath,
			token1Path:  barPath,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-011] same token used in single pool || expected token0Path(gno.land/r/onbloc/bar) != token1Path(gno.land/r/onbloc/bar)",
		},
		{
			name:        "different token paths",
			token0Path:  barPath,
			token1Path:  fooPath,
			shouldPanic: false,
		},
		{
			name:        "empty strings",
			token0Path:  "",
			token1Path:  "",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-011] same token used in single pool || expected token0Path() != token1Path()",
		},
		{
			name:        "one empty one valid",
			token0Path:  barPath,
			token1Path:  "",
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					assertIsNotEqualsTokens(tt.token0Path, tt.token1Path)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsNotEqualsTokens(tt.token0Path, tt.token1Path)
				})
			}
		})
	}
}

// TestAssertIsSupportedFeeTier tests fee tier validation
func TestAssertIsSupportedFeeTier(t *testing.T) {
	tests := []struct {
		name        string
		fee         uint32
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "valid - fee tier 100",
			fee:         FeeTier100,
			shouldPanic: false,
		},
		{
			name:        "valid - fee tier 500",
			fee:         FeeTier500,
			shouldPanic: false,
		},
		{
			name:        "valid - fee tier 3000",
			fee:         FeeTier3000,
			shouldPanic: false,
		},
		{
			name:        "valid - fee tier 10000",
			fee:         FeeTier10000,
			shouldPanic: false,
		},
		{
			name:        "invalid - zero",
			fee:         0,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-002] unsupported fee tier || expected fee(0) to be one of 100, 500, 3000, 10000",
		},
		{
			name:        "invalid - 99",
			fee:         99,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-002] unsupported fee tier || expected fee(99) to be one of 100, 500, 3000, 10000",
		},
		{
			name:        "invalid - 101",
			fee:         101,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-002] unsupported fee tier || expected fee(101) to be one of 100, 500, 3000, 10000",
		},
		{
			name:        "invalid - 1000",
			fee:         1000,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-002] unsupported fee tier || expected fee(1000) to be one of 100, 500, 3000, 10000",
		},
		{
			name:        "invalid - max uint32",
			fee:         4294967295,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-002] unsupported fee tier || expected fee(4294967295) to be one of 100, 500, 3000, 10000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					assertIsSupportedFeeTier(tt.fee)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsSupportedFeeTier(tt.fee)
				})
			}
		})
	}
}

// TestAssertAmountSpecifiedIsNotZero tests zero amount validation
func TestAssertAmountSpecifiedIsNotZero(t *testing.T) {
	tests := []struct {
		name            string
		amountSpecified string
		shouldPanic     bool
		errorMsg        string
	}{
		{
			name:            "zero amount",
			amountSpecified: "0",
			shouldPanic:     true,
			errorMsg:        "[GNOSWAP-POOL-015] invalid swap amount || amountSpecified == 0",
		},
		{
			name:            "positive amount",
			amountSpecified: "100",
			shouldPanic:     false,
		},
		{
			name:            "negative amount",
			amountSpecified: "-100",
			shouldPanic:     false,
		},
		{
			name:            "large positive amount",
			amountSpecified: "999999999999999999",
			shouldPanic:     false,
		},
		{
			name:            "large negative amount",
			amountSpecified: "-999999999999999999",
			shouldPanic:     false,
		},
		{
			name:            "empty string",
			amountSpecified: "",
			shouldPanic:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					assertAmountSpecifiedIsNotZero(tt.amountSpecified)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertAmountSpecifiedIsNotZero(tt.amountSpecified)
				})
			}
		})
	}
}

// TestAssertIsValidTokenOrder tests token lexicographical ordering
func TestAssertIsValidTokenOrder(t *testing.T) {
	tests := []struct {
		name        string
		token0Path  string
		token1Path  string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "valid order - token0 < token1",
			token0Path:  barPath,
			token1Path:  fooPath,
			shouldPanic: false,
		},
		{
			name:        "invalid order - token0 > token1",
			token0Path:  fooPath,
			token1Path:  barPath,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-006] invalid input data || expected token0Path(gno.land/r/onbloc/foo) < token1Path(gno.land/r/onbloc/bar)",
		},
		{
			name:        "invalid order - equal tokens",
			token0Path:  barPath,
			token1Path:  barPath,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-006] invalid input data || expected token0Path(gno.land/r/onbloc/bar) < token1Path(gno.land/r/onbloc/bar)",
		},
		{
			name:        "valid order - alphabetical",
			token0Path:  "gno.land/r/onbloc/aaa",
			token1Path:  "gno.land/r/onbloc/zzz",
			shouldPanic: false,
		},
		{
			name:        "invalid order - reverse alphabetical",
			token0Path:  "gno.land/r/onbloc/zzz",
			token1Path:  "gno.land/r/onbloc/aaa",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-006] invalid input data || expected token0Path(gno.land/r/onbloc/zzz) < token1Path(gno.land/r/onbloc/aaa)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					assertIsValidTokenOrder(tt.token0Path, tt.token1Path)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidTokenOrder(tt.token0Path, tt.token1Path)
				})
			}
		})
	}
}
