package staker

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/uassert"
)

// TestRegisterInitializer tests the staker upgrade system with table-driven approach
func TestRegisterInitializer(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(t *testing.T)
		initializer          func(s IStakerStore, p PoolAccessor, e EmissionAccessor) IStaker
		callerRealm          runtime.Realm
		expectedVersion      string
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:            "register initializer is success",
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"),
			initializer:     makeMockInitializer("v1"),
			expectedVersion: "v1",
		},
		{
			name: "register multiple different initializers",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/staker/new_version"),
			initializer:     makeMockInitializer("new_version"),
			expectedVersion: "v1",
		},
		{
			name: "register initializer is failed by duplicate registration",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"),
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

			impl := implementation.(*MockStaker)
			uassert.Equal(t, impl.Version, tt.expectedVersion)
		}
	}
}

// TestUpgradeImpl tests the staker upgrade implementation
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
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/new_version"))
				RegisterInitializer(cross, makeMockInitializer("new_version"))
			},
			packagePath:     "gno.land/r/gnoswap/staker/new_version",
			callerRealm:     testing.NewUserRealm(adminAddr),
			expectedVersion: "new_version",
		},
		{
			name: "upgrade impl is failed by non-admin caller",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/new_version"))
				RegisterInitializer(cross, makeMockInitializer("new_version"))
			},
			packagePath:          "gno.land/r/gnoswap/staker/new_version",
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/invalid"),
			expectedVersion:      "v1",
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1ute9mjth6la3nrkeaaj4ec0nh3ypj4ngy0jnjh is not admin",
		},
		{
			name: "upgrade impl is failed by initializer not found",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			packagePath:          "gno.land/r/gnoswap/staker/nonexistent",
			callerRealm:          testing.NewUserRealm(adminAddr),
			expectedVersion:      "v1",
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: initializer not found for package path:gno.land/r/gnoswap/staker/nonexistent",
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

		impl := implementation.(*MockStaker)
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
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/staker/v1")
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

// TestStakeToken tests the StakeToken proxy function
func TestStakeToken(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		positionId  uint64
		referrer    string
		callerRealm runtime.Realm
	}{
		{
			name: "stake token is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/staker/v1")
			},
			positionId:  1,
			referrer:    "",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/staker"),
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
		StakeToken(cross, tt.positionId, tt.referrer)

		// Assert
		mockStaker := implementation.(*MockStaker)
		if mockStaker.Response.CallCount("StakeToken") == 0 {
			t.Error("StakeToken was not called on the implementation")
		}
	}
}

// TestUnStakeToken tests the UnStakeToken proxy function
func TestUnStakeToken(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		positionId   uint64
		unwrapResult bool
		callerRealm  runtime.Realm
	}{
		{
			name: "unstake token is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/staker/v1")
			},
			positionId:   1,
			unwrapResult: false,
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/staker"),
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
		UnStakeToken(cross, tt.positionId, tt.unwrapResult)

		// Assert
		mockStaker := implementation.(*MockStaker)
		if mockStaker.Response.CallCount("UnStakeToken") == 0 {
			t.Error("UnStakeToken was not called on the implementation")
		}
	}
}

// TestCollectReward tests the CollectReward proxy function
func TestCollectReward(t *testing.T) {
	tests := []struct {
		name         string
		setup        func(t *testing.T)
		positionId   uint64
		unwrapResult bool
		callerRealm  runtime.Realm
	}{
		{
			name: "collect reward is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/staker/v1")
			},
			positionId:   1,
			unwrapResult: false,
			callerRealm:  testing.NewCodeRealm("gno.land/r/gnoswap/staker"),
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
		CollectReward(cross, tt.positionId, tt.unwrapResult)

		// Assert
		mockStaker := implementation.(*MockStaker)
		if mockStaker.Response.CallCount("CollectReward") == 0 {
			t.Error("CollectReward was not called on the implementation")
		}
	}
}

// TestSetPoolTier tests the SetPoolTier proxy function
func TestSetPoolTier(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		poolPath    string
		tier        uint64
		callerRealm runtime.Realm
	}{
		{
			name: "set pool tier is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/staker/v1")
			},
			poolPath:    "gno.land/r/gnoswap/pool/test",
			tier:        1,
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/staker"),
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
		SetPoolTier(cross, tt.poolPath, tt.tier)

		// Assert
		mockStaker := implementation.(*MockStaker)
		if mockStaker.Response.CallCount("SetPoolTier") == 0 {
			t.Error("SetPoolTier was not called on the implementation")
		}
	}
}

// TestCreateExternalIncentive tests the CreateExternalIncentive proxy function
func TestCreateExternalIncentive(t *testing.T) {
	tests := []struct {
		name           string
		setup          func(t *testing.T)
		targetPoolPath string
		rewardToken    string
		rewardAmount   int64
		startTimestamp int64
		endTimestamp   int64
		callerRealm    runtime.Realm
	}{
		{
			name: "create external incentive is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/staker/v1")
			},
			targetPoolPath: "gno.land/r/gnoswap/pool/test",
			rewardToken:    "gno.land/r/gnoswap/test_token/reward",
			rewardAmount:   1000000,
			startTimestamp: 1000000,
			endTimestamp:   2000000,
			callerRealm:    testing.NewCodeRealm("gno.land/r/gnoswap/staker"),
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
		CreateExternalIncentive(cross, tt.targetPoolPath, tt.rewardToken, tt.rewardAmount, tt.startTimestamp, tt.endTimestamp)

		// Assert
		mockStaker := implementation.(*MockStaker)
		if mockStaker.Response.CallCount("CreateExternalIncentive") == 0 {
			t.Error("CreateExternalIncentive was not called on the implementation")
		}
	}
}

// TestGetDepositGnsAmount tests the GetDepositGnsAmount getter function
func TestGetDepositGnsAmount(t *testing.T) {
	tests := []struct {
		name     string
		setup    func(t *testing.T)
		expected int64
	}{
		{
			name: "get deposit gns amount is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/staker/v1")
			},
			expected: 1000,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockStaker := implementation.(*MockStaker)
		mockStaker.Response.Set("GetDepositGnsAmount", tt.expected)

		// Action
		result := GetDepositGnsAmount()

		// Assert
		if mockStaker.Response.CallCount("GetDepositGnsAmount") == 0 {
			t.Error("GetDepositGnsAmount was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetDepositGnsAmount() = %v, want %v", result, tt.expected)
		}
	}
}

// TestGetPoolTier tests the GetPoolTier getter function
func TestGetPoolTier(t *testing.T) {
	tests := []struct {
		name     string
		setup    func(t *testing.T)
		poolPath string
		expected uint64
	}{
		{
			name: "get pool tier is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/staker/v1")
			},
			poolPath: "gno.land/r/gnoswap/pool/test",
			expected: 1,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockStaker := implementation.(*MockStaker)
		mockStaker.Response.Set("GetPoolTier", tt.expected)

		// Action
		result := GetPoolTier(tt.poolPath)

		// Assert
		if mockStaker.Response.CallCount("GetPoolTier") == 0 {
			t.Error("GetPoolTier was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("GetPoolTier() = %v, want %v", result, tt.expected)
		}
	}
}

// TestIsStaked tests the IsStaked getter function
func TestIsStaked(t *testing.T) {
	tests := []struct {
		name       string
		setup      func(t *testing.T)
		positionId uint64
		expected   bool
	}{
		{
			name: "is staked is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				UpgradeImpl(cross, "gno.land/r/gnoswap/staker/v1")
			},
			positionId: 1,
			expected:   true,
		},
	}

	for _, tt := range tests {
		// Setup
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		mockStaker := implementation.(*MockStaker)
		mockStaker.Response.Set("IsStaked", tt.expected)

		// Action
		result := IsStaked(tt.positionId)

		// Assert
		if mockStaker.Response.CallCount("IsStaked") == 0 {
			t.Error("IsStaked was not called on the implementation")
		}
		if result != tt.expected {
			t.Errorf("IsStaked() = %v, want %v", result, tt.expected)
		}
	}
}
