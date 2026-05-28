package v1

import (
	"chain"
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
)

// TestSwapCallback tests the SwapCallback function with various scenarios
func TestSwapCallback(cur realm, t *testing.T) {
	tests := []struct {
		name             string
		setupFunc        func(cur realm, t *testing.T) address // returns payer address
		amount0Delta     string
		amount1Delta     string
		callerRealmPath  string
		shouldError      bool
		expectedErrorMsg string
	}{
		{
			name: "success with token0 payment",
			setupFunc: func(cur realm, t *testing.T) address {
				initRouterTest(t)
				CreatePoolWithoutFee(cur, t)
				MakeMintPositionWithoutFee(cur, t)
				TokenFaucet(cur, t, barPath, routerAddr)
				TokenFaucet(cur, t, bazPath, routerAddr)
				return routerAddr
			},
			amount0Delta:    "1000",
			amount1Delta:    "0",
			callerRealmPath: "gno.land/r/gnoswap/router/v1",
			shouldError:     false,
		},
		{
			name: "success with token1 payment",
			setupFunc: func(cur realm, t *testing.T) address {
				initRouterTest(t)
				CreatePoolWithoutFee(cur, t)
				MakeMintPositionWithoutFee(cur, t)
				TokenFaucet(cur, t, barPath, routerAddr)
				TokenFaucet(cur, t, bazPath, routerAddr)
				return routerAddr
			},
			amount0Delta:    "0",
			amount1Delta:    "1000",
			callerRealmPath: "gno.land/r/gnoswap/router/v1",
			shouldError:     false,
		},
		{
			name: "success with both deltas zero",
			setupFunc: func(cur realm, t *testing.T) address {
				initRouterTest(t)
				CreatePoolWithoutFee(cur, t)
				return routerAddr
			},
			amount0Delta:    "0",
			amount1Delta:    "0",
			callerRealmPath: "gno.land/r/gnoswap/router/v1",
			shouldError:     false,
		},
		{
			name: "success with user as payer",
			setupFunc: func(cur realm, t *testing.T) address {
				initRouterTest(t)
				CreatePoolWithoutFee(cur, t)
				MakeMintPositionWithoutFee(cur, t)
				testUser := testutils.TestAddress("testUser")
				TokenFaucet(cur, t, barPath, testUser)
				TokenFaucet(cur, t, bazPath, testUser)
				TokenApprove(cur, t, barPath, testUser, routerAddr, maxApprove)
				TokenApprove(cur, t, bazPath, testUser, routerAddr, maxApprove)
				return testUser
			},
			amount0Delta:    "1000",
			amount1Delta:    "0",
			callerRealmPath: "gno.land/r/gnoswap/router/v1",
			shouldError:     false,
		},
		{
			name: "fail with invalid caller",
			setupFunc: func(cur realm, t *testing.T) address {
				initRouterTest(t)
				CreatePoolWithoutFee(cur, t)
				return routerAddr
			},
			amount0Delta:     "1000",
			amount1Delta:     "0",
			callerRealmPath:  "gno.land/r/unauthorized/contract",
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-ROUTER-009]",
		},
		{
			name: "fail with insufficient balance",
			setupFunc: func(cur realm, t *testing.T) address {
				initRouterTest(t)
				CreatePoolWithoutFee(cur, t)
				MakeMintPositionWithoutFee(cur, t)
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Setup
			payer := tt.setupFunc(t)

			// Set caller realm
			testing.SetRealm(testing.NewCodeRealm(tt.callerRealmPath))

			// Execute
			if tt.shouldError {
				uassert.AbortsContains(t, cur, tt.expectedErrorMsg, func() {
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
func TestSwapCallback_AssertIsRouterV1(cur realm, t *testing.T) {
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
			name:             "invalid caller from router v2",
			callerAddress:    chain.PackageAddress("gno.land/r/gnoswap/router/v2"),
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-ROUTER-009] unauthorized caller",
		},
		{
			name:             "invalid caller from router domain",
			callerAddress:    chain.PackageAddress("gno.land/r/gnoswap/router"),
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-ROUTER-009] unauthorized caller",
		},
		{
			name:             "invalid caller from unauthorized contract",
			callerAddress:    testutils.TestAddress("unauthorized"),
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-ROUTER-009]",
		},
		{
			name:             "invalid caller from user realm",
			callerAddress:    testutils.TestAddress("maliciousUser"),
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-ROUTER-009]",
		},
		{
			name:             "invalid caller from different contract",
			callerAddress:    testutils.TestAddress("different"),
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-ROUTER-009]",
		},
		{
			name:             "invalid caller from pool contract",
			callerAddress:    poolAddr,
			shouldError:      true,
			expectedErrorMsg: "[GNOSWAP-ROUTER-009]",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Execute and verify
			if tt.shouldError {
				uassert.PanicsContains(t, cur, tt.expectedErrorMsg, func() {
					assertIsRouterV1(tt.callerAddress)
				})
			} else {
				// Should not panic
				assertIsRouterV1(tt.callerAddress)
			}
		})
	}
}
