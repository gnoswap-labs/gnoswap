package pool

import (
	"chain/runtime"
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
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:        "register initializer is success",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"),
			initializer: makeMockInitializer("v1"),
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
			expectedAbortMessage: "RegisterInitializer can only be called once",
		},
		{
			name:                 "register initializer is failed by invalid domain path",
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/invalid"),
			initializer:          makeMockInitializer("v1"),
			expectedHasAbort:     true,
			expectedAbortMessage: "RegisterInitializer can only be called in the domain path",
		},
		{
			name:        "register multiple different initializers",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"),
			initializer: makeMockInitializer("v1"),
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
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name: "upgrade impl is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			packagePath: "gno.land/r/gnoswap/pool/v1",
			callerRealm: testing.NewUserRealm(adminAddr),
		},
		{
			name: "upgrade impl is failed by non-admin caller",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			packagePath:          "gno.land/r/gnoswap/pool/v1",
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/invalid"),
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1ute9mjth6la3nrkeaaj4ec0nh3ypj4ngy0jnjh is not admin",
		},
		{
			name:                 "upgrade impl is failed by initializer not found",
			packagePath:          "gno.land/r/gnoswap/pool/nonexistent",
			callerRealm:          testing.NewUserRealm(adminAddr),
			expectedHasAbort:     true,
			expectedAbortMessage: "Initializer not found for package path:gno.land/r/gnoswap/pool/nonexistent",
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
	}
}

// TestIsContainDomainPath tests the domain path validation
func TestIsContainDomainPath(t *testing.T) {
	tests := []struct {
		name           string
		callerRealm    runtime.Realm
		expectedResult bool
	}{
		{
			name:           "valid domain path",
			callerRealm:    testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"),
			expectedResult: true,
		},
		{
			name:           "invalid domain path",
			callerRealm:    testing.NewCodeRealm("gno.land/r/gnoswap/invalid"),
			expectedResult: false,
		},
		{
			name:           "exact domain path",
			callerRealm:    testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedResult: false,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)
		testing.SetRealm(tt.callerRealm)

		// Action
		result := func(cur realm) bool {
			return isContainDomainPath()
		}(cross)

		// Assert
		if result != tt.expectedResult {
			t.Errorf("isContainDomainPath() = %v, want %v", result, tt.expectedResult)
		}
	}
}

// TestGetImpl tests the implementation getter
func TestGetImpl(t *testing.T) {
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
			expectedAbortMessage: "pool implementation is not set",
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
				getImpl()
			})
		} else {
			impl := getImpl()
			if impl == nil {
				t.Error("getImpl() returned nil")
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

		println(poolImpl)

		// Assert - verify that the mock pool's CreatePool was called
		mPool := poolImpl.(*mockPoolImpl)
		if !mPool.createPoolCalled {
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

		// Action
		amount0, amount1 := Mint(cross, tt.token0Path, tt.token1Path, tt.fee, tt.tickLower, tt.tickUpper, tt.liquidityAmount, tt.positionCaller)

		// Assert
		if amount0 != tt.expectedAmount0 {
			t.Errorf("Mint() amount0 = %v, want %v", amount0, tt.expectedAmount0)
		}
		if amount1 != tt.expectedAmount1 {
			t.Errorf("Mint() amount1 = %v, want %v", amount1, tt.expectedAmount1)
		}

		mockPool := poolImpl.(*mockPoolImpl)
		if !mockPool.mintCalled {
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
		amount0, amount1 := Burn(cross, tt.token0Path, tt.token1Path, tt.fee, tt.tickLower, tt.tickUpper, tt.liquidityAmount, tt.positionCaller)

		// Assert
		if amount0 != tt.expectedAmount0 {
			t.Errorf("Burn() amount0 = %v, want %v", amount0, tt.expectedAmount0)
		}
		if amount1 != tt.expectedAmount1 {
			t.Errorf("Burn() amount1 = %v, want %v", amount1, tt.expectedAmount1)
		}

		mockPool := poolImpl.(*mockPoolImpl)
		if !mockPool.burnCalled {
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
		amount0, amount1 := Collect(cross, tt.token0Path, tt.token1Path, tt.fee, tt.recipient, tt.tickLower, tt.tickUpper, tt.amount0Requested, tt.amount1Requested)

		// Assert
		if amount0 != tt.expectedAmount0 {
			t.Errorf("Collect() amount0 = %v, want %v", amount0, tt.expectedAmount0)
		}
		if amount1 != tt.expectedAmount1 {
			t.Errorf("Collect() amount1 = %v, want %v", amount1, tt.expectedAmount1)
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
		amount0, amount1 := CollectProtocol(cross, tt.token0Path, tt.token1Path, tt.fee, tt.recipient, tt.amount0Requested, tt.amount1Requested)

		// Assert
		if amount0 != tt.expectedAmount0 {
			t.Errorf("CollectProtocol() amount0 = %v, want %v", amount0, tt.expectedAmount0)
		}
		if amount1 != tt.expectedAmount1 {
			t.Errorf("CollectProtocol() amount1 = %v, want %v", amount1, tt.expectedAmount1)
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
		amount0, amount1 := Swap(cross, tt.token0Path, tt.token1Path, tt.fee, tt.recipient, tt.zeroForOne, tt.amountSpecified, tt.sqrtPriceLimitX96, tt.caller)

		// Assert
		if amount0 != tt.expectedAmount0 {
			t.Errorf("Swap() amount0 = %v, want %v", amount0, tt.expectedAmount0)
		}
		if amount1 != tt.expectedAmount1 {
			t.Errorf("Swap() amount1 = %v, want %v", amount1, tt.expectedAmount1)
		}

		mockPool := poolImpl.(*mockPoolImpl)
		if !mockPool.swapCalled {
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
		amount0, amount1 := DrySwap(cross, tt.token0Path, tt.token1Path, tt.fee, tt.zeroForOne, tt.amountSpecified, tt.sqrtPriceLimitX96)

		// Assert
		if amount0 != tt.expectedAmount0 {
			t.Errorf("DrySwap() amount0 = %v, want %v", amount0, tt.expectedAmount0)
		}
		if amount1 != tt.expectedAmount1 {
			t.Errorf("DrySwap() amount1 = %v, want %v", amount1, tt.expectedAmount1)
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
	}
}

// TestGetPoolPath tests the GetPoolPath proxy function
func TestGetPoolPath(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		token0Path   string
		token1Path   string
		fee          uint32
		callerRealm  runtime.Realm
		expectedPath string
	}{
		{
			name: "get pool path is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			token0Path:   "gno.land/r/gnoswap/test_token/token0",
			token1Path:   "gno.land/r/gnoswap/test_token/token1",
			fee:          3000,
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedPath: "mock_pool_path",
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
		path := GetPoolPath(tt.token0Path, tt.token1Path, tt.fee)

		// Assert
		if path != tt.expectedPath {
			t.Errorf("GetPoolPath() = %v, want %v", path, tt.expectedPath)
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

		testing.SetRealm(tt.callerRealm)

		// Action
		sqrtPrice := GetSlot0SqrtPriceX96(tt.poolPath)

		// Assert
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

		testing.SetRealm(tt.callerRealm)

		// Action
		tick := GetSlot0Tick(tt.poolPath)

		// Assert
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

		testing.SetRealm(tt.callerRealm)

		// Action
		liquidity := GetLiquidity(tt.poolPath)

		// Assert
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

		testing.SetRealm(tt.callerRealm)

		// Action
		balance := GetBalanceToken0(tt.poolPath)

		// Assert
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

		testing.SetRealm(tt.callerRealm)

		// Action
		balance := GetBalanceToken1(tt.poolPath)

		// Assert
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

		testing.SetRealm(tt.callerRealm)

		// Action
		fee0, fee1 := GetFeeGrowthGlobalX128(tt.poolPath)

		// Assert
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

		testing.SetRealm(tt.callerRealm)

		// Action
		fee0, fee1 := GetPositionFeeGrowthInsideLastX128(tt.poolPath, tt.key)

		// Assert
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

		testing.SetRealm(tt.callerRealm)

		// Action
		tick, sqrt, liquidity, timestamp := GetObservation(tt.poolPath, tt.secondsAgo)

		// Assert
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

		testing.SetRealm(tt.callerRealm)

		// Action
		exists := ExistsPoolPath(tt.poolPath)

		// Assert
		if exists != tt.expectedExists {
			t.Errorf("ExistsPoolPath() = %v, want %v", exists, tt.expectedExists)
		}
	}
}

// TestApiGetPool tests the ApiGetPool proxy function
func TestApiGetPool(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		poolPath     string
		callerRealm  runtime.Realm
		expectedJSON string
	}{
		{
			name: "api get pool is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/pool/v1")
			},
			poolPath:     "mock_pool_path",
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/pool"),
			expectedJSON: "{}",
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
		json := ApiGetPool(tt.poolPath)

		// Assert
		if json != tt.expectedJSON {
			t.Errorf("ApiGetPool() = %v, want %v", json, tt.expectedJSON)
		}
	}
}

// TestApiGetTWAP tests the ApiGetTWAP proxy function
func TestApiGetTWAP(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		poolPath     string
		secondsAgo   uint32
		callerRealm  runtime.Realm
		expectedTWAP string
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
			expectedTWAP: "0",
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
		twap := ApiGetTWAP(tt.poolPath, tt.secondsAgo)

		// Assert
		if twap != tt.expectedTWAP {
			t.Errorf("ApiGetTWAP() = %v, want %v", twap, tt.expectedTWAP)
		}
	}
}
