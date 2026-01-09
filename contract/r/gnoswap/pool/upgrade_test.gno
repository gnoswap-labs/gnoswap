package pool

import (
	"chain/runtime"
	"errors"
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
)

// TestRegisterInitializer tests the pool upgrade system with table-driven approach
func TestRegisterInitializer(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(t *testing.T)
		initializer          func(s IPoolStore) IPool
		callerRealm          runtime.Realm
		expectedVersion      string
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:            "register initializer is success",
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"),
			initializer:     makeMockInitializer("v1"),
			expectedVersion: "v1",
		},
		{
			name: "register multiple different initializers",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/pool/new_version"),
			initializer:     makeMockInitializer("new_version"),
			expectedVersion: "v1",
		},
		{
			name: "register initializer is failed by duplicate registration",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"),
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

			impl := implementation.(*MockPool)
			uassert.Equal(t, impl.Version, tt.expectedVersion)
		}
	}
}

// TestUpgradeImpl tests the pool upgrade implementation
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
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/new_version"))
				RegisterInitializer(cross, makeMockInitializer("new_version"))
			},
			packagePath:     "gno.land/r/gnoswap/pool/new_version",
			callerRealm:     testing.NewUserRealm(adminAddr),
			expectedVersion: "new_version",
		},
		{
			name: "upgrade impl is failed by non-admin caller",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/new_version"))
				RegisterInitializer(cross, makeMockInitializer("new_version"))
			},
			packagePath:          "gno.land/r/gnoswap/pool/new_version",
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/invalid"),
			expectedVersion:      "v1",
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1ute9mjth6la3nrkeaaj4ec0nh3ypj4ngy0jnjh is not admin",
		},
		{
			name: "upgrade impl is failed by initializer not found",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			packagePath:          "gno.land/r/gnoswap/pool/nonexistent",
			callerRealm:          testing.NewUserRealm(adminAddr),
			expectedVersion:      "v1",
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: initializer not found for package path:gno.land/r/gnoswap/pool/nonexistent",
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

		impl := implementation.(*MockPool)
		uassert.Equal(t, impl.Version, tt.expectedVersion)
	}
}

// TestGetImpl tests the implementation getter
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
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
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

// TestCreatePool tests the CreatePool proxy function
func TestCreatePool(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		token0Path   string
		token1Path   string
		fee          uint32
		sqrtPriceX96 string
		callerRealm  runtime.Realm
	}{
		{
			name: "create pool is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			token0Path:   "gno.land/r/gnoswap/test_token/token0",
			token1Path:   "gno.land/r/gnoswap/test_token/token1",
			fee:          3000,
			sqrtPriceX96: "79228162514264337593543950336",
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
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
		CreatePool(cross, tt.token0Path, tt.token1Path, tt.fee, tt.sqrtPriceX96)

		// Assert - verify that the mock pool's CreatePool was called
		mPool := implementation.(*MockPool)
		if mPool.Response.CallCount("CreatePool") != 1 {
			t.Error("CreatePool was not called on the implementation")
		}
	}
}

// TestMint tests the Mint proxy function
func TestMint(t *testing.T) {
	tests := []struct {
		name            string
		setup           func(t *testing.T)
		token0Path      string
		token1Path      string
		fee             uint32
		tickLower       int32
		tickUpper       int32
		liquidityAmount string
		positionCaller  address
		callerRealm     runtime.Realm
		expectedAmount0 string
		expectedAmount1 string
	}{
		{
			name: "mint is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			token0Path:      "gno.land/r/gnoswap/test_token/token0",
			token1Path:      "gno.land/r/gnoswap/test_token/token1",
			fee:             3000,
			tickLower:       -100,
			tickUpper:       100,
			liquidityAmount: "1000000",
			positionCaller:  "gno1...",
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedAmount0: "0",
			expectedAmount1: "0",
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		testing.SetRealm(tt.callerRealm)
		mockPool := implementation.(*MockPool)

		// Action
		Mint(cross, tt.token0Path, tt.token1Path, tt.fee, tt.tickLower, tt.tickUpper, tt.liquidityAmount, tt.positionCaller)

		// Assert
		if mockPool.Response.CallCount("Mint") != 1 {
			t.Error("Mint was not called on the implementation")
		}
	}
}

// TestBurn tests the Burn proxy function
func TestBurn(t *testing.T) {
	tests := []struct {
		name            string
		setup           func(t *testing.T)
		token0Path      string
		token1Path      string
		fee             uint32
		tickLower       int32
		tickUpper       int32
		liquidityAmount string
		positionCaller  address
		callerRealm     runtime.Realm
		expectedAmount0 string
		expectedAmount1 string
	}{
		{
			name: "burn is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			token0Path:      "gno.land/r/gnoswap/test_token/token0",
			token1Path:      "gno.land/r/gnoswap/test_token/token1",
			fee:             3000,
			tickLower:       -100,
			tickUpper:       100,
			liquidityAmount: "1000000",
			positionCaller:  "gno1...",
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedAmount0: "0",
			expectedAmount1: "0",
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
		Burn(cross, tt.token0Path, tt.token1Path, tt.fee, tt.tickLower, tt.tickUpper, tt.liquidityAmount, tt.positionCaller)

		// Assert
		mockPool := implementation.(*MockPool)
		if mockPool.Response.CallCount("Burn") != 1 {
			t.Error("Burn was not called on the implementation")
		}
	}
}

// TestCollect tests the Collect proxy function
func TestCollect(t *testing.T) {
	tests := []struct {
		name             string
		setup            func(t *testing.T)
		token0Path       string
		token1Path       string
		fee              uint32
		recipient        address
		tickLower        int32
		tickUpper        int32
		amount0Requested string
		amount1Requested string
		callerRealm      runtime.Realm
		expectedAmount0  string
		expectedAmount1  string
	}{
		{
			name: "collect is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			token0Path:       "gno.land/r/gnoswap/test_token/token0",
			token1Path:       "gno.land/r/gnoswap/test_token/token1",
			fee:              3000,
			recipient:        "gno1...",
			tickLower:        -100,
			tickUpper:        100,
			amount0Requested: "1000000",
			amount1Requested: "1000000",
			callerRealm:      testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedAmount0:  "0",
			expectedAmount1:  "0",
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
		Collect(cross, tt.token0Path, tt.token1Path, tt.fee, tt.recipient, tt.tickLower, tt.tickUpper, tt.amount0Requested, tt.amount1Requested)

		// Assert
		mockPool := implementation.(*MockPool)
		if mockPool.Response.CallCount("Collect") != 1 {
			t.Error("Collect was not called on the implementation")
		}
	}
}

// TestCollectProtocol tests the CollectProtocol proxy function
func TestCollectProtocol(t *testing.T) {
	tests := []struct {
		name             string
		setup            func(t *testing.T)
		token0Path       string
		token1Path       string
		fee              uint32
		recipient        address
		amount0Requested string
		amount1Requested string
		callerRealm      runtime.Realm
		expectedAmount0  string
		expectedAmount1  string
	}{
		{
			name: "collect protocol is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			token0Path:       "gno.land/r/gnoswap/test_token/token0",
			token1Path:       "gno.land/r/gnoswap/test_token/token1",
			fee:              3000,
			recipient:        "gno1...",
			amount0Requested: "1000000",
			amount1Requested: "1000000",
			callerRealm:      testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedAmount0:  "0",
			expectedAmount1:  "0",
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
		CollectProtocol(cross, tt.token0Path, tt.token1Path, tt.fee, tt.recipient, tt.amount0Requested, tt.amount1Requested)

		// Assert
		mockPool := implementation.(*MockPool)
		if mockPool.Response.CallCount("CollectProtocol") != 1 {
			t.Error("CollectProtocol was not called on the implementation")
		}
	}
}

// TestSwap tests the Swap proxy function
func TestSwap(t *testing.T) {
	tests := []struct {
		name              string
		setup             func(t *testing.T)
		token0Path        string
		token1Path        string
		fee               uint32
		recipient         address
		zeroForOne        bool
		amountSpecified   string
		sqrtPriceLimitX96 string
		caller            address
		callerRealm       runtime.Realm
		expectedAmount0   string
		expectedAmount1   string
	}{
		{
			name: "swap is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			token0Path:        "gno.land/r/gnoswap/test_token/token0",
			token1Path:        "gno.land/r/gnoswap/test_token/token1",
			fee:               3000,
			recipient:         "gno1...",
			zeroForOne:        true,
			amountSpecified:   "1000000",
			sqrtPriceLimitX96: "79228162514264337593543950336",
			caller:            "gno1...",
			callerRealm:       testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedAmount0:   "0",
			expectedAmount1:   "0",
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
		Swap(cross, tt.token0Path, tt.token1Path, tt.fee, tt.recipient, tt.zeroForOne, tt.amountSpecified, tt.sqrtPriceLimitX96, tt.caller, func(cur realm, amount0Delta int64, amount1Delta int64, _ *CallbackMarker) error {
			return nil
		})

		// Assert
		mockPool := implementation.(*MockPool)
		if mockPool.Response.CallCount("Swap") != 1 {
			t.Error("Swap was not called on the implementation")
		}
	}
}

// TestDrySwap tests the DrySwap proxy function
func TestDrySwap(t *testing.T) {
	tests := []struct {
		name              string
		setup             func(t *testing.T)
		token0Path        string
		token1Path        string
		fee               uint32
		zeroForOne        bool
		amountSpecified   string
		sqrtPriceLimitX96 string
		callerRealm       runtime.Realm
		expectedAmount0   string
		expectedAmount1   string
	}{
		{
			name: "dry swap is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			token0Path:        "gno.land/r/gnoswap/test_token/token0",
			token1Path:        "gno.land/r/gnoswap/test_token/token1",
			fee:               3000,
			zeroForOne:        true,
			amountSpecified:   "1000000",
			sqrtPriceLimitX96: "79228162514264337593543950336",
			callerRealm:       testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedAmount0:   "0",
			expectedAmount1:   "0",
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
		DrySwap(tt.token0Path, tt.token1Path, tt.fee, tt.zeroForOne, tt.amountSpecified, tt.sqrtPriceLimitX96)

		// Assert
		mockPool := implementation.(*MockPool)
		if mockPool.Response.CallCount("DrySwap") != 1 {
			t.Error("DrySwap was not called on the implementation")
		}
	}
}

// TestSetFeeProtocol tests the SetFeeProtocol proxy function
func TestSetFeeProtocol(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		feeProtocol0 uint8
		feeProtocol1 uint8
		callerRealm  runtime.Realm
	}{
		{
			name: "set fee protocol is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			feeProtocol0: 10,
			feeProtocol1: 20,
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
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
		SetFeeProtocol(cross, tt.feeProtocol0, tt.feeProtocol1)

		// Assert - no return value to check, just verify no panic
		mockPool := implementation.(*MockPool)
		if mockPool.Response.CallCount("SetFeeProtocol") != 1 {
			t.Error("SetFeeProtocol was not called on the implementation")
		}
	}
}

// TestGetSlot0SqrtPriceX96 tests the GetSlot0SqrtPriceX96 proxy function
func TestGetSlot0SqrtPriceX96(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		poolPath     string
		callerRealm  runtime.Realm
		expectedSqrt *u256.Uint
	}{
		{
			name: "get slot0 sqrt price x96 is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:     "mock_pool_path",
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedSqrt: u256.NewUint(0),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}
		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetSlot0SqrtPriceX96", tt.expectedSqrt)
		testing.SetRealm(tt.callerRealm)

		// Action
		sqrtPrice := GetSlot0SqrtPriceX96(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetSlot0SqrtPriceX96") != 1 {
			t.Error("GetSlot0SqrtPriceX96 was not called on the implementation")
		}
		if sqrtPrice == nil {
			t.Error("GetSlot0SqrtPriceX96() returned nil")
		}
	}
}

// TestGetSlot0Tick tests the GetSlot0Tick proxy function
func TestGetSlot0Tick(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		poolPath     string
		callerRealm  runtime.Realm
		expectedTick int32
	}{
		{
			name: "get slot0 tick is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:     "mock_pool_path",
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedTick: 0,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetSlot0Tick", tt.expectedTick)
		testing.SetRealm(tt.callerRealm)

		// Action
		tick := GetSlot0Tick(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetSlot0Tick") != 1 {
			t.Error("GetSlot0Tick was not called on the implementation")
		}
		if tick != tt.expectedTick {
			t.Errorf("GetSlot0Tick() = %v, want %v", tick, tt.expectedTick)
		}
	}
}

// TestGetLiquidity tests the GetLiquidity proxy function
func TestGetLiquidity(t *testing.T) {
	tests := []struct {
		name              string
		setup             func(t *testing.T)
		poolPath          string
		callerRealm       runtime.Realm
		expectedLiquidity string
	}{
		{
			name: "get liquidity is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:          "mock_pool_path",
			callerRealm:       testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedLiquidity: "0",
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetLiquidity", tt.expectedLiquidity)

		testing.SetRealm(tt.callerRealm)

		// Action
		liquidity := GetLiquidity(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetLiquidity") != 1 {
			t.Error("GetLiquidity was not called on the implementation")
		}
		if liquidity != tt.expectedLiquidity {
			t.Errorf("GetLiquidity() = %v, want %v", liquidity, tt.expectedLiquidity)
		}
	}
}

// TestGetBalanceToken0 tests the GetBalanceToken0 proxy function
func TestGetBalanceToken0(t *testing.T) {
	tests := []struct {
		name            string
		setup           func(t *testing.T)
		poolPath        string
		callerRealm     runtime.Realm
		expectedBalance string
	}{
		{
			name: "get balance token0 is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:        "mock_pool_path",
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedBalance: "0",
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetBalanceToken0", tt.expectedBalance)

		testing.SetRealm(tt.callerRealm)

		// Action
		balance := GetBalanceToken0(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetBalanceToken0") != 1 {
			t.Error("GetBalanceToken0 was not called on the implementation")
		}
		if balance != tt.expectedBalance {
			t.Errorf("GetBalanceToken0() = %v, want %v", balance, tt.expectedBalance)
		}
	}
}

// TestGetBalanceToken1 tests the GetBalanceToken1 proxy function
func TestGetBalanceToken1(t *testing.T) {
	tests := []struct {
		name            string
		setup           func(t *testing.T)
		poolPath        string
		callerRealm     runtime.Realm
		expectedBalance string
	}{
		{
			name: "get balance token1 is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:        "mock_pool_path",
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedBalance: "0",
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetBalanceToken1", tt.expectedBalance)

		testing.SetRealm(tt.callerRealm)

		// Action
		balance := GetBalanceToken1(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetBalanceToken1") != 1 {
			t.Error("GetBalanceToken1 was not called on the implementation")
		}
		if balance != tt.expectedBalance {
			t.Errorf("GetBalanceToken1() = %v, want %v", balance, tt.expectedBalance)
		}
	}
}

// TestGetFeeGrowthGlobalX128 tests the GetFeeGrowthGlobalX128 proxy function
func TestGetFeeGrowthGlobalX128(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		poolPath     string
		callerRealm  runtime.Realm
		expectedFee0 *u256.Uint
		expectedFee1 *u256.Uint
	}{
		{
			name: "get fee growth global x128 is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:     "mock_pool_path",
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedFee0: u256.NewUint(0),
			expectedFee1: u256.NewUint(0),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetFeeGrowthGlobalX128", tt.expectedFee0, tt.expectedFee1)

		testing.SetRealm(tt.callerRealm)

		// Action
		fee0, fee1 := GetFeeGrowthGlobalX128(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetFeeGrowthGlobalX128") != 1 {
			t.Error("GetFeeGrowthGlobalX128 was not called on the implementation")
		}
		if fee0 == nil || fee1 == nil {
			t.Error("GetFeeGrowthGlobalX128() returned nil")
		}
	}
}

// TestGetPositionFeeGrowthInsideLastX128 tests the GetPositionFeeGrowthInsideLastX128 proxy function
func TestGetPositionFeeGrowthInsideLastX128(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		poolPath     string
		key          string
		callerRealm  runtime.Realm
		expectedFee0 *u256.Uint
		expectedFee1 *u256.Uint
	}{
		{
			name: "get position fee growth inside last x128 is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:     "mock_pool_path",
			key:          "mock_key",
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedFee0: u256.NewUint(0),
			expectedFee1: u256.NewUint(0),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetPositionFeeGrowthInsideLastX128", tt.expectedFee0, tt.expectedFee1)

		testing.SetRealm(tt.callerRealm)

		// Action
		fee0, fee1 := GetPositionFeeGrowthInsideLastX128(tt.poolPath, tt.key)

		// Assert
		if mockPool.Response.CallCount("GetPositionFeeGrowthInsideLastX128") != 1 {
			t.Error("GetPositionFeeGrowthInsideLastX128 was not called on the implementation")
		}
		if fee0 == nil || fee1 == nil {
			t.Error("GetPositionFeeGrowthInsideLastX128() returned nil")
		}
	}
}

// TestGetObservation tests the GetObservation proxy function
func TestGetObservation(t *testing.T) {
	tests := []struct {
		name              string
		setup             func(t *testing.T)
		poolPath          string
		secondsAgo        int64
		callerRealm       runtime.Realm
		expectedTick      int64
		expectedSqrt      string
		expectedLiquidity string
		expectedTimestamp int64
	}{
		{
			name: "get observation is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:          "mock_pool_path",
			secondsAgo:        3600,
			callerRealm:       testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedTick:      0,
			expectedSqrt:      "0",
			expectedLiquidity: "0",
			expectedTimestamp: 0,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetObservation", tt.expectedTick, tt.expectedSqrt, tt.expectedLiquidity, tt.expectedTimestamp)

		testing.SetRealm(tt.callerRealm)

		// Action
		tick, sqrt, liquidity, timestamp := GetObservation(tt.poolPath, tt.secondsAgo)

		// Assert
		if mockPool.Response.CallCount("GetObservation") != 1 {
			t.Error("GetObservation was not called on the implementation")
		}
		if tick != tt.expectedTick {
			t.Errorf("GetObservation() tick = %v, want %v", tick, tt.expectedTick)
		}
		if sqrt != tt.expectedSqrt {
			t.Errorf("GetObservation() sqrt = %v, want %v", sqrt, tt.expectedSqrt)
		}
		if liquidity != tt.expectedLiquidity {
			t.Errorf("GetObservation() liquidity = %v, want %v", liquidity, tt.expectedLiquidity)
		}
		if timestamp != tt.expectedTimestamp {
			t.Errorf("GetObservation() timestamp = %v, want %v", timestamp, tt.expectedTimestamp)
		}
	}
}

// TestExistsPoolPath tests the ExistsPoolPath proxy function
func TestExistsPoolPath(t *testing.T) {
	tests := []struct {
		name           string
		setup          func(t *testing.T)
		poolPath       string
		callerRealm    runtime.Realm
		expectedExists bool
	}{
		{
			name: "exists pool path is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:       "mock_pool_path",
			callerRealm:    testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedExists: true,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("ExistsPoolPath", tt.expectedExists)

		testing.SetRealm(tt.callerRealm)

		// Action
		exists := ExistsPoolPath(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("ExistsPoolPath") != 1 {
			t.Error("ExistsPoolPath was not called on the implementation")
		}
		if exists != tt.expectedExists {
			t.Errorf("ExistsPoolPath() = %v, want %v", exists, tt.expectedExists)
		}
	}
}

// TestGetTWAP tests the GetTWAP proxy function
func TestGetTWAP(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		poolPath     string
		secondsAgo   uint32
		callerRealm  runtime.Realm
		expectedTWAP int32
	}{
		{
			name: "api get twap is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:     "mock_pool_path",
			secondsAgo:   3600,
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedTWAP: 0,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetTWAP", tt.expectedTWAP, errors.New(""))

		testing.SetRealm(tt.callerRealm)

		// Action
		twap, _ := GetTWAP(tt.poolPath, tt.secondsAgo)

		// Assert
		if mockPool.Response.CallCount("GetTWAP") != 1 {
			t.Error("GetTWAP was not called on the implementation")
		}
		if twap != tt.expectedTWAP {
			t.Errorf("GetTWAP() = %v, want %v", twap, tt.expectedTWAP)
		}
	}
}

// TestSetPoolCreationFee tests the SetPoolCreationFee proxy function
func TestSetPoolCreationFee(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		fee         int64
		callerRealm runtime.Realm
	}{
		{
			name: "set pool creation fee is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			fee:         1000000,
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
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
		SetPoolCreationFee(cross, tt.fee)

		// Assert
		mockPool := implementation.(*MockPool)
		if mockPool.Response.CallCount("SetPoolCreationFee") != 1 {
			t.Error("SetPoolCreationFee was not called on the implementation")
		}
	}
}

// TestIncreaseObservationCardinalityLimit tests the IncreaseObservationCardinalityLimit proxy function
func TestIncreaseObservationCardinalityLimit(t *testing.T) {
	tests := []struct {
		name            string
		setup           func(t *testing.T)
		token0Path      string
		token1Path      string
		fee             uint32
		cardinalityNext uint16
		callerRealm     runtime.Realm
	}{
		{
			name: "increase observation cardinality limit is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			token0Path:      "gno.land/r/gnoswap/test_token/token0",
			token1Path:      "gno.land/r/gnoswap/test_token/token1",
			fee:             3000,
			cardinalityNext: 100,
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
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
		IncreaseObservationCardinalityLimit(cross, tt.token0Path, tt.token1Path, tt.fee, tt.cardinalityNext)

		// Assert
		mockPool := implementation.(*MockPool)
		if mockPool.Response.CallCount("IncreaseObservationCardinalityLimit") != 1 {
			t.Error("IncreaseObservationCardinalityLimit was not called on the implementation")
		}
	}
}

// TestSetWithdrawalFee tests the SetWithdrawalFee proxy function
func TestSetWithdrawalFee(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		fee         uint64
		callerRealm runtime.Realm
	}{
		{
			name: "set withdrawal fee is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			fee:         100,
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
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
		SetWithdrawalFee(cross, tt.fee)

		// Assert
		mockPool := implementation.(*MockPool)
		if mockPool.Response.CallCount("SetWithdrawalFee") != 1 {
			t.Error("SetWithdrawalFee was not called on the implementation")
		}
	}
}

// TestHandleWithdrawalFee tests the HandleWithdrawalFee proxy function
func TestHandleWithdrawalFee(t *testing.T) {
	tests := []struct {
		name            string
		setup           func(t *testing.T)
		positionId      uint64
		token0Path      string
		amount0         string
		token1Path      string
		amount1         string
		poolPath        string
		positionCaller  address
		callerRealm     runtime.Realm
		expectedAmount0 string
		expectedAmount1 string
	}{
		{
			name: "handle withdrawal fee is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			positionId:      1,
			token0Path:      "gno.land/r/gnoswap/test_token/token0",
			amount0:         "1000000",
			token1Path:      "gno.land/r/gnoswap/test_token/token1",
			amount1:         "1000000",
			poolPath:        "mock_pool_path",
			positionCaller:  "gno1...",
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedAmount0: "990000",
			expectedAmount1: "990000",
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("HandleWithdrawalFee", tt.expectedAmount0, tt.expectedAmount1)

		testing.SetRealm(tt.callerRealm)

		// Action
		amount0, amount1 := HandleWithdrawalFee(cross, tt.positionId, tt.token0Path, tt.amount0, tt.token1Path, tt.amount1, tt.poolPath, tt.positionCaller)

		// Assert
		if mockPool.Response.CallCount("HandleWithdrawalFee") != 1 {
			t.Error("HandleWithdrawalFee was not called on the implementation")
		}
		if amount0 != tt.expectedAmount0 {
			t.Errorf("HandleWithdrawalFee() amount0 = %v, want %v", amount0, tt.expectedAmount0)
		}
		if amount1 != tt.expectedAmount1 {
			t.Errorf("HandleWithdrawalFee() amount1 = %v, want %v", amount1, tt.expectedAmount1)
		}
	}
}

// TestSetSwapEndHook tests the SetSwapEndHook proxy function
func TestSetSwapEndHook(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		callerRealm runtime.Realm
	}{
		{
			name: "set swap end hook is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
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
		SetSwapEndHook(cross, func(cur realm, poolPath string) error {
			return nil
		})

		// Assert
		mockPool := implementation.(*MockPool)
		if mockPool.Response.CallCount("SetSwapEndHook") != 1 {
			t.Error("SetSwapEndHook was not called on the implementation")
		}
	}
}

// TestSetSwapStartHook tests the SetSwapStartHook proxy function
func TestSetSwapStartHook(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		callerRealm runtime.Realm
	}{
		{
			name: "set swap start hook is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
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
		SetSwapStartHook(cross, func(cur realm, poolPath string, timestamp int64) {})

		// Assert
		mockPool := implementation.(*MockPool)
		if mockPool.Response.CallCount("SetSwapStartHook") != 1 {
			t.Error("SetSwapStartHook was not called on the implementation")
		}
	}
}

// TestSetTickCrossHook tests the SetTickCrossHook proxy function
func TestSetTickCrossHook(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		callerRealm runtime.Realm
	}{
		{
			name: "set tick cross hook is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
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
		SetTickCrossHook(cross, func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {})

		// Assert
		mockPool := implementation.(*MockPool)
		if mockPool.Response.CallCount("SetTickCrossHook") != 1 {
			t.Error("SetTickCrossHook was not called on the implementation")
		}
	}
}

// TestGetPoolCreationFee tests the GetPoolCreationFee proxy function
func TestGetPoolCreationFee(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		expectedFee int64
	}{
		{
			name: "get pool creation fee is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			expectedFee: 1000000,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetPoolCreationFee", tt.expectedFee)

		// Action
		fee := GetPoolCreationFee()

		// Assert
		if mockPool.Response.CallCount("GetPoolCreationFee") != 1 {
			t.Error("GetPoolCreationFee was not called on the implementation")
		}
		if fee != tt.expectedFee {
			t.Errorf("GetPoolCreationFee() = %v, want %v", fee, tt.expectedFee)
		}
	}
}

// TestGetWithdrawalFee tests the GetWithdrawalFee proxy function
func TestGetWithdrawalFee(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		expectedFee uint64
	}{
		{
			name: "get withdrawal fee is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
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

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetWithdrawalFee", tt.expectedFee)

		// Action
		fee := GetWithdrawalFee()

		// Assert
		if mockPool.Response.CallCount("GetWithdrawalFee") != 1 {
			t.Error("GetWithdrawalFee was not called on the implementation")
		}
		if fee != tt.expectedFee {
			t.Errorf("GetWithdrawalFee() = %v, want %v", fee, tt.expectedFee)
		}
	}
}

// TestGetFee tests the GetFee proxy function
func TestGetFee(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		poolPath    string
		expectedFee uint32
	}{
		{
			name: "get fee is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:    "mock_pool_path",
			expectedFee: 3000,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetFee", tt.expectedFee)

		// Action
		fee := GetFee(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetFee") != 1 {
			t.Error("GetFee was not called on the implementation")
		}
		if fee != tt.expectedFee {
			t.Errorf("GetFee() = %v, want %v", fee, tt.expectedFee)
		}
	}
}

// TestGetFeeAmountTickSpacing tests the GetFeeAmountTickSpacing proxy function
func TestGetFeeAmountTickSpacing(t *testing.T) {
	tests := []struct {
		name            string
		setup           func(t *testing.T)
		fee             uint32
		expectedSpacing int32
	}{
		{
			name: "get fee amount tick spacing is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			fee:             3000,
			expectedSpacing: 60,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetFeeAmountTickSpacing", tt.expectedSpacing)

		// Action
		spacing := GetFeeAmountTickSpacing(tt.fee)

		// Assert
		if mockPool.Response.CallCount("GetFeeAmountTickSpacing") != 1 {
			t.Error("GetFeeAmountTickSpacing was not called on the implementation")
		}
		if spacing != tt.expectedSpacing {
			t.Errorf("GetFeeAmountTickSpacing() = %v, want %v", spacing, tt.expectedSpacing)
		}
	}
}

// TestGetMaxLiquidityPerTick tests the GetMaxLiquidityPerTick proxy function
func TestGetMaxLiquidityPerTick(t *testing.T) {
	tests := []struct {
		name              string
		setup             func(t *testing.T)
		poolPath          string
		expectedLiquidity string
	}{
		{
			name: "get max liquidity per tick is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:          "mock_pool_path",
			expectedLiquidity: "1000000",
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetMaxLiquidityPerTick", tt.expectedLiquidity)

		// Action
		liquidity := GetMaxLiquidityPerTick(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetMaxLiquidityPerTick") != 1 {
			t.Error("GetMaxLiquidityPerTick was not called on the implementation")
		}
		if liquidity != tt.expectedLiquidity {
			t.Errorf("GetMaxLiquidityPerTick() = %v, want %v", liquidity, tt.expectedLiquidity)
		}
	}
}

// TestGetSlot0FeeProtocol tests the GetSlot0FeeProtocol proxy function
func TestGetSlot0FeeProtocol(t *testing.T) {
	tests := []struct {
		name                string
		setup               func(t *testing.T)
		poolPath            string
		expectedFeeProtocol uint8
	}{
		{
			name: "get slot0 fee protocol is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:            "mock_pool_path",
			expectedFeeProtocol: 10,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetSlot0FeeProtocol", tt.expectedFeeProtocol)

		// Action
		feeProtocol := GetSlot0FeeProtocol(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetSlot0FeeProtocol") != 1 {
			t.Error("GetSlot0FeeProtocol was not called on the implementation")
		}
		if feeProtocol != tt.expectedFeeProtocol {
			t.Errorf("GetSlot0FeeProtocol() = %v, want %v", feeProtocol, tt.expectedFeeProtocol)
		}
	}
}

// TestGetSlot0Unlocked tests the GetSlot0Unlocked proxy function
func TestGetSlot0Unlocked(t *testing.T) {
	tests := []struct {
		name             string
		setup            func(t *testing.T)
		poolPath         string
		expectedUnlocked bool
	}{
		{
			name: "get slot0 unlocked is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:         "mock_pool_path",
			expectedUnlocked: true,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetSlot0Unlocked", tt.expectedUnlocked)

		// Action
		unlocked := GetSlot0Unlocked(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetSlot0Unlocked") != 1 {
			t.Error("GetSlot0Unlocked was not called on the implementation")
		}
		if unlocked != tt.expectedUnlocked {
			t.Errorf("GetSlot0Unlocked() = %v, want %v", unlocked, tt.expectedUnlocked)
		}
	}
}

// TestGetToken0Path tests the GetToken0Path proxy function
func TestGetToken0Path(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		poolPath     string
		expectedPath string
	}{
		{
			name: "get token0 path is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:     "mock_pool_path",
			expectedPath: "gno.land/r/gnoswap/test_token/token0",
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetToken0Path", tt.expectedPath)

		// Action
		path := GetToken0Path(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetToken0Path") != 1 {
			t.Error("GetToken0Path was not called on the implementation")
		}
		if path != tt.expectedPath {
			t.Errorf("GetToken0Path() = %v, want %v", path, tt.expectedPath)
		}
	}
}

// TestGetToken1Path tests the GetToken1Path proxy function
func TestGetToken1Path(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		poolPath     string
		expectedPath string
	}{
		{
			name: "get token1 path is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:     "mock_pool_path",
			expectedPath: "gno.land/r/gnoswap/test_token/token1",
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetToken1Path", tt.expectedPath)

		// Action
		path := GetToken1Path(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetToken1Path") != 1 {
			t.Error("GetToken1Path was not called on the implementation")
		}
		if path != tt.expectedPath {
			t.Errorf("GetToken1Path() = %v, want %v", path, tt.expectedPath)
		}
	}
}

// TestGetTickSpacing tests the GetTickSpacing proxy function
func TestGetTickSpacing(t *testing.T) {
	tests := []struct {
		name            string
		setup           func(t *testing.T)
		poolPath        string
		expectedSpacing int32
	}{
		{
			name: "get tick spacing is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:        "mock_pool_path",
			expectedSpacing: 60,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetTickSpacing", tt.expectedSpacing)

		// Action
		spacing := GetTickSpacing(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetTickSpacing") != 1 {
			t.Error("GetTickSpacing was not called on the implementation")
		}
		if spacing != tt.expectedSpacing {
			t.Errorf("GetTickSpacing() = %v, want %v", spacing, tt.expectedSpacing)
		}
	}
}

// TestGetProtocolFeesToken0 tests the GetProtocolFeesToken0 proxy function
func TestGetProtocolFeesToken0(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		poolPath    string
		expectedFee string
	}{
		{
			name: "get protocol fees token0 is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:    "mock_pool_path",
			expectedFee: "1000",
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetProtocolFeesToken0", tt.expectedFee)

		// Action
		fee := GetProtocolFeesToken0(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetProtocolFeesToken0") != 1 {
			t.Error("GetProtocolFeesToken0 was not called on the implementation")
		}
		if fee != tt.expectedFee {
			t.Errorf("GetProtocolFeesToken0() = %v, want %v", fee, tt.expectedFee)
		}
	}
}

// TestGetProtocolFeesToken1 tests the GetProtocolFeesToken1 proxy function
func TestGetProtocolFeesToken1(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		poolPath    string
		expectedFee string
	}{
		{
			name: "get protocol fees token1 is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:    "mock_pool_path",
			expectedFee: "1000",
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetProtocolFeesToken1", tt.expectedFee)

		// Action
		fee := GetProtocolFeesToken1(tt.poolPath)

		// Assert
		if mockPool.Response.CallCount("GetProtocolFeesToken1") != 1 {
			t.Error("GetProtocolFeesToken1 was not called on the implementation")
		}
		if fee != tt.expectedFee {
			t.Errorf("GetProtocolFeesToken1() = %v, want %v", fee, tt.expectedFee)
		}
	}
}

// TestGetPositionLiquidity tests the GetPositionLiquidity proxy function
func TestGetPositionLiquidity(t *testing.T) {
	tests := []struct {
		name              string
		setup             func(t *testing.T)
		poolPath          string
		key               string
		expectedLiquidity *u256.Uint
	}{
		{
			name: "get position liquidity is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:          "mock_pool_path",
			key:               "mock_key",
			expectedLiquidity: u256.NewUint(1000000),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPool := implementation.(*MockPool)
		mockPool.Response.Set("GetPositionLiquidity", tt.expectedLiquidity)

		// Action
		liquidity := GetPositionLiquidity(tt.poolPath, tt.key)

		// Assert
		if mockPool.Response.CallCount("GetPositionLiquidity") != 1 {
			t.Error("GetPositionLiquidity was not called on the implementation")
		}
		if liquidity == nil {
			t.Error("GetPositionLiquidity() returned nil")
		}
	}
}
