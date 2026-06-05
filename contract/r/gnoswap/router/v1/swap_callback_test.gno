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
				initRouterTest(cur, t)
				CreatePoolWithoutFee(cur, t)
				// SwapCallback runs under the router v1 realm, so the GRC20
				// transfer actor (and the payer == routerAddr check) resolves to
				// routerImplAddr. Fund and self-approve that address.
				TokenFaucet(cur, t, barPath, routerImplAddr)
				TokenFaucet(cur, t, bazPath, routerImplAddr)
				TokenApprove(cur, t, barPath, routerImplAddr, routerImplAddr, maxApprove)
				TokenApprove(cur, t, bazPath, routerImplAddr, routerImplAddr, maxApprove)
				return routerImplAddr
			},
			amount0Delta:    "1000",
			amount1Delta:    "0",
			callerRealmPath: "gno.land/r/gnoswap/router/v1",
			shouldError:     false,
		},
		{
			name: "success with token1 payment",
			setupFunc: func(cur realm, t *testing.T) address {
				initRouterTest(cur, t)
				CreatePoolWithoutFee(cur, t)
				TokenFaucet(cur, t, barPath, routerImplAddr)
				TokenFaucet(cur, t, bazPath, routerImplAddr)
				TokenApprove(cur, t, barPath, routerImplAddr, routerImplAddr, maxApprove)
				TokenApprove(cur, t, bazPath, routerImplAddr, routerImplAddr, maxApprove)
				return routerImplAddr
			},
			amount0Delta:    "0",
			amount1Delta:    "1000",
			callerRealmPath: "gno.land/r/gnoswap/router/v1",
			shouldError:     false,
		},
		{
			name: "success with both deltas zero",
			setupFunc: func(cur realm, t *testing.T) address {
				initRouterTest(cur, t)
				CreatePoolWithoutFee(cur, t)
				return routerImplAddr
			},
			amount0Delta:    "0",
			amount1Delta:    "0",
			callerRealmPath: "gno.land/r/gnoswap/router/v1",
			shouldError:     false,
		},
		{
			name: "success with user as payer",
			setupFunc: func(cur realm, t *testing.T) address {
				initRouterTest(cur, t)
				CreatePoolWithoutFee(cur, t)
				testUser := testutils.TestAddress("testUser")
				TokenFaucet(cur, t, barPath, testUser)
				TokenFaucet(cur, t, bazPath, testUser)
				// The TransferFrom spender is the router v1 realm (the callback
				// caller), so approve routerImplAddr, not the router domain addr.
				TokenApprove(cur, t, barPath, testUser, routerImplAddr, maxApprove)
				TokenApprove(cur, t, bazPath, testUser, routerImplAddr, maxApprove)
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
				initRouterTest(cur, t)
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
				initRouterTest(cur, t)
				CreatePoolWithoutFee(cur, t)
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
			initPoolTest(cur, t)
			initRouterTest(cur, t)
			// Setup
			payer := tt.setupFunc(cur, t)

			// Set caller realm
			testing.SetRealm(testing.NewCodeRealm(tt.callerRealmPath))

			// Execute
			if tt.shouldError {
				uassert.AbortsContains(t, cur, tt.expectedErrorMsg, func() {
					mockInstanceSwapCallback(
						cross(cur),
						barPath,
						bazPath,
						tt.amount0Delta,
						tt.amount1Delta,
						payer,
					)
				})
			} else {
				err := mockInstanceSwapCallback(
					cross(cur),
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

// TestSwapCallback_assertIsRouterImplementation tests the assertIsRouterImplementation function with various caller types
func TestSwapCallback_assertIsRouterImplementation(cur realm, t *testing.T) {
	tests := []struct {
		name             string
		callerAddress    address
		shouldError      bool
		expectedErrorMsg string
	}{
		{
			name:          "valid caller from router v1",
			callerAddress: routerImplAddr,
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
					assertIsRouterImplementation(tt.callerAddress)
				})
			} else {
				// Should not panic
				assertIsRouterImplementation(tt.callerAddress)
			}
		})
	}
}
