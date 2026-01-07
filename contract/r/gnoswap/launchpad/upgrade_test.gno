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
