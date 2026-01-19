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
			panicMsg:    "[GNOSWAP-POOL-009] same token used in single pool || expected token0Path(gno.land/r/onbloc/bar) != token1Path(gno.land/r/onbloc/bar)",
		},
		{
			name:        "fail - same wrapped tokens",
			token0Path:  WUGNOT_PATH,
			token1Path:  GNOT_DENOM,
			fee:         3000,
			sqrtPrice:   "4295128740",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-009] same token used in single pool || expected token0Path(gno.land/r/gnoland/wugnot) != token1Path(gno.land/r/gnoland/wugnot)",
		},
		{
			name:        "fail - same wrapped tokens reversed",
			token0Path:  GNOT_DENOM,
			token1Path:  WUGNOT_PATH,
			fee:         3000,
			sqrtPrice:   "4295128740",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-009] same token used in single pool || expected token0Path(gno.land/r/gnoland/wugnot) != token1Path(gno.land/r/gnoland/wugnot)",
		},
		{
			name:        "success - when tokens not in order, reverse order and create pool",
			token0Path:  fooPath,
			token1Path:  bazPath,
			fee:         3000,
			sqrtPrice:   "4295343490",
			shouldPanic: false,
			panicMsg:    "[GNOSWAP-POOL-010] tokens must be in lexicographical order || expected token0Path(gno.land/r/onbloc/foo) < token1Path(gno.land/r/onbloc/baz)",
			inOrder:     true,
		},
		{
			name:        "fail - pool already exists",
			token0Path:  barPath,
			token1Path:  fooPath,
			fee:         3000,
			sqrtPrice:   "4295128740",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-002] pool already created || expected poolPath(gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000) not to exist",
		},
		{
			name:        "fail - invalid fee amount",
			token0Path:  barPath,
			token1Path:  fooPath,
			fee:         1234,
			sqrtPrice:   "4295128740",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-001] unsupported fee tier || expected fee(1234) to be one of 100, 500, 3000, 10000",
		},
		{
			name:        "fail - invalid sqrtPrice (too small)",
			token0Path:  bazPath,
			token1Path:  barPath,
			fee:         3000,
			sqrtPrice:   "0",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-003] out of range for numeric value || sqrtPriceX96(0) is out of range",
		},
		{
			name:        "fail - sqrtPrice above MAX_SQRT_RATIO",
			token0Path:  barPath,
			token1Path:  quxPath,
			fee:         3000,
			sqrtPrice:   "1461446703485210103287273052203988822378723970343", // MAX_SQRT_RATIO + 1
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-003] out of range for numeric value || sqrtPriceX96(1461446703485210103287273052203988822378723970343) is out of range",
		},
		{
			name:        "success - sqrtPrice at MIN_SQRT_RATIO",
			token0Path:  fooPath,
			token1Path:  quxPath,
			fee:         500,
			sqrtPrice:   "4295128739", // MIN_SQRT_RATIO
			shouldPanic: false,
		},
		{
			name:        "fail - sqrtPrice at MAX_SQRT_RATIO (boundary excluded)",
			token0Path:  bazPath,
			token1Path:  quxPath,
			fee:         10000,
			sqrtPrice:   "1461446703485210103287273052203988822378723970342", // MAX_SQRT_RATIO
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-003] out of range for numeric value || sqrtPriceX96(1461446703485210103287273052203988822378723970342) is out of range",
		},
		{
			name:        "success - sqrtPrice just below MAX_SQRT_RATIO",
			token0Path:  barPath,
			token1Path:  bazPath,
			fee:         100,
			sqrtPrice:   "1461446703485210103287273052203988822378723970341", // MAX_SQRT_RATIO - 1
			shouldPanic: false,
		},
		{
			name:        "fail - sqrtPrice just below MIN_SQRT_RATIO",
			token0Path:  oblPath,
			token1Path:  barPath,
			fee:         500,
			sqrtPrice:   "4295128738", // MIN_SQRT_RATIO - 1
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-003] out of range for numeric value || sqrtPriceX96(4295128738) is out of range",
		},
		{
			name:        "success - sqrtPrice just above MIN_SQRT_RATIO",
			token0Path:  fooPath,
			token1Path:  oblPath,
			fee:         3000,
			sqrtPrice:   "4295128740", // MIN_SQRT_RATIO + 1
			shouldPanic: false,
		},
		{
			name:        "fail - sqrtPrice one",
			token0Path:  oblPath,
			token1Path:  quxPath,
			fee:         500,
			sqrtPrice:   "1",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-003] out of range for numeric value || sqrtPriceX96(1) is out of range",
		},
		{
			name:        "success - mid-range sqrtPrice",
			token0Path:  bazPath,
			token1Path:  oblPath,
			fee:         10000,
			sqrtPrice:   "79228162514264337593543950337", // sqrt(1) * 2^96
			shouldPanic: false,
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

				if expectedToken0 == GNOT_DENOM {
					expectedToken0 = WUGNOT_PATH
				}
				if expectedToken1 == GNOT_DENOM {
					expectedToken1 = WUGNOT_PATH
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
		shouldError bool
		expected    string
		verifyFn    func(t *testing.T, pool *pl.Pool)
	}{
		{
			name: "Panic - unregistered poolPath",
			setupFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)
				mockInstanceSetPoolCreationFee(0)
			},
			shouldError: true,
			expected:    "[GNOSWAP-POOL-006] requested data not found || expected poolPath(gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500) to exist",
		},
		{
			name: "success - get pool (bar:foo:500)",
			setupFn: func(t *testing.T) {
				testing.SetRealm(adminRealm)
				mockInstanceSetPoolCreationFee(0)
				mockInstanceCreatePool(barPath, fooPath, fee500, "4295128740")
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
			if tt.setupFn != nil {
				tt.setupFn(t)
			}

			pool, err := getMockInstance().GetPool(barPath, fooPath, fee500)
			if tt.shouldError {
				uassert.Error(t, err, "expected error")
			} else {
				if tt.verifyFn != nil {
					tt.verifyFn(t, pool)
				}
			}
		})
	}
}

// TestSetFeeProtocol_BoundaryValues tests edge cases for fee protocol values
func TestSetFeeProtocol_BoundaryValues(t *testing.T) {
	tests := []struct {
		name         string
		feeProtocol0 uint8
		feeProtocol1 uint8
		shouldError  bool
		expectedFee  uint8
		description  string
	}{
		{
			name:         "valid - both zero (fees disabled)",
			feeProtocol0: 0,
			feeProtocol1: 0,
			shouldError:  false,
			expectedFee:  0,
			description:  "Zero values should disable protocol fees",
		},
		{
			name:         "valid - minimum non-zero values",
			feeProtocol0: 4,
			feeProtocol1: 4,
			shouldError:  false,
			expectedFee:  68, // 4 + (4 << 4) = 4 + 64 = 68
			description:  "Minimum non-zero values (4, 4) should be accepted",
		},
		{
			name:         "valid - maximum values",
			feeProtocol0: 10,
			feeProtocol1: 10,
			shouldError:  false,
			expectedFee:  170, // 10 + (10 << 4) = 10 + 160 = 170
			description:  "Maximum values (10, 10) should be accepted",
		},
		{
			name:         "valid - asymmetric minimum",
			feeProtocol0: 4,
			feeProtocol1: 0,
			shouldError:  false,
			expectedFee:  4, // 4 + (0 << 4) = 4
			description:  "Asymmetric values (4, 0) should be accepted",
		},
		{
			name:         "valid - asymmetric maximum",
			feeProtocol0: 0,
			feeProtocol1: 10,
			shouldError:  false,
			expectedFee:  160, // 0 + (10 << 4) = 160
			description:  "Asymmetric values (0, 10) should be accepted",
		},
		{
			name:         "valid - mixed values",
			feeProtocol0: 4,
			feeProtocol1: 10,
			shouldError:  false,
			expectedFee:  164, // 4 + (10 << 4) = 4 + 160 = 164
			description:  "Mixed values (4, 10) should be accepted",
		},
		{
			name:         "invalid - just below minimum (token0)",
			feeProtocol0: 3,
			feeProtocol1: 5,
			shouldError:  true,
			expectedFee:  0,
			description:  "Value 3 for token0 should be rejected",
		},
		{
			name:         "invalid - just below minimum (token1)",
			feeProtocol0: 5,
			feeProtocol1: 3,
			shouldError:  true,
			expectedFee:  0,
			description:  "Value 3 for token1 should be rejected",
		},
		{
			name:         "invalid - just above maximum (token0)",
			feeProtocol0: 11,
			feeProtocol1: 5,
			shouldError:  true,
			expectedFee:  0,
			description:  "Value 11 for token0 should be rejected",
		},
		{
			name:         "invalid - just above maximum (token1)",
			feeProtocol0: 5,
			feeProtocol1: 11,
			shouldError:  true,
			expectedFee:  0,
			description:  "Value 11 for token1 should be rejected",
		},
		{
			name:         "invalid - value 1",
			feeProtocol0: 1,
			feeProtocol1: 5,
			shouldError:  true,
			expectedFee:  0,
			description:  "Value 1 should be rejected (must be 0 or 4-10)",
		},
		{
			name:         "invalid - value 2",
			feeProtocol0: 2,
			feeProtocol1: 5,
			shouldError:  true,
			expectedFee:  0,
			description:  "Value 2 should be rejected (must be 0 or 4-10)",
		},
		{
			name:         "invalid - max uint8",
			feeProtocol0: 255,
			feeProtocol1: 5,
			shouldError:  true,
			expectedFee:  0,
			description:  "Max uint8 value should be rejected",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetObject(t)

			newFee, err := getMockInstance().setFeeProtocol(tt.feeProtocol0, tt.feeProtocol1)

			if tt.shouldError {
				uassert.NotNil(t, err, tt.description)
			} else {
				uassert.Nil(t, err, tt.description)
				uassert.Equal(t, tt.expectedFee, newFee, tt.description)

				// Verify the fee was actually set
				actualFee := getMockInstance().store.GetSlot0FeeProtocol()
				uassert.Equal(t, tt.expectedFee, actualFee, "Fee should be persisted correctly")
			}
		})
	}
}
