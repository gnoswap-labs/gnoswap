package router

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/uassert"
)

// TestRegisterInitializer tests the router upgrade system with table-driven approach
func TestRegisterInitializer(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(t *testing.T)
		initializer          func(s IRouterStore) IRouter
		callerRealm          runtime.Realm
		expectedVersion      string
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:            "register initializer is success",
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"),
			initializer:     makeMockInitializer("v1"),
			expectedVersion: "v1",
		},
		{
			name: "register multiple different initializers",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/router/new_version"),
			initializer:     makeMockInitializer("new_version"),
			expectedVersion: "v1",
		},
		{
			name: "register initializer is failed by duplicate registration",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"),
			initializer:          makeMockInitializer("v1"),
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: initializer already registered",
		},
		{
			name:                 "register initializer is failed by invalid domain path",
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/invalid"),
			initializer:          makeMockInitializer("v1"),
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: caller is not in the domain path",
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		if tt.expectedHasAbort {
			uassert.AbortsContains(t, tt.expectedAbortMessage, func() {
				RegisterInitializer(cross, tt.initializer)
			})
		} else {
			RegisterInitializer(cross, tt.initializer)

			impl := implementation.(*MockRouter)
			uassert.Equal(t, impl.Version, tt.expectedVersion)
		}
	}
}

// TestUpgradeImpl tests the router upgrade implementation
func TestUpgradeImpl(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(t *testing.T)
		packagePath          string
		callerRealm          runtime.Realm
		expectedVersion      string
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name: "upgrade impl is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/new_version"))
				RegisterInitializer(cross, makeMockInitializer("new_version"))
			},
			packagePath:     "gno.land/r/gnoswap/router/new_version",
			callerRealm:     testing.NewUserRealm(adminAddr),
			expectedVersion: "new_version",
		},
		{
			name: "upgrade impl is failed by non-admin caller",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/new_version"))
				RegisterInitializer(cross, makeMockInitializer("new_version"))
			},
			packagePath:          "gno.land/r/gnoswap/router/new_version",
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/invalid"),
			expectedVersion:      "v1",
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1ute9mjth6la3nrkeaaj4ec0nh3ypj4ngy0jnjh is not admin",
		},
		{
			name: "upgrade impl is failed by initializer not found",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			packagePath:          "gno.land/r/gnoswap/router/nonexistent",
			callerRealm:          testing.NewUserRealm(adminAddr),
			expectedVersion:      "v1",
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: initializer not found for package path:gno.land/r/gnoswap/router/nonexistent",
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		if tt.expectedHasAbort {
			uassert.AbortsContains(t, tt.expectedAbortMessage, func() {
				UpgradeImpl(cross, tt.packagePath)
			})
		} else {
			UpgradeImpl(cross, tt.packagePath)
		}

		impl := implementation.(*MockRouter)
		uassert.Equal(t, impl.Version, tt.expectedVersion)
	}
}

// TestGetImplementation tests the implementation getter
func TestGetImplementation(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(t *testing.T)
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name: "get impl is success when implementation is set",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/router/v1")
			},
		},
		{
			name:                 "get impl is failed when implementation is not set",
			expectedHasAbort:     true,
			expectedAbortMessage: "implementation is not initialized",
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		// Action
		if tt.expectedHasAbort {
			uassert.PanicsContains(t, tt.expectedAbortMessage, func() {
				getImplementation()
			})
		} else {
			impl := getImplementation()
			if impl == nil {
				t.Error("getImplementation() returned nil")
			}
		}
	}
}

// TestExactInSwapRoute tests the ExactInSwapRoute proxy function
func TestExactInSwapRoute(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		inputToken   string
		outputToken  string
		amountIn     string
		routeArr     string
		quoteArr     string
		amountOutMin string
		deadline     int64
		referrer     string
		callerRealm  runtime.Realm
	}{
		{
			name: "exact in swap route is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/router/v1")
			},
			inputToken:   "gno.land/r/gnoswap/test_token/token0",
			outputToken:  "gno.land/r/gnoswap/test_token/token1",
			amountIn:     "1000000",
			routeArr:     "gno.land/r/gnoswap/test_token/token0:gno.land/r/gnoswap/test_token/token1:3000",
			quoteArr:     "100",
			amountOutMin: "900000",
			deadline:     9999999999,
			referrer:     "",
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/router"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		ExactInSwapRoute(cross, tt.inputToken, tt.outputToken, tt.amountIn, tt.routeArr, tt.quoteArr, tt.amountOutMin, tt.deadline, tt.referrer)

		// Assert
		mockRouter := implementation.(*MockRouter)
		if mockRouter.Response.CallCount("ExactInSwapRoute") != 1 {
			t.Error("ExactInSwapRoute was not called on the implementation")
		}
	}
}

// TestExactInSingleSwapRoute tests the ExactInSingleSwapRoute proxy function
func TestExactInSingleSwapRoute(t *testing.T) {
	tests := []struct {
		name              string
		setup             func(t *testing.T)
		inputToken        string
		outputToken       string
		amountIn          string
		routeArr          string
		amountOutMin      string
		sqrtPriceLimitX96 string
		deadline          int64
		referrer          string
		callerRealm       runtime.Realm
	}{
		{
			name: "exact in single swap route is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/router/v1")
			},
			inputToken:        "gno.land/r/gnoswap/test_token/token0",
			outputToken:       "gno.land/r/gnoswap/test_token/token1",
			amountIn:          "1000000",
			routeArr:          "gno.land/r/gnoswap/test_token/token0:gno.land/r/gnoswap/test_token/token1:3000",
			amountOutMin:      "900000",
			sqrtPriceLimitX96: "0",
			deadline:          9999999999,
			referrer:          "",
			callerRealm:       testing.NewCodeRealm("gno.land/r/gnoswap/router"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		ExactInSingleSwapRoute(cross, tt.inputToken, tt.outputToken, tt.amountIn, tt.routeArr, tt.amountOutMin, tt.sqrtPriceLimitX96, tt.deadline, tt.referrer)

		// Assert
		mockRouter := implementation.(*MockRouter)
		if mockRouter.Response.CallCount("ExactInSingleSwapRoute") != 1 {
			t.Error("ExactInSingleSwapRoute was not called on the implementation")
		}
	}
}

// TestExactOutSwapRoute tests the ExactOutSwapRoute proxy function
func TestExactOutSwapRoute(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		inputToken  string
		outputToken string
		amountOut   string
		routeArr    string
		quoteArr    string
		amountInMax string
		deadline    int64
		referrer    string
		callerRealm runtime.Realm
	}{
		{
			name: "exact out swap route is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/router/v1")
			},
			inputToken:  "gno.land/r/gnoswap/test_token/token0",
			outputToken: "gno.land/r/gnoswap/test_token/token1",
			amountOut:   "1000000",
			routeArr:    "gno.land/r/gnoswap/test_token/token0:gno.land/r/gnoswap/test_token/token1:3000",
			quoteArr:    "100",
			amountInMax: "1100000",
			deadline:    9999999999,
			referrer:    "",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/router"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		ExactOutSwapRoute(cross, tt.inputToken, tt.outputToken, tt.amountOut, tt.routeArr, tt.quoteArr, tt.amountInMax, tt.deadline, tt.referrer)

		// Assert
		mockRouter := implementation.(*MockRouter)
		if mockRouter.Response.CallCount("ExactOutSwapRoute") != 1 {
			t.Error("ExactOutSwapRoute was not called on the implementation")
		}
	}
}

// TestExactOutSingleSwapRoute tests the ExactOutSingleSwapRoute proxy function
func TestExactOutSingleSwapRoute(t *testing.T) {
	tests := []struct {
		name              string
		setup             func(t *testing.T)
		inputToken        string
		outputToken       string
		amountOut         string
		routeArr          string
		amountInMax       string
		sqrtPriceLimitX96 string
		deadline          int64
		referrer          string
		callerRealm       runtime.Realm
	}{
		{
			name: "exact out single swap route is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/router/v1")
			},
			inputToken:        "gno.land/r/gnoswap/test_token/token0",
			outputToken:       "gno.land/r/gnoswap/test_token/token1",
			amountOut:         "1000000",
			routeArr:          "gno.land/r/gnoswap/test_token/token0:gno.land/r/gnoswap/test_token/token1:3000",
			amountInMax:       "1100000",
			sqrtPriceLimitX96: "0",
			deadline:          9999999999,
			referrer:          "",
			callerRealm:       testing.NewCodeRealm("gno.land/r/gnoswap/router"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		ExactOutSingleSwapRoute(cross, tt.inputToken, tt.outputToken, tt.amountOut, tt.routeArr, tt.amountInMax, tt.sqrtPriceLimitX96, tt.deadline, tt.referrer)

		// Assert
		mockRouter := implementation.(*MockRouter)
		if mockRouter.Response.CallCount("ExactOutSingleSwapRoute") != 1 {
			t.Error("ExactOutSingleSwapRoute was not called on the implementation")
		}
	}
}

// TestDrySwapRoute tests the DrySwapRoute proxy function
func TestDrySwapRoute(t *testing.T) {
	tests := []struct {
		name             string
		setup            func(t *testing.T)
		inputToken       string
		outputToken      string
		specifiedAmount  string
		swapTypeStr      string
		strRouteArr      string
		quoteArr         string
		tokenAmountLimit string
		callerRealm      runtime.Realm
	}{
		{
			name: "dry swap route is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/router/v1")
			},
			inputToken:       "gno.land/r/gnoswap/test_token/token0",
			outputToken:      "gno.land/r/gnoswap/test_token/token1",
			specifiedAmount:  "1000000",
			swapTypeStr:      "EXACT_IN",
			strRouteArr:      "gno.land/r/gnoswap/test_token/token0:gno.land/r/gnoswap/test_token/token1:3000",
			quoteArr:         "100",
			tokenAmountLimit: "900000",
			callerRealm:      testing.NewCodeRealm("gno.land/r/gnoswap/router"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockRouter := implementation.(*MockRouter)
		mockRouter.Response.Set("DrySwapRoute", "1000000", "1000000", true)

		testing.SetRealm(tt.callerRealm)

		// Action
		DrySwapRoute(tt.inputToken, tt.outputToken, tt.specifiedAmount, tt.swapTypeStr, tt.strRouteArr, tt.quoteArr, tt.tokenAmountLimit)

		// Assert
		if mockRouter.Response.CallCount("DrySwapRoute") != 1 {
			t.Error("DrySwapRoute was not called on the implementation")
		}
	}
}

// TestSwapCallback tests the SwapCallback proxy function
func TestSwapCallback(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		token0Path   string
		token1Path   string
		amount0Delta int64
		amount1Delta int64
		payer        address
		callerRealm  runtime.Realm
	}{
		{
			name: "swap callback is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/router/v1")
			},
			token0Path:   "gno.land/r/gnoswap/test_token/token0",
			token1Path:   "gno.land/r/gnoswap/test_token/token1",
			amount0Delta: 1000000,
			amount1Delta: -1000000,
			payer:        "gno1...",
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/router"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockRouter := implementation.(*MockRouter)
		mockRouter.Response.Set("SwapCallback", nil)

		testing.SetRealm(tt.callerRealm)

		// Action
		SwapCallback(tt.token0Path, tt.token1Path, tt.amount0Delta, tt.amount1Delta, tt.payer)

		// Assert
		if mockRouter.Response.CallCount("SwapCallback") != 1 {
			t.Error("SwapCallback was not called on the implementation")
		}
	}
}

// TestGetSwapFee tests the GetSwapFee proxy function
func TestGetSwapFee(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		expectedFee uint64
	}{
		{
			name: "get swap fee is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/router/v1")
			},
			expectedFee: 100,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockRouter := implementation.(*MockRouter)
		mockRouter.Response.Set("GetSwapFee", tt.expectedFee)

		// Action
		fee := GetSwapFee()

		// Assert
		if mockRouter.Response.CallCount("GetSwapFee") != 1 {
			t.Error("GetSwapFee was not called on the implementation")
		}
		if fee != tt.expectedFee {
			t.Errorf("GetSwapFee() = %v, want %v", fee, tt.expectedFee)
		}
	}
}

// TestSetSwapFee tests the SetSwapFee proxy function
func TestSetSwapFee(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		fee         uint64
		callerRealm runtime.Realm
	}{
		{
			name: "set swap fee is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/router/v1")
			},
			fee:         200,
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/router"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		SetSwapFee(cross, tt.fee)

		// Assert
		mockRouter := implementation.(*MockRouter)
		if mockRouter.Response.CallCount("SetSwapFee") != 1 {
			t.Error("SetSwapFee was not called on the implementation")
		}
	}
}
