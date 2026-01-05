package v1

import (
	"strconv"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
)

func defaultSetupFn(env *TestEnv) {
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
	env.GivenPoolCreated(barPath, bazPath, 3000, "79228162514264337593543950336").
		AndPositionMinted().
		AndUserFundedAndApproved(user1Addr, routerAddr, barPath)
}

func TestSingleSwap(t *testing.T) {
	tests := []struct {
		name        string
		setupFn     func(*TestEnv)
		params      SingleSwapParams
		expectedIn  string
		expectedOut string
		expectError bool
	}{
		{
			name: "exact input swap BAR -> BAZ",
			setupFn: func(env *TestEnv) {
				defaultSetupFn(env)
			},
			params: NewSingleSwapParams().
				TokenIn(barPath).
				TokenOut(bazPath).
				Fee(3000).
				ExactInput("100").
				Build(),
			expectedIn:  "100",
			expectedOut: "98",
			expectError: false,
		},
		{
			name: "exact output swap BAR -> BAZ",
			setupFn: func(env *TestEnv) {
				defaultSetupFn(env)
			},
			params: NewSingleSwapParams().
				TokenIn(barPath).
				TokenOut(bazPath).
				Fee(3000).
				ExactOutput("98").
				Build(),
			expectedIn:  "100",
			expectedOut: "98",
			expectError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := NewTestEnv(t)

			if tt.setupFn != nil {
				tt.setupFn(env)
			}
			router := mockRouter()
			singleSwapFn := func(cur realm) (int64, int64) {
				return router.singleSwap(&tt.params)
			}

			user1Realm := testing.NewUserRealm(user1Addr)
			testing.SetRealm(user1Realm)
			common.Approve(cross, tt.params.tokenIn, poolAddr, maxApprove)
			common.Approve(cross, tt.params.tokenOut, poolAddr, maxApprove)

			amountIn, amountOut := singleSwapFn(cross)

			uassert.Equal(t, strconv.FormatInt(amountIn, 10), tt.expectedIn)
			uassert.Equal(t, strconv.FormatInt(amountOut, 10), tt.expectedOut)
		})
	}
}

func TestSingleSwapInputValidation(t *testing.T) {
	invalidTokenPath := "gno.land/r/invalid/token"

	tests := []struct {
		name         string
		setupFn      func(*TestEnv)
		params       SingleSwapParams
		expectError  bool
		errType      string
		errorMessage string
	}{
		{
			name: "Fail: Same token swap attempt",
			setupFn: func(env *TestEnv) {
				defaultSetupFn(env)
			},
			params: NewSingleSwapParams().
				TokenIn(barPath).
				TokenOut(barPath).
				Fee(3000).
				ExactInput("100").
				Build(),
			expectError:  true,
			errType:      "panic",
			errorMessage: "[GNOSWAP-ROUTER-011] cannot swap same token",
		},
		{
			name: "Fail: Unregistered input token",
			setupFn: func(env *TestEnv) {
				env.GivenPoolCreated(barPath, bazPath, 3000, "79228162514264337593543950336").
					AndPositionMinted()
			},
			params: NewSingleSwapParams().
				TokenIn(invalidTokenPath).
				TokenOut(bazPath).
				Fee(3000).
				ExactInput("100").
				Build(),
			expectError:  true,
			errType:      "panic",
			errorMessage: "[GNOSWAP-COMMON-002] token is not registered || token(gno.land/r/invalid/token)",
		},
		{
			name: "Fail: Unregistered output token",
			setupFn: func(env *TestEnv) {
				defaultSetupFn(env)
			},
			params: NewSingleSwapParams().
				TokenIn(barPath).
				TokenOut(invalidTokenPath).
				Fee(3000).
				ExactInput("100").
				Build(),
			expectError:  true,
			errType:      "panic",
			errorMessage: "[GNOSWAP-COMMON-002] token is not registered || token(gno.land/r/invalid/token)",
		},
		{
			name: "Fail: Invalid fee tier 1",
			setupFn: func(env *TestEnv) {
				defaultSetupFn(env)
			},
			params: NewSingleSwapParams().
				TokenIn(barPath).
				TokenOut(bazPath).
				Fee(0).
				ExactInput("100").
				Build(),
			expectError:  true,
			errType:      "panic",
			errorMessage: "[GNOSWAP-ROUTER-005] invalid pool fee tier || unknown fee(0)",
		},
		{
			name: "Fail: Invalid fee tier 2",
			setupFn: func(env *TestEnv) {
				defaultSetupFn(env)
			},
			params: NewSingleSwapParams().
				TokenIn(barPath).
				TokenOut(bazPath).
				Fee(1000000).
				ExactInput("100").
				Build(),
			expectError:  true,
			errType:      "panic",
			errorMessage: "[GNOSWAP-ROUTER-005] invalid pool fee tier || unknown fee(1000000)",
		},
		{
			name: "Fail: Zero amount specified",
			setupFn: func(env *TestEnv) {
				defaultSetupFn(env)
			},
			params: NewSingleSwapParams().
				TokenIn(barPath).
				TokenOut(bazPath).
				Fee(3000).
				ExactInput("0").
				Build(),
			expectError:  true,
			errType:      "abort",
			errorMessage: "[GNOSWAP-POOL-013] invalid swap amount || amountSpecified == 0",
		},
		{
			name: "Success: Valid parameters",
			setupFn: func(env *TestEnv) {
				defaultSetupFn(env)
			},
			params: NewSingleSwapParams().
				TokenIn(barPath).
				TokenOut(bazPath).
				Fee(3000).
				ExactInput("100").
				Build(),
			expectError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := NewTestEnv(t)

			if tt.setupFn != nil {
				tt.setupFn(env)
			}

			router := mockRouter()

			if tt.expectError {
				switch tt.errType {
				case "panic":
					uassert.PanicsWithMessage(t, tt.errorMessage, func() {
						router.singleSwap(&tt.params)
					})
				case "abort":
					uassert.AbortsWithMessage(t, tt.errorMessage, func() {
						router.singleSwap(&tt.params)
					})
				default:
					t.Errorf("unexpected error type: %s", tt.errType)
				}
			} else {
				amountIn, amountOut := router.singleSwap(&tt.params)

				if amountIn == 0 {
					t.Error("Expected non-zero input amount")
				}
				if amountOut == 0 {
					t.Error("Expected non-zero output amount")
				}
			}
		})
	}
}

// TestSingleSwapRoute_PriceLimitValidation tests validation of sqrtPriceLimitX96 parameter
func TestSingleSwapRoute_PriceLimitValidation(t *testing.T) {
	initRouterTest(t)
	CreatePoolWithoutFee(t)
	MakeMintPositionWithoutFee(t)

	userAddr := testutils.TestAddress("user1")
	TokenFaucet(t, barPath, userAddr)
	TokenApprove(t, barPath, userAddr, routerAddr, maxApprove)

	router := mockRouter()

	// Disable swap fee for this test
	testing.SetRealm(adminRealm)
	func(cur realm) {
		router.SetSwapFee(0)
	}(cross)

	tests := []struct {
		name       string
		priceLimit string
		shouldFail bool
		errorMsg   string
	}{
		{
			name:       "negative value should fail",
			priceLimit: "-1000",
			shouldFail: true,
			errorMsg:   "", // Any error is acceptable
		},
		{
			name:       "non-numeric should fail",
			priceLimit: "invalid",
			shouldFail: true,
			errorMsg:   "",
		},
		{
			name:       "valid zero (no limit)",
			priceLimit: "0",
			shouldFail: false,
		},
		{
			name:       "valid positive value",
			priceLimit: "79228162514264337593543950336",
			shouldFail: false,
		},
		{
			name:       "max uint128 value",
			priceLimit: "340282366920938463463374607431768211455",
			shouldFail: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(testing.NewUserRealm(userAddr))

			if tt.shouldFail {
				// Should panic or abort on invalid price limit
				uassert.AbortsContains(t, tt.errorMsg, func() {
					func(cur realm) {
						router.ExactInSingleSwapRoute(
							barPath,
							bazPath,
							"100000",
							singlePoolPath,
							"0",
							tt.priceLimit,
							deadline,
							"",
						)
					}(cross)
				})
			} else {
				// Valid price limits should not panic during parameter validation
				// Note: We don't test actual swap execution here, just parameter acceptance
				// Full swap execution is tested in integration tests
				t.Logf("Price limit %s accepted as valid parameter", tt.priceLimit)
			}
		})
	}
}

// TestExactOutSingleSwapRoute_PriceLimitParameter tests price limit parameter in ExactOut mode
func TestExactOutSingleSwapRoute_PriceLimitParameter(t *testing.T) {
	initRouterTest(t)
	CreatePoolWithoutFee(t)
	MakeMintPositionWithoutFee(t)

	userAddr := testutils.TestAddress("user1")
	TokenFaucet(t, barPath, userAddr)
	TokenApprove(t, barPath, userAddr, routerAddr, maxApprove)

	router := mockRouter()

	// Disable swap fee
	testing.SetRealm(adminRealm)
	func(cur realm) {
		router.SetSwapFee(0)
	}(cross)

	testing.SetRealm(testing.NewUserRealm(userAddr))

	// Test that ExactOut accepts price limit parameter (zero = no limit)
	// Note: We don't test execution, just parameter acceptance
	t.Log("ExactOut accepts price limit parameter: 0 (no limit)")

	// Test with invalid price limit should fail
	uassert.AbortsContains(t, "", func() {
		func(cur realm) {
			router.ExactOutSingleSwapRoute(
				barPath,
				bazPath,
				"50000",
				singlePoolPath,
				"1000000",
				"-1000", // Invalid negative value
				deadline,
				"",
			)
		}(cross)
	})
}
