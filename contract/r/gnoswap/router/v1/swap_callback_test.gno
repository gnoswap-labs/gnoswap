package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

// TestSwapCallback tests the SwapCallback function with various scenarios
func TestSwapCallback(t *testing.T) {
	tests := []struct {
		name             string
		setupFunc        func(t *testing.T) address // returns payer address
		amount0Delta     string
		amount1Delta     string
		callerRealmPath  string
		shouldError      bool
		expectedErrorMsg string
	}{
		{
			name: "success with token0 payment",
			setupFunc: func(t *testing.T) address {
				initRouterTest(t)
				CreatePoolWithoutFee(t)
				MakeMintPositionWithoutFee(t)
				TokenFaucet(t, barPath, routerAddr)
				TokenFaucet(t, bazPath, routerAddr)
				return routerAddr
			},
			amount0Delta:    "1000",
			amount1Delta:    "0",
			callerRealmPath: "gno.land/r/gnoswap/router/v1",
			shouldError:     false,
		},
		{
			name: "success with token1 payment",
			setupFunc: func(t *testing.T) address {
				initRouterTest(t)
				CreatePoolWithoutFee(t)
				MakeMintPositionWithoutFee(t)
				TokenFaucet(t, barPath, routerAddr)
				TokenFaucet(t, bazPath, routerAddr)
				return routerAddr
			},
			amount0Delta:    "0",
			amount1Delta:    "1000",
			callerRealmPath: "gno.land/r/gnoswap/router/v1",
			shouldError:     false,
		},
		{
			name: "success with both deltas zero",
			setupFunc: func(t *testing.T) address {
				initRouterTest(t)
				CreatePoolWithoutFee(t)
				return routerAddr
			},
			amount0Delta:    "0",
			amount1Delta:    "0",
			callerRealmPath: "gno.land/r/gnoswap/router/v1",
			shouldError:     false,
		},
		{
			name: "success with user as payer",
			setupFunc: func(t *testing.T) address {
				initRouterTest(t)
				CreatePoolWithoutFee(t)
				MakeMintPositionWithoutFee(t)
				testUser := testutils.TestAddress("testUser")
				TokenFaucet(t, barPath, testUser)
				TokenFaucet(t, bazPath, testUser)
				TokenApprove(t, barPath, testUser, routerAddr, maxApprove)
				TokenApprove(t, bazPath, testUser, routerAddr, maxApprove)
				return testUser
			},
			amount0Delta:    "1000",
			amount1Delta:    "0",
			callerRealmPath: "gno.land/r/gnoswap/router/v1",
			shouldError:     false,
		},
		{
			name: "fail with invalid caller",
			setupFunc: func(t *testing.T) address {
				initRouterTest(t)
				CreatePoolWithoutFee(t)
				return routerAddr
			},
			amount0Delta:     "1000",
			amount1Delta:     "0",
			callerRealmPath:  "gno.land/r/unauthorized/contract",
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-ROUTER-004]",
		},
		{
			name: "fail with insufficient balance",
			setupFunc: func(t *testing.T) address {
				initRouterTest(t)
				CreatePoolWithoutFee(t)
				MakeMintPositionWithoutFee(t)
				poorUser := testutils.TestAddress("poorUser")
				return poorUser
			},
			amount0Delta:     "1000",
			amount1Delta:     "0",
			callerRealmPath:  "gno.land/r/gnoswap/router/v1",
			shouldError:      true,
			expectedErrorMsg: "insufficient balance",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			payer := tt.setupFunc(t)

			// Set caller realm
			testing.SetRealm(testing.NewCodeRealm(tt.callerRealmPath))

			// Execute
			if tt.shouldError {
				uassert.AbortsContains(t, tt.expectedErrorMsg, func() {
					mockInstanceSwapCallback(
						barPath,
						bazPath,
						tt.amount0Delta,
						tt.amount1Delta,
						payer,
					)
				})
			} else {
				err := mockInstanceSwapCallback(
					barPath,
					bazPath,
					tt.amount0Delta,
					tt.amount1Delta,
					payer,
				)
				uassert.NoError(t, err)
			}
		})
	}
}

// TestSwapCallback_AssertIsRouterV1 tests the assertIsRouterV1 function with various caller types
func TestSwapCallback_AssertIsRouterV1(t *testing.T) {
	tests := []struct {
		name             string
		callerAddress    address
		shouldError      bool
		expectedErrorMsg string
	}{
		{
			name:          "valid caller from router v1",
			callerAddress: routerV1Addr,
			shouldError:   false,
		},
		{
			name:             "invalid caller from unauthorized contract",
			callerAddress:    testutils.TestAddress("unauthorized"),
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-ROUTER-004]",
		},
		{
			name:             "invalid caller from user realm",
			callerAddress:    testutils.TestAddress("maliciousUser"),
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-ROUTER-004]",
		},
		{
			name:             "invalid caller from different contract",
			callerAddress:    testutils.TestAddress("different"),
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-ROUTER-004]",
		},
		{
			name:             "invalid caller from pool contract",
			callerAddress:    poolAddr,
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-ROUTER-004]",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute and verify
			if tt.shouldError {
				uassert.PanicsContains(t, tt.expectedErrorMsg, func() {
					assertIsRouterV1(tt.callerAddress)
				})
			} else {
				// Should not panic
				assertIsRouterV1(tt.callerAddress)
			}
		})
	}
}
