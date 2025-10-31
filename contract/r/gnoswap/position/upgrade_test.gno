package position

import (
	"chain/runtime"
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
)

// TestRegisterInitializer tests the position upgrade system with table-driven approach
func TestRegisterInitializer(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(t *testing.T)
		initializer          func(s IPositionStore) IPosition
		callerRealm          runtime.Realm
		expectedVersion      string
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:            "register initializer is success",
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"),
			initializer:     makeMockInitializer("v1"),
			expectedVersion: "v1",
		},
		{
			name: "register multiple different initializers",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/position/new_version"),
			initializer:     makeMockInitializer("new_version"),
			expectedVersion: "v1",
		},
		{
			name: "register initializer is failed by duplicate registration",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"),
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

			impl := implementation.(*MockPosition)
			uassert.Equal(t, impl.Version, tt.expectedVersion)
		}
	}
}

// TestUpgradeImpl tests the position upgrade implementation
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
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/new_version"))
				RegisterInitializer(cross, makeMockInitializer("new_version"))
			},
			packagePath:     "gno.land/r/gnoswap/position/new_version",
			callerRealm:     testing.NewUserRealm(adminAddr),
			expectedVersion: "new_version",
		},
		{
			name: "upgrade impl is failed by non-admin caller",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/new_version"))
				RegisterInitializer(cross, makeMockInitializer("new_version"))
			},
			packagePath:          "gno.land/r/gnoswap/position/new_version",
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/invalid"),
			expectedVersion:      "v1",
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1ute9mjth6la3nrkeaaj4ec0nh3ypj4ngy0jnjh is not admin",
		},
		{
			name: "upgrade impl is failed by initializer not found",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			packagePath:          "gno.land/r/gnoswap/position/nonexistent",
			callerRealm:          testing.NewUserRealm(adminAddr),
			expectedVersion:      "v1",
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: initializer not found for package path:gno.land/r/gnoswap/position/nonexistent",
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

		impl := implementation.(*MockPosition)
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
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
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

// TestMint tests the Mint proxy function
func TestMint(t *testing.T) {
	tests := []struct {
		name           string
		setup          func(t *testing.T)
		token0         string
		token1         string
		fee            uint32
		tickLower      int32
		tickUpper      int32
		amount0Desired string
		amount1Desired string
		amount0Min     string
		amount1Min     string
		deadline       int64
		mintTo         address
		caller         address
		referrer       string
		callerRealm    runtime.Realm
	}{
		{
			name: "mint is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			token0:         "gno.land/r/gnoswap/test_token/token0",
			token1:         "gno.land/r/gnoswap/test_token/token1",
			fee:            3000,
			tickLower:      -100,
			tickUpper:      100,
			amount0Desired: "1000000",
			amount1Desired: "1000000",
			amount0Min:     "900000",
			amount1Min:     "900000",
			deadline:       9999999999,
			mintTo:         "gno1...",
			caller:         "gno1...",
			referrer:       "",
			callerRealm:    testing.NewCodeRealm("gno.land/r/gnoswap/position"),
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
		Mint(cross, tt.token0, tt.token1, tt.fee, tt.tickLower, tt.tickUpper, tt.amount0Desired, tt.amount1Desired, tt.amount0Min, tt.amount1Min, tt.deadline, tt.mintTo, tt.caller, tt.referrer)

		// Assert
		mockPosition := implementation.(*MockPosition)
		if mockPosition.Response.CallCount("Mint") == 0 {
			t.Error("Mint was not called on the implementation")
		}
	}
}

// TestIncreaseLiquidity tests the IncreaseLiquidity proxy function
func TestIncreaseLiquidity(t *testing.T) {
	tests := []struct {
		name              string
		setup             func(t *testing.T)
		positionId        uint64
		amount0DesiredStr string
		amount1DesiredStr string
		amount0MinStr     string
		amount1MinStr     string
		deadline          int64
		callerRealm       runtime.Realm
	}{
		{
			name: "increase liquidity is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:        1,
			amount0DesiredStr: "1000000",
			amount1DesiredStr: "1000000",
			amount0MinStr:     "900000",
			amount1MinStr:     "900000",
			deadline:          9999999999,
			callerRealm:       testing.NewCodeRealm("gno.land/r/gnoswap/position"),
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
		IncreaseLiquidity(cross, tt.positionId, tt.amount0DesiredStr, tt.amount1DesiredStr, tt.amount0MinStr, tt.amount1MinStr, tt.deadline)

		// Assert
		mockPosition := implementation.(*MockPosition)
		if mockPosition.Response.CallCount("IncreaseLiquidity") == 0 {
			t.Error("IncreaseLiquidity was not called on the implementation")
		}
	}
}

// TestDecreaseLiquidity tests the DecreaseLiquidity proxy function
func TestDecreaseLiquidity(t *testing.T) {
	tests := []struct {
		name          string
		setup         func(t *testing.T)
		positionId    uint64
		liquidityStr  string
		amount0MinStr string
		amount1MinStr string
		deadline      int64
		unwrapResult  bool
		callerRealm   runtime.Realm
	}{
		{
			name: "decrease liquidity is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:    1,
			liquidityStr:  "1000000",
			amount0MinStr: "900000",
			amount1MinStr: "900000",
			deadline:      9999999999,
			unwrapResult:  false,
			callerRealm:   testing.NewCodeRealm("gno.land/r/gnoswap/position"),
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
		DecreaseLiquidity(cross, tt.positionId, tt.liquidityStr, tt.amount0MinStr, tt.amount1MinStr, tt.deadline, tt.unwrapResult)

		// Assert
		mockPosition := implementation.(*MockPosition)
		if mockPosition.Response.CallCount("DecreaseLiquidity") == 0 {
			t.Error("DecreaseLiquidity was not called on the implementation")
		}
	}
}

// TestReposition tests the Reposition proxy function
func TestReposition(t *testing.T) {
	tests := []struct {
		name              string
		setup             func(t *testing.T)
		positionId        uint64
		tickLower         int32
		tickUpper         int32
		amount0DesiredStr string
		amount1DesiredStr string
		amount0MinStr     string
		amount1MinStr     string
		callerRealm       runtime.Realm
	}{
		{
			name: "reposition is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:        1,
			tickLower:         -200,
			tickUpper:         200,
			amount0DesiredStr: "1000000",
			amount1DesiredStr: "1000000",
			amount0MinStr:     "900000",
			amount1MinStr:     "900000",
			callerRealm:       testing.NewCodeRealm("gno.land/r/gnoswap/position"),
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
		Reposition(cross, tt.positionId, tt.tickLower, tt.tickUpper, tt.amount0DesiredStr, tt.amount1DesiredStr, tt.amount0MinStr, tt.amount1MinStr)

		// Assert
		mockPosition := implementation.(*MockPosition)
		if mockPosition.Response.CallCount("Reposition") == 0 {
			t.Error("Reposition was not called on the implementation")
		}
	}
}

// TestCollectFee tests the CollectFee proxy function
func TestCollectFee(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		positionId   uint64
		unwrapResult bool
		callerRealm  runtime.Realm
	}{
		{
			name: "collect fee is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:   1,
			unwrapResult: false,
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/position"),
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
		CollectFee(cross, tt.positionId, tt.unwrapResult)

		// Assert
		mockPosition := implementation.(*MockPosition)
		if mockPosition.Response.CallCount("CollectFee") == 0 {
			t.Error("CollectFee was not called on the implementation")
		}
	}
}

// TestSetPositionOperator tests the SetPositionOperator proxy function
func TestSetPositionOperator(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		operator    address
		callerRealm runtime.Realm
	}{
		{
			name: "set position operator is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			operator:    "gno1operator",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
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
		SetPositionOperator(cross, tt.positionId, tt.operator)

		// Assert
		mockPosition := implementation.(*MockPosition)
		if mockPosition.Response.CallCount("SetPositionOperator") == 0 {
			t.Error("SetPositionOperator was not called on the implementation")
		}
	}
}

// TestGetPosition tests the GetPosition proxy function
func TestGetPosition(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		callerRealm runtime.Realm
	}{
		{
			name: "get position is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPosition", Position{}, true)

		testing.SetRealm(tt.callerRealm)

		// Action
		GetPosition(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPosition") == 0 {
			t.Error("GetPosition was not called on the implementation")
		}
	}
}

// TestIsBurned tests the IsBurned proxy function
func TestIsBurned(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    bool
		callerRealm runtime.Realm
	}{
		{
			name: "is burned is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    false,
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("IsBurned", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := IsBurned(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("IsBurned") == 0 {
			t.Error("IsBurned was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("IsBurned() = %v, want %v", result, tt.expected)
		}
	}
}

// TestIsInRange tests the IsInRange proxy function
func TestIsInRange(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    bool
		callerRealm runtime.Realm
	}{
		{
			name: "is in range is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    true,
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("IsInRange", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := IsInRange(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("IsInRange") == 0 {
			t.Error("IsInRange was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("IsInRange() = %v, want %v", result, tt.expected)
		}
	}
}

// TestGetPositionFeeGrowthInside0LastX128 tests the GetPositionFeeGrowthInside0LastX128 proxy function
func TestGetPositionFeeGrowthInside0LastX128(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    *u256.Uint
		callerRealm runtime.Realm
	}{
		{
			name: "get position fee growth inside 0 last x128 is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    u256.NewUint(1000),
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionFeeGrowthInside0LastX128", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionFeeGrowthInside0LastX128(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionFeeGrowthInside0LastX128") == 0 {
			t.Error("GetPositionFeeGrowthInside0LastX128 was not called on the implementation")
		}
		if result == nil {
			t.Error("GetPositionFeeGrowthInside0LastX128() returned nil")
		}
	}
}

// TestGetPositionFeeGrowthInside1LastX128 tests the GetPositionFeeGrowthInside1LastX128 proxy function
func TestGetPositionFeeGrowthInside1LastX128(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    *u256.Uint
		callerRealm runtime.Realm
	}{
		{
			name: "get position fee growth inside 1 last x128 is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    u256.NewUint(1000),
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionFeeGrowthInside1LastX128", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionFeeGrowthInside1LastX128(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionFeeGrowthInside1LastX128") == 0 {
			t.Error("GetPositionFeeGrowthInside1LastX128 was not called on the implementation")
		}
		if result == nil {
			t.Error("GetPositionFeeGrowthInside1LastX128() returned nil")
		}
	}
}

// TestGetPositionLiquidity tests the GetPositionLiquidity proxy function
func TestGetPositionLiquidity(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    *u256.Uint
		callerRealm runtime.Realm
	}{
		{
			name: "get position liquidity is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    u256.NewUint(1000000),
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionLiquidity", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionLiquidity(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionLiquidity") == 0 {
			t.Error("GetPositionLiquidity was not called on the implementation")
		}
		if result == nil {
			t.Error("GetPositionLiquidity() returned nil")
		}
	}
}

// TestGetPositionOperator tests the GetPositionOperator proxy function
func TestGetPositionOperator(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    address
		callerRealm runtime.Realm
	}{
		{
			name: "get position operator is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    "gno1operator",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionOperator", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionOperator(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionOperator") == 0 {
			t.Error("GetPositionOperator was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionOperator() = %v, want %v", result, tt.expected)
		}
	}
}

// TestGetPositionPoolKey tests the GetPositionPoolKey proxy function
func TestGetPositionPoolKey(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    string
		callerRealm runtime.Realm
	}{
		{
			name: "get position pool key is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    "gno.land/r/gnoswap/test_token/token0:gno.land/r/gnoswap/test_token/token1:3000",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionPoolKey", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionPoolKey(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionPoolKey") == 0 {
			t.Error("GetPositionPoolKey was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionPoolKey() = %v, want %v", result, tt.expected)
		}
	}
}

// TestGetPositionTickLower tests the GetPositionTickLower proxy function
func TestGetPositionTickLower(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    int32
		callerRealm runtime.Realm
	}{
		{
			name: "get position tick lower is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    -100,
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionTickLower", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionTickLower(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionTickLower") == 0 {
			t.Error("GetPositionTickLower was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionTickLower() = %v, want %v", result, tt.expected)
		}
	}
}

// TestGetPositionTickUpper tests the GetPositionTickUpper proxy function
func TestGetPositionTickUpper(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    int32
		callerRealm runtime.Realm
	}{
		{
			name: "get position tick upper is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    100,
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionTickUpper", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionTickUpper(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionTickUpper") == 0 {
			t.Error("GetPositionTickUpper was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionTickUpper() = %v, want %v", result, tt.expected)
		}
	}
}

// TestGetPositionTokensOwed0 tests the GetPositionTokensOwed0 proxy function
func TestGetPositionTokensOwed0(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    *u256.Uint
		callerRealm runtime.Realm
	}{
		{
			name: "get position tokens owed 0 is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    u256.NewUint(1000),
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionTokensOwed0", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionTokensOwed0(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionTokensOwed0") == 0 {
			t.Error("GetPositionTokensOwed0 was not called on the implementation")
		}
		if result == nil {
			t.Error("GetPositionTokensOwed0() returned nil")
		}
	}
}

// TestGetPositionTokensOwed1 tests the GetPositionTokensOwed1 proxy function
func TestGetPositionTokensOwed1(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    *u256.Uint
		callerRealm runtime.Realm
	}{
		{
			name: "get position tokens owed 1 is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    u256.NewUint(1000),
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionTokensOwed1", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionTokensOwed1(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionTokensOwed1") == 0 {
			t.Error("GetPositionTokensOwed1 was not called on the implementation")
		}
		if result == nil {
			t.Error("GetPositionTokensOwed1() returned nil")
		}
	}
}

// TestGetUnclaimedFee tests the GetUnclaimedFee proxy function
func TestGetUnclaimedFee(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		positionId   uint64
		expectedFee0 *u256.Uint
		expectedFee1 *u256.Uint
		callerRealm  runtime.Realm
	}{
		{
			name: "get unclaimed fee is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:   1,
			expectedFee0: u256.NewUint(1000),
			expectedFee1: u256.NewUint(2000),
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetUnclaimedFee", tt.expectedFee0, tt.expectedFee1)

		testing.SetRealm(tt.callerRealm)

		// Action
		fee0, fee1 := GetUnclaimedFee(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetUnclaimedFee") == 0 {
			t.Error("GetUnclaimedFee was not called on the implementation")
		}
		if fee0 == nil || fee1 == nil {
			t.Error("GetUnclaimedFee() returned nil")
		}
	}
}

// TestGetPositionOwner tests the GetPositionOwner proxy function
func TestGetPositionOwner(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    address
		callerRealm runtime.Realm
	}{
		{
			name: "get position owner is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    "gno1owner",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionOwner", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionOwner(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionOwner") == 0 {
			t.Error("GetPositionOwner was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionOwner() = %v, want %v", result, tt.expected)
		}
	}
}

// TestApiGetPosition tests the ApiGetPosition proxy function
func TestApiGetPosition(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    string
		callerRealm runtime.Realm
	}{
		{
			name: "api get position is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    "{}",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("ApiGetPosition", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := ApiGetPosition(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("ApiGetPosition") == 0 {
			t.Error("ApiGetPosition was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("ApiGetPosition() = %v, want %v", result, tt.expected)
		}
	}
}

// TestApiGetPositionUnclaimedFeeByPositionID tests the ApiGetPositionUnclaimedFeeByPositionID proxy function
func TestApiGetPositionUnclaimedFeeByPositionID(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		expected    string
		callerRealm runtime.Realm
	}{
		{
			name: "api get position unclaimed fee by position id is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    "{}",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("ApiGetPositionUnclaimedFeeByPositionID", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := ApiGetPositionUnclaimedFeeByPositionID(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("ApiGetPositionUnclaimedFeeByPositionID") == 0 {
			t.Error("ApiGetPositionUnclaimedFeeByPositionID was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("ApiGetPositionUnclaimedFeeByPositionID() = %v, want %v", result, tt.expected)
		}
	}
}
