package launchpad

import (
	"chain/runtime"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/access"
)

func TestRegisterInitializer(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(t *testing.T)
		initializer          func(s ILaunchpadStore) ILaunchpad
		callerRealm          runtime.Realm
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:        "register initializer is success",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"),
			initializer: makeMockInitializer("v1"),
		},
		{
			name: "register initializer is failed by duplicate registration",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"),
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
		resetTestState(t)

		if tt.setup != nil {
			tt.setup(t)
		}

		testing.SetRealm(tt.callerRealm)

		if tt.expectedHasAbort {
			uassert.AbortsContains(t, tt.expectedAbortMessage, func() {
				RegisterInitializer(cross, tt.initializer)
			})
		} else {
			RegisterInitializer(cross, tt.initializer)
		}
	}
}

func TestUpgradeImpl(t *testing.T) {
	govAddr := access.MustGetAddress(prbac.ROLE_GOVERNANCE.String())

	tests := []struct {
		name                 string
		setup                func(t *testing.T)
		packagePath          string
		callerRealm          runtime.Realm
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name: "upgrade impl is success with admin",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			packagePath: "gno.land/r/gnoswap/launchpad/v1",
			callerRealm: testing.NewUserRealm(adminAddr),
		},
		{
			name: "upgrade impl is success with governance",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			packagePath: "gno.land/r/gnoswap/launchpad/v1",
			callerRealm: testing.NewUserRealm(govAddr),
		},
		{
			name: "upgrade impl is failed by non-admin caller",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			packagePath:          "gno.land/r/gnoswap/launchpad/v1",
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/invalid"),
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized",
		},
		{
			name: "upgrade impl fails with non-registered package path",
			setup: func(t *testing.T) {
				// Register v1 but try to upgrade to v2 which is not registered
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			packagePath:          "gno.land/r/gnoswap/launchpad/v2",
			callerRealm:          testing.NewUserRealm(adminAddr),
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: initializer not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)

			if tt.setup != nil {
				tt.setup(t)
			}

			testing.SetRealm(tt.callerRealm)

			if tt.expectedHasAbort {
				uassert.AbortsContains(t, tt.expectedAbortMessage, func() {
					UpgradeImpl(cross, tt.packagePath)
				})
			} else {
				UpgradeImpl(cross, tt.packagePath)
			}
		})
	}
}

func TestCreateProject(t *testing.T) {
	tests := []struct {
		name             string
		projectName      string
		tokenPath        string
		recipient        address
		depositAmount    int64
		conditionTokens  string
		conditionAmounts string
		tier30Ratio      int64
		tier90Ratio      int64
		tier180Ratio     int64
		startTime        int64
		callerRealm      runtime.Realm
	}{
		{
			name:             "create project is success",
			projectName:      "Test Project",
			tokenPath:        "gno.land/r/token/test",
			recipient:        "g1addr",
			depositAmount:    1000000,
			conditionTokens:  "",
			conditionAmounts: "",
			tier30Ratio:      30,
			tier90Ratio:      30,
			tier180Ratio:     40,
			startTime:        1000000,
			callerRealm:      testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))
			testing.SetRealm(testing.NewUserRealm(adminAddr))
			UpgradeImpl(cross, "gno.land/r/gnoswap/launchpad/v1")

			testing.SetRealm(tt.callerRealm)
			result := CreateProject(cross, tt.projectName, tt.tokenPath, tt.recipient, tt.depositAmount, tt.conditionTokens, tt.conditionAmounts, tt.tier30Ratio, tt.tier90Ratio, tt.tier180Ratio, tt.startTime)
			_ = result
		})
	}
}

func TestTransferLeftFromProjectByAdmin(t *testing.T) {
	tests := []struct {
		name        string
		projectID   string
		recipient   address
		callerRealm runtime.Realm
	}{
		{
			name:        "transfer left from project by admin is success",
			projectID:   "project1",
			recipient:   "g1addr",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))
			testing.SetRealm(testing.NewUserRealm(adminAddr))
			UpgradeImpl(cross, "gno.land/r/gnoswap/launchpad/v1")

			testing.SetRealm(tt.callerRealm)
			result := TransferLeftFromProjectByAdmin(cross, tt.projectID, tt.recipient)
			_ = result
		})
	}
}

func TestCollectProtocolFee(t *testing.T) {
	tests := []struct {
		name        string
		callerRealm runtime.Realm
	}{
		{
			name:        "collect protocol fee is success",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))
			testing.SetRealm(testing.NewUserRealm(adminAddr))
			UpgradeImpl(cross, "gno.land/r/gnoswap/launchpad/v1")

			testing.SetRealm(tt.callerRealm)
			CollectProtocolFee(cross)
		})
	}
}

func TestDepositGns(t *testing.T) {
	tests := []struct {
		name                string
		targetProjectTierID string
		depositAmount       int64
		referrer            string
		callerRealm         runtime.Realm
	}{
		{
			name:                "deposit gns is success",
			targetProjectTierID: "tier1",
			depositAmount:       1000,
			referrer:            "",
			callerRealm:         testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))
			testing.SetRealm(testing.NewUserRealm(adminAddr))
			UpgradeImpl(cross, "gno.land/r/gnoswap/launchpad/v1")

			testing.SetRealm(tt.callerRealm)
			result := DepositGns(cross, tt.targetProjectTierID, tt.depositAmount, tt.referrer)
			_ = result
		})
	}
}

func TestCollectDepositGns(t *testing.T) {
	tests := []struct {
		name        string
		depositID   string
		callerRealm runtime.Realm
	}{
		{
			name:        "collect deposit gns is success",
			depositID:   "deposit1",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))
			testing.SetRealm(testing.NewUserRealm(adminAddr))
			UpgradeImpl(cross, "gno.land/r/gnoswap/launchpad/v1")

			testing.SetRealm(tt.callerRealm)
			result, err := CollectDepositGns(cross, tt.depositID)
			_, _ = result, err
		})
	}
}

func TestCollectRewardByDepositId(t *testing.T) {
	tests := []struct {
		name        string
		depositID   string
		callerRealm runtime.Realm
	}{
		{
			name:        "collect reward by deposit id is success",
			depositID:   "deposit1",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"),
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))
			testing.SetRealm(testing.NewUserRealm(adminAddr))
			UpgradeImpl(cross, "gno.land/r/gnoswap/launchpad/v1")

			testing.SetRealm(tt.callerRealm)
			result := CollectRewardByDepositId(cross, tt.depositID)
			_ = result
		})
	}
}

// ==================================
// Getter Tests
// ==================================

func TestGetProjectCount(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get project count is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetProjectCount()

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetProjectCount") != 1 {
				t.Error("GetProjectCount was not called on the implementation")
			}
		})
	}
}

func TestGetDepositCount(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get deposit count is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetDepositCount()

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetDepositCount") != 1 {
				t.Error("GetDepositCount was not called on the implementation")
			}
		})
	}
}

func TestGetProject(t *testing.T) {
	tests := []struct {
		name      string
		projectId string
	}{
		{
			name:      "get project is success",
			projectId: "project1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetProject(tt.projectId)

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetProject") != 1 {
				t.Error("GetProject was not called on the implementation")
			}
		})
	}
}

func TestGetDeposit(t *testing.T) {
	tests := []struct {
		name      string
		depositId string
	}{
		{
			name:      "get deposit is success",
			depositId: "deposit1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetDeposit(tt.depositId)

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetDeposit") != 1 {
				t.Error("GetDeposit was not called on the implementation")
			}
		})
	}
}

func TestGetProjectTier(t *testing.T) {
	tests := []struct {
		name      string
		projectId string
		tier      int64
	}{
		{
			name:      "get project tier is success",
			projectId: "project1",
			tier:      30,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetProjectTier(tt.projectId, tt.tier)

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetProjectTier") != 1 {
				t.Error("GetProjectTier was not called on the implementation")
			}
		})
	}
}

func TestGetClaimableRewardByProjectId(t *testing.T) {
	tests := []struct {
		name      string
		projectId string
	}{
		{
			name:      "get claimable reward by project id is success",
			projectId: "project1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetClaimableRewardByProjectId(tt.projectId)

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetClaimableRewardByProjectId") != 1 {
				t.Error("GetClaimableRewardByProjectId was not called on the implementation")
			}
		})
	}
}

func TestGetClaimableRewardByAddress(t *testing.T) {
	tests := []struct {
		name string
		addr address
	}{
		{
			name: "get claimable reward by address is success",
			addr: "g1test",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetClaimableRewardByAddress(tt.addr)

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetClaimableRewardByAddress") != 1 {
				t.Error("GetClaimableRewardByAddress was not called on the implementation")
			}
		})
	}
}

func TestGetProjectActiveStatus(t *testing.T) {
	tests := []struct {
		name      string
		projectId string
	}{
		{
			name:      "get project active status is success",
			projectId: "project1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetProjectActiveStatus(tt.projectId)

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetProjectActiveStatus") != 1 {
				t.Error("GetProjectActiveStatus was not called on the implementation")
			}
		})
	}
}

func TestGetProjects(t *testing.T) {
	tests := []struct {
		name   string
		offset int64
		limit  int64
	}{
		{
			name:   "get projects is success",
			offset: 0,
			limit:  10,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetProjects(tt.offset, tt.limit)

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetProjects") != 1 {
				t.Error("GetProjects was not called on the implementation")
			}
		})
	}
}

func TestGetDeposits(t *testing.T) {
	tests := []struct {
		name   string
		offset int64
		limit  int64
	}{
		{
			name:   "get deposits is success",
			offset: 0,
			limit:  10,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetDeposits(tt.offset, tt.limit)

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetDeposits") != 1 {
				t.Error("GetDeposits was not called on the implementation")
			}
		})
	}
}

func TestGetRewardManagerCount(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get reward manager count is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetRewardManagerCount()

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetRewardManagerCount") != 1 {
				t.Error("GetRewardManagerCount was not called on the implementation")
			}
		})
	}
}

func TestGetCurrentDepositId(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get current deposit id is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetCurrentDepositId()

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetCurrentDepositId") != 1 {
				t.Error("GetCurrentDepositId was not called on the implementation")
			}
		})
	}
}

func TestGetProjectCondition(t *testing.T) {
	tests := []struct {
		name      string
		projectId string
		tokenPath string
	}{
		{
			name:      "get project condition is success",
			projectId: "project1",
			tokenPath: "gno.land/r/token/test",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetProjectCondition(tt.projectId, tt.tokenPath)

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetProjectCondition") != 1 {
				t.Error("GetProjectCondition was not called on the implementation")
			}
		})
	}
}

func TestGetRewardManager(t *testing.T) {
	tests := []struct {
		name          string
		projectTierId string
	}{
		{
			name:          "get reward manager is success",
			projectTierId: "project1:30",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetRewardManager(tt.projectTierId)

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetRewardManager") != 1 {
				t.Error("GetRewardManager was not called on the implementation")
			}
		})
	}
}

func TestGetRewardState(t *testing.T) {
	tests := []struct {
		name          string
		projectTierId string
		depositId     string
	}{
		{
			name:          "get reward state is success",
			projectTierId: "project1:30",
			depositId:     "1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetRewardState(tt.projectTierId, tt.depositId)

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetRewardState") != 1 {
				t.Error("GetRewardState was not called on the implementation")
			}
		})
	}
}

func TestGetRewardManagers(t *testing.T) {
	tests := []struct {
		name   string
		offset int64
		limit  int64
	}{
		{
			name:   "get reward managers is success",
			offset: 0,
			limit:  10,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// Action
			GetRewardManagers(tt.offset, tt.limit)

			// Assert
			mockLaunchpad := implementation.(*MockLaunchpad)
			if mockLaunchpad.Response.CallCount("GetRewardManagers") != 1 {
				t.Error("GetRewardManagers was not called on the implementation")
			}
		})
	}
}

func TestGetImplementationPackagePath(t *testing.T) {
	tests := []struct {
		name         string
		packagePath  string
		expectedPath string
	}{
		{
			name:         "get package path after v1 registration",
			packagePath:  "gno.land/r/gnoswap/launchpad/v1",
			expectedPath: "gno.land/r/gnoswap/launchpad/v1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm(tt.packagePath))
			RegisterInitializer(cross, makeMockInitializer(tt.packagePath))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

			// when
			path := GetImplementationPackagePath()

			// then
			uassert.Equal(t, path, tt.expectedPath)
		})
	}
}
