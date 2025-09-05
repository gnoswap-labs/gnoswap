package router

import (
	"std"
	"testing"

	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/v1/common"
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

			singleSwapFn := func(cur realm) (*u256.Uint, *u256.Uint) {
				return singleSwap(&tt.params)
			}

			user1Realm := std.NewUserRealm(user1Addr)
			testing.SetRealm(user1Realm)
			common.Approve(cross, tt.params.tokenIn, poolAddr, maxApprove)
			common.Approve(cross, tt.params.tokenOut, poolAddr, maxApprove)

			amountIn, amountOut := singleSwapFn(cross)

			uassert.Equal(t, amountIn.ToString(), tt.expectedIn)
			uassert.Equal(t, amountOut.ToString(), tt.expectedOut)
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
			errorMessage: "[GNOSWAP-ROUTER-014] cannot swap same token",
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
			errorMessage: "[GNOSWAP-COMMON-004] token is not registered || token(gno.land/r/invalid/token)",
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
			errorMessage: "[GNOSWAP-COMMON-004] token is not registered || token(gno.land/r/invalid/token)",
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
			errorMessage: "[GNOSWAP-ROUTER-006] invalid pool fee tier || unknown fee(0)",
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
			errorMessage: "[GNOSWAP-ROUTER-006] invalid pool fee tier || unknown fee(1000000)",
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
			errorMessage: "[GNOSWAP-POOL-015] invalid swap amount || amountSpecified == 0",
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

			if tt.expectError {
				switch tt.errType {
				case "panic":
					uassert.PanicsWithMessage(t, tt.errorMessage, func() {
						singleSwap(&tt.params)
					})
				case "abort":
					uassert.AbortsWithMessage(t, tt.errorMessage, func() {
						singleSwap(&tt.params)
					})
				default:
					t.Errorf("unexpected error type: %s", tt.errType)
				}
			} else {
				amountIn, amountOut := singleSwap(&tt.params)

				if amountIn == nil || amountOut == nil {
					t.Error("Expected non-nil amounts for successful swap")
				}
				if amountIn.IsZero() {
					t.Error("Expected non-zero input amount")
				}
				if amountOut.IsZero() {
					t.Error("Expected non-zero output amount")
				}
			}
		})
	}
}
