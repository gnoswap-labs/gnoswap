package position

import (
	"chain/runtime"
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

// TestRegisterInitializer tests the position upgrade system with table-driven approach
func TestRegisterInitializer(cur realm, t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(cur realm, t *testing.T)
		initializer          func(_ int, rlm realm, s IPositionStore) IPosition
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
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
			},
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/position/new_version"),
			initializer:     makeMockInitializer("new_version"),
			expectedVersion: "v1",
		},
		{
			name: "register initializer is failed by duplicate registration",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
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
			tt.setup(cur, t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		if tt.expectedHasAbort {
			uassert.AbortsContains(t, cur, tt.expectedAbortMessage, func() {
				RegisterInitializer(cross(cur), tt.initializer)
			})
		} else {
			RegisterInitializer(cross(cur), tt.initializer)

			impl := implementation.(*MockPosition)
			uassert.Equal(t, impl.Version, tt.expectedVersion)
		}
	}
}

func TestRegisterInitializerLiveRealmBootstrap(cur realm, t *testing.T) {
	resetTestState(t)

	initializerCalls := 0
	initializer := func(_ int, rlm realm, s IPositionStore) IPosition {
		if !rlm.IsCurrent() {
			panic(ErrSpoofedRealm)
		}

		initializerCalls++
		err := s.SetPositionNextID(0, rlm, uint64(initializerCalls))
		if err != nil {
			panic(err)
		}

		return newMockPosition("v1")
	}

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
	RegisterInitializer(cross(cur), initializer)
	uassert.Equal(t, 1, initializerCalls)
	uassert.Equal(t, uint64(1), NewPositionStore(kvStore).GetPositionNextID())

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
	uassert.Equal(t, 2, initializerCalls)
	uassert.Equal(t, uint64(2), NewPositionStore(kvStore).GetPositionNextID())
}

// TestUpgradeImpl tests the position upgrade implementation
func TestUpgradeImpl(cur realm, t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(cur realm, t *testing.T)
		packagePath          string
		callerRealm          runtime.Realm
		expectedVersion      string
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name: "upgrade impl is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/new_version"))
				RegisterInitializer(cross(cur), makeMockInitializer("new_version"))
			},
			packagePath:     "gno.land/r/gnoswap/position/new_version",
			callerRealm:     testing.NewUserRealm(adminAddr),
			expectedVersion: "new_version",
		},
		{
			name: "upgrade impl is failed by non-admin caller",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/new_version"))
				RegisterInitializer(cross(cur), makeMockInitializer("new_version"))
			},
			packagePath:          "gno.land/r/gnoswap/position/new_version",
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/invalid"),
			expectedVersion:      "v1",
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1ute9mjth6la3nrkeaaj4ec0nh3ypj4ngy0jnjh is not admin",
		},
		{
			name: "upgrade impl is failed by initializer not found",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
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
			tt.setup(cur, t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		if tt.expectedHasAbort {
			uassert.AbortsContains(t, cur, tt.expectedAbortMessage, func() {
				UpgradeImpl(cross(cur), tt.packagePath)
			})
		} else {
			UpgradeImpl(cross(cur), tt.packagePath)
		}

		impl := implementation.(*MockPosition)
		uassert.Equal(t, impl.Version, tt.expectedVersion)
	}
}

// TestGetImplementation tests the implementation getter
func TestGetImplementation(cur realm, t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(cur realm, t *testing.T)
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name: "get impl is success when implementation is set",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
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
			tt.setup(cur, t)
		}

		// Action
		if tt.expectedHasAbort {
			uassert.PanicsContains(t, cur, tt.expectedAbortMessage, func() {
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
func TestMint(cur realm, t *testing.T) {
	tests := []struct {
		name           string
		setup          func(cur realm, t *testing.T)
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
		referrer       string
		callerRealm    runtime.Realm
	}{
		{
			name: "mint is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
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
			mintTo:         adminAddr,
			referrer:       "",
			callerRealm:    testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(cur, t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		Mint(cross(cur), tt.token0, tt.token1, tt.fee, tt.tickLower, tt.tickUpper, tt.amount0Desired, tt.amount1Desired, tt.amount0Min, tt.amount1Min, tt.deadline, tt.mintTo, tt.referrer)

		// Assert
		mockPosition := implementation.(*MockPosition)
		if mockPosition.Response.CallCount("Mint") != 1 {
			t.Error("Mint was not called on the implementation")
		}
	}
}

// TestIncreaseLiquidity tests the IncreaseLiquidity proxy function
func TestIncreaseLiquidity(cur realm, t *testing.T) {
	tests := []struct {
		name              string
		setup             func(cur realm, t *testing.T)
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
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
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
			tt.setup(cur, t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		IncreaseLiquidity(cross(cur), tt.positionId, tt.amount0DesiredStr, tt.amount1DesiredStr, tt.amount0MinStr, tt.amount1MinStr, tt.deadline)

		// Assert
		mockPosition := implementation.(*MockPosition)
		if mockPosition.Response.CallCount("IncreaseLiquidity") != 1 {
			t.Error("IncreaseLiquidity was not called on the implementation")
		}
	}
}

// TestDecreaseLiquidity tests the DecreaseLiquidity proxy function
func TestDecreaseLiquidity(cur realm, t *testing.T) {
	tests := []struct {
		name          string
		setup         func(cur realm, t *testing.T)
		positionId    uint64
		liquidityStr  string
		amount0MinStr string
		amount1MinStr string
		deadline      int64
		callerRealm   runtime.Realm
	}{
		{
			name: "decrease liquidity is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
			},
			positionId:    1,
			liquidityStr:  "1000000",
			amount0MinStr: "900000",
			amount1MinStr: "900000",
			deadline:      9999999999,
			callerRealm:   testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(cur, t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		DecreaseLiquidity(cross(cur), tt.positionId, tt.liquidityStr, tt.amount0MinStr, tt.amount1MinStr, tt.deadline)

		// Assert
		mockPosition := implementation.(*MockPosition)
		if mockPosition.Response.CallCount("DecreaseLiquidity") != 1 {
			t.Error("DecreaseLiquidity was not called on the implementation")
		}
	}
}

// TestReposition tests the Reposition proxy function
func TestReposition(cur realm, t *testing.T) {
	tests := []struct {
		name              string
		setup             func(cur realm, t *testing.T)
		positionId        uint64
		tickLower         int32
		tickUpper         int32
		amount0DesiredStr string
		amount1DesiredStr string
		amount0MinStr     string
		amount1MinStr     string
		deadline          int64
		callerRealm       runtime.Realm
	}{
		{
			name: "reposition is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
			},
			positionId:        1,
			tickLower:         -200,
			tickUpper:         200,
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
			tt.setup(cur, t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		Reposition(cross(cur), tt.positionId, tt.tickLower, tt.tickUpper, tt.amount0DesiredStr, tt.amount1DesiredStr, tt.amount0MinStr, tt.amount1MinStr, tt.deadline)

		// Assert
		mockPosition := implementation.(*MockPosition)
		if mockPosition.Response.CallCount("Reposition") != 1 {
			t.Error("Reposition was not called on the implementation")
		}
	}
}

// TestCollectFee tests the CollectFee proxy function
func TestCollectFee(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		callerRealm runtime.Realm
	}{
		{
			name: "collect fee is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(cur, t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		CollectFee(cross(cur), tt.positionId)

		// Assert
		mockPosition := implementation.(*MockPosition)
		if mockPosition.Response.CallCount("CollectFee") != 1 {
			t.Error("CollectFee was not called on the implementation")
		}
	}
}

// TestSetPositionOperator tests the SetPositionOperator proxy function
func TestSetPositionOperator(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		operator    address
		callerRealm runtime.Realm
	}{
		{
			name: "set position operator is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
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
			tt.setup(cur, t)
		}

		testing.SetRealm(tt.callerRealm)

		// Action
		SetPositionOperator(cross(cur), tt.positionId, tt.operator)

		// Assert
		mockPosition := implementation.(*MockPosition)
		if mockPosition.Response.CallCount("SetPositionOperator") != 1 {
			t.Error("SetPositionOperator was not called on the implementation")
		}
	}
}

// TestGetPosition tests the GetPosition proxy function
func TestGetPosition(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		callerRealm runtime.Realm
	}{
		{
			name: "get position is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPosition", Position{}, false)

		testing.SetRealm(tt.callerRealm)

		// Action
		GetPosition(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPosition") != 1 {
			t.Error("GetPosition was not called on the implementation")
		}
	}
}

// TestIsBurned tests the IsBurned proxy function
func TestIsBurned(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		expected    bool
		callerRealm runtime.Realm
	}{
		{
			name: "is burned is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
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
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("IsBurned", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := IsBurned(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("IsBurned") != 1 {
			t.Error("IsBurned was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("IsBurned() = %v, want %v", result, tt.expected)
		}
	}
}

// TestIsInRange tests the IsInRange proxy function
func TestIsInRange(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		expected    bool
		callerRealm runtime.Realm
	}{
		{
			name: "is in range is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
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
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("IsInRange", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := IsInRange(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("IsInRange") != 1 {
			t.Error("IsInRange was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("IsInRange() = %v, want %v", result, tt.expected)
		}
	}
}

// TestGetPositionFeeGrowthInside0LastX128 tests the GetPositionFeeGrowthInside0LastX128 proxy function
func TestGetPositionFeeGrowthInside0LastX128(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		expected    string
		callerRealm runtime.Realm
	}{
		{
			name: "get position fee growth inside 0 last x128 is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    "1000",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionFeeGrowthInside0LastX128", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionFeeGrowthInside0LastX128(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionFeeGrowthInside0LastX128") != 1 {
			t.Error("GetPositionFeeGrowthInside0LastX128 was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionFeeGrowthInside0LastX128() = %s, want %s", result, tt.expected)
		}
	}
}

// TestGetPositionFeeGrowthInside1LastX128 tests the GetPositionFeeGrowthInside1LastX128 proxy function
func TestGetPositionFeeGrowthInside1LastX128(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		expected    string
		callerRealm runtime.Realm
	}{
		{
			name: "get position fee growth inside 1 last x128 is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    "1000",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionFeeGrowthInside1LastX128", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionFeeGrowthInside1LastX128(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionFeeGrowthInside1LastX128") != 1 {
			t.Error("GetPositionFeeGrowthInside1LastX128 was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionFeeGrowthInside1LastX128() = %s, want %s", result, tt.expected)
		}
	}
}

// TestGetPositionLiquidity tests the GetPositionLiquidity proxy function
func TestGetPositionLiquidity(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		expected    string
		callerRealm runtime.Realm
	}{
		{
			name: "get position liquidity is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    "1000000",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionLiquidity", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionLiquidity(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionLiquidity") != 1 {
			t.Error("GetPositionLiquidity was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionLiquidity() = %s, want %s", result, tt.expected)
		}
	}
}

// TestGetPositionOperator tests the GetPositionOperator proxy function
func TestGetPositionOperator(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		expected    address
		callerRealm runtime.Realm
	}{
		{
			name: "get position operator is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
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
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionOperator", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionOperator(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionOperator") != 1 {
			t.Error("GetPositionOperator was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionOperator() = %v, want %v", result, tt.expected)
		}
	}
}

// TestGetPositionPoolKey tests the GetPositionPoolKey proxy function
func TestGetPositionPoolKey(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		expected    string
		callerRealm runtime.Realm
	}{
		{
			name: "get position pool key is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
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
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionPoolKey", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionPoolKey(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionPoolKey") != 1 {
			t.Error("GetPositionPoolKey was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionPoolKey() = %v, want %v", result, tt.expected)
		}
	}
}

// TestGetPositionTickLower tests the GetPositionTickLower proxy function
func TestGetPositionTickLower(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		expected    int32
		callerRealm runtime.Realm
	}{
		{
			name: "get position tick lower is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
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
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionTickLower", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionTickLower(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionTickLower") != 1 {
			t.Error("GetPositionTickLower was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionTickLower() = %v, want %v", result, tt.expected)
		}
	}
}

// TestGetPositionTickUpper tests the GetPositionTickUpper proxy function
func TestGetPositionTickUpper(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		expected    int32
		callerRealm runtime.Realm
	}{
		{
			name: "get position tick upper is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
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
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionTickUpper", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionTickUpper(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionTickUpper") != 1 {
			t.Error("GetPositionTickUpper was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionTickUpper() = %v, want %v", result, tt.expected)
		}
	}
}

// TestGetPositionTokensOwed0 tests the GetPositionTokensOwed0 proxy function
func TestGetPositionTokensOwed0(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		expected    int64
		callerRealm runtime.Realm
	}{
		{
			name: "get position tokens owed 0 is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    1000,
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionTokensOwed0", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionTokensOwed0(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionTokensOwed0") != 1 {
			t.Error("GetPositionTokensOwed0 was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionTokensOwed0() = %d, want %d", result, tt.expected)
		}
	}
}

// TestGetPositionTokensOwed1 tests the GetPositionTokensOwed1 proxy function
func TestGetPositionTokensOwed1(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		expected    int64
		callerRealm runtime.Realm
	}{
		{
			name: "get position tokens owed 1 is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
			},
			positionId:  1,
			expected:    1000,
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionTokensOwed1", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionTokensOwed1(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionTokensOwed1") != 1 {
			t.Error("GetPositionTokensOwed1 was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionTokensOwed1() = %d, want %d", result, tt.expected)
		}
	}
}

// TestGetUnclaimedFee tests the GetUnclaimedFee proxy function
func TestGetUnclaimedFee(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setup        func(cur realm, t *testing.T)
		positionId   uint64
		expectedFee0 string
		expectedFee1 string
		callerRealm  runtime.Realm
	}{
		{
			name: "get unclaimed fee is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
			},
			positionId:   1,
			expectedFee0: "1000",
			expectedFee1: "2000",
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetUnclaimedFee", u256.MustFromDecimal(tt.expectedFee0), u256.MustFromDecimal(tt.expectedFee1))

		testing.SetRealm(tt.callerRealm)

		// Action
		fee0, fee1 := GetUnclaimedFee(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetUnclaimedFee") != 1 {
			t.Error("GetUnclaimedFee was not called on the implementation")
		}
		if fee0 == "" || fee1 == "" {
			t.Error("GetUnclaimedFee() returned empty string")
		}
	}
}

// TestGetPositionOwner tests the GetPositionOwner proxy function
func TestGetPositionOwner(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm, t *testing.T)
		positionId  uint64
		expected    address
		callerRealm runtime.Realm
	}{
		{
			name: "get position owner is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross(cur), "gno.land/r/gnoswap/position/v1")
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
			tt.setup(cur, t)
		}

		mockPosition := implementation.(*MockPosition)
		mockPosition.Response.Set("GetPositionOwner", tt.expected)

		testing.SetRealm(tt.callerRealm)

		// Action
		result := GetPositionOwner(tt.positionId)

		// Assert
		if mockPosition.Response.CallCount("GetPositionOwner") != 1 {
			t.Error("GetPositionOwner was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPositionOwner() = %v, want %v", result, tt.expected)
		}
	}
}
