package governance

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/uassert"
)


func TestUpgrade_RegisterInitializer(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(t *testing.T)
		initializer          func(s IGovernanceStore) IGovernance
		callerRealm          runtime.Realm
		expectedVersion      string
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:            "register initializer is success",
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"),
			initializer:     makeMockInitializer("v1"),
			expectedVersion: "v1",
		},
		{
			name: "register multiple different initializers",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/new_version"),
			initializer:     makeMockInitializer("new_version"),
			expectedVersion: "v1",
		},
		{
			name: "register initializer is failed by duplicate registration",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"),
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
		t.Run(tt.name, func(t *testing.T) {
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

				impl := implementation.(*MockGovernance)
				uassert.Equal(t, impl.Version, tt.expectedVersion)
			}
		})
	}
}

func TestUpgrade_UpgradeImpl(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(t *testing.T)
		targetPackagePath    string
		callerRealm          runtime.Realm
		expectedPath         string
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name: "upgrade from v1 to v2 by admin",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v2"))
				RegisterInitializer(cross, makeMockInitializer("v2"))
			},
			targetPackagePath: "gno.land/r/gnoswap/gov/governance/v2",
			callerRealm:       testing.NewUserRealm(adminAddr),
			expectedPath:      "gno.land/r/gnoswap/gov/governance/v2",
		},
		{
			name: "fail - unauthorized caller",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v2"))
				RegisterInitializer(cross, makeMockInitializer("v2"))
			},
			targetPackagePath:    "gno.land/r/gnoswap/gov/governance/v2",
			callerRealm:          testing.NewUserRealm("g1unauthorized"),
			expectedHasAbort:     true,
			expectedAbortMessage: "caller g1unauthorized is not admin or governance",
		},
		{
			name: "fail - target version not registered",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			targetPackagePath:    "gno.land/r/gnoswap/gov/governance/v999",
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
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))
						UpgradeImpl(cur, tt.targetPackagePath)
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))
					UpgradeImpl(cur, tt.targetPackagePath)
				}(cross)

				path := GetImplementationPackagePath()
				uassert.Equal(t, path, tt.expectedPath)
			}
		})
	}
}

func TestUpgrade_ProposeText(t *testing.T) {
	tests := []struct {
		name        string
		title       string
		description string
	}{
		{
			name:        "propose text is success",
			title:       "Test Proposal",
			description: "Test Description",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			ProposeText(cross, tt.title, tt.description)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("ProposeText") != 1 {
				t.Error("ProposeText was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_ProposeCommunityPoolSpend(t *testing.T) {
	tests := []struct {
		name        string
		title       string
		description string
		to          address
		tokenPath   string
		amount      int64
	}{
		{
			name:        "propose community pool spend is success",
			title:       "Test Spend",
			description: "Test Description",
			to:          "g1test",
			tokenPath:   "gno.land/r/demo/gns",
			amount:      1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			ProposeCommunityPoolSpend(cross, tt.title, tt.description, tt.to, tt.tokenPath, tt.amount)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("ProposeCommunityPoolSpend") != 1 {
				t.Error("ProposeCommunityPoolSpend was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_ProposeParameterChange(t *testing.T) {
	tests := []struct {
		name         string
		title        string
		description  string
		numToExecute int64
		executions   string
	}{
		{
			name:         "propose parameter change is success",
			title:        "Test Parameter Change",
			description:  "Test Description",
			numToExecute: 1,
			executions:   "test_execution",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			ProposeParameterChange(cross, tt.title, tt.description, tt.numToExecute, tt.executions)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("ProposeParameterChange") != 1 {
				t.Error("ProposeParameterChange was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_Vote(t *testing.T) {
	tests := []struct {
		name       string
		proposalId int64
		yes        bool
	}{
		{
			name:       "vote yes is success",
			proposalId: 1,
			yes:        true,
		},
		{
			name:       "vote no is success",
			proposalId: 1,
			yes:        false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			Vote(cross, tt.proposalId, tt.yes)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("Vote") != 1 {
				t.Error("Vote was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_Execute(t *testing.T) {
	tests := []struct {
		name       string
		proposalId int64
	}{
		{
			name:       "execute is success",
			proposalId: 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			Execute(cross, tt.proposalId)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("Execute") != 1 {
				t.Error("Execute was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_Cancel(t *testing.T) {
	tests := []struct {
		name       string
		proposalId int64
	}{
		{
			name:       "cancel is success",
			proposalId: 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			Cancel(cross, tt.proposalId)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("Cancel") != 1 {
				t.Error("Cancel was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_Reconfigure(t *testing.T) {
	tests := []struct {
		name                          string
		votingStartDelay              int64
		votingPeriod                  int64
		votingWeightSmoothingDuration int64
		quorum                        int64
		proposalCreationThreshold     int64
		executionDelay                int64
		executionWindow               int64
	}{
		{
			name:                          "reconfigure is success",
			votingStartDelay:              100,
			votingPeriod:                  200,
			votingWeightSmoothingDuration: 50,
			quorum:                        1000,
			proposalCreationThreshold:     500,
			executionDelay:                150,
			executionWindow:               300,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			Reconfigure(cross, tt.votingStartDelay, tt.votingPeriod, tt.votingWeightSmoothingDuration, tt.quorum, tt.proposalCreationThreshold, tt.executionDelay, tt.executionWindow)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("Reconfigure") != 1 {
				t.Error("Reconfigure was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetProposerByProposalId(t *testing.T) {
	tests := []struct {
		name string
		id   int64
	}{
		{
			name: "get proposer by proposal id is success",
			id:   1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetProposerByProposalId(tt.id)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetProposerByProposalId") != 1 {
				t.Error("GetProposerByProposalId was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetProposalTypeByProposalId(t *testing.T) {
	tests := []struct {
		name string
		id   int64
	}{
		{
			name: "get proposal type by proposal id is success",
			id:   1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetProposalTypeByProposalId(tt.id)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetProposalTypeByProposalId") != 1 {
				t.Error("GetProposalTypeByProposalId was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetYeaByProposalId(t *testing.T) {
	tests := []struct {
		name string
		id   int64
	}{
		{
			name: "get yea by proposal id is success",
			id:   1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetYeaByProposalId(tt.id)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetYeaByProposalId") != 1 {
				t.Error("GetYeaByProposalId was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetNayByProposalId(t *testing.T) {
	tests := []struct {
		name string
		id   int64
	}{
		{
			name: "get nay by proposal id is success",
			id:   1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetNayByProposalId(tt.id)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetNayByProposalId") != 1 {
				t.Error("GetNayByProposalId was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetProposalById(t *testing.T) {
	tests := []struct {
		name string
		id   int64
	}{
		{
			name: "get proposal by id is success",
			id:   1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetProposalById(tt.id)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetProposalById") != 1 {
				t.Error("GetProposalById was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetVoteStatusFromProposalById(t *testing.T) {
	tests := []struct {
		name string
		id   int64
	}{
		{
			name: "get vote status from proposal by id is success",
			id:   1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetVoteStatusFromProposalById(tt.id)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetVoteStatusFromProposalById") != 1 {
				t.Error("GetVoteStatusFromProposalById was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetVoteByAddressFromProposalById(t *testing.T) {
	tests := []struct {
		name string
		addr address
		id   int64
	}{
		{
			name: "get vote by address from proposal by id is success",
			addr: "g1test",
			id:   1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetVoteByAddressFromProposalById(tt.addr, tt.id)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetVoteByAddressFromProposalById") != 1 {
				t.Error("GetVoteByAddressFromProposalById was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetConfigVersionByProposalId(t *testing.T) {
	tests := []struct {
		name string
		id   int64
	}{
		{
			name: "get config version by proposal id is success",
			id:   1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetConfigVersionByProposalId(tt.id)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetConfigVersionByProposalId") != 1 {
				t.Error("GetConfigVersionByProposalId was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetQuorumAmountByProposalId(t *testing.T) {
	tests := []struct {
		name string
		id   int64
	}{
		{
			name: "get quorum amount by proposal id is success",
			id:   1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetQuorumAmountByProposalId(tt.id)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetQuorumAmountByProposalId") != 1 {
				t.Error("GetQuorumAmountByProposalId was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetTitleByProposalId(t *testing.T) {
	tests := []struct {
		name string
		id   int64
	}{
		{
			name: "get title by proposal id is success",
			id:   1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetTitleByProposalId(tt.id)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetTitleByProposalId") != 1 {
				t.Error("GetTitleByProposalId was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetDescriptionByProposalId(t *testing.T) {
	tests := []struct {
		name string
		id   int64
	}{
		{
			name: "get description by proposal id is success",
			id:   1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetDescriptionByProposalId(tt.id)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetDescriptionByProposalId") != 1 {
				t.Error("GetDescriptionByProposalId was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetExecutionStateByProposalId(t *testing.T) {
	tests := []struct {
		name string
		id   int64
	}{
		{
			name: "get execution state by proposal id is success",
			id:   1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetExecutionStateByProposalId(tt.id)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetExecutionStateByProposalId") != 1 {
				t.Error("GetExecutionStateByProposalId was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetLatestConfig(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get latest config is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetLatestConfig()

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetLatestConfig") != 1 {
				t.Error("GetLatestConfig was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetConfig(t *testing.T) {
	tests := []struct {
		name          string
		configVersion int64
	}{
		{
			name:          "get config is success",
			configVersion: 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetConfig(tt.configVersion)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetConfig") != 1 {
				t.Error("GetConfig was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetVoteWeight(t *testing.T) {
	tests := []struct {
		name       string
		proposalID int64
		address    address
	}{
		{
			name:       "get vote weight is success",
			proposalID: 1,
			address:    "g1test",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetVoteWeight(tt.proposalID, tt.address)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetVoteWeight") != 1 {
				t.Error("GetVoteWeight was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetVotedHeight(t *testing.T) {
	tests := []struct {
		name       string
		proposalID int64
		address    address
	}{
		{
			name:       "get voted height is success",
			proposalID: 1,
			address:    "g1test",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetVotedHeight(tt.proposalID, tt.address)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetVotedHeight") != 1 {
				t.Error("GetVotedHeight was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetVotedAt(t *testing.T) {
	tests := []struct {
		name       string
		proposalID int64
		address    address
	}{
		{
			name:       "get voted at is success",
			proposalID: 1,
			address:    "g1test",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// Action
			GetVotedAt(tt.proposalID, tt.address)

			// Assert
			mockGovernance := implementation.(*MockGovernance)
			if mockGovernance.Response.CallCount("GetVotedAt") != 1 {
				t.Error("GetVotedAt was not called on the implementation")
			}
		})
	}
}

func TestUpgrade_GetImplementationPackagePath(t *testing.T) {
	tests := []struct {
		name         string
		packagePath  string
		expectedPath string
	}{
		{
			name:         "get package path after v1 registration",
			packagePath:  "gno.land/r/gnoswap/gov/governance/v1",
			expectedPath: "gno.land/r/gnoswap/gov/governance/v1",
		},
		{
			name:         "get package path after v2 registration",
			packagePath:  "gno.land/r/gnoswap/gov/governance/v2",
			expectedPath: "gno.land/r/gnoswap/gov/governance/v2",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm(tt.packagePath))
			RegisterInitializer(cross, makeMockInitializer(tt.packagePath))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

			// when
			path := GetImplementationPackagePath()

			// then
			uassert.Equal(t, path, tt.expectedPath)
		})
	}
}
