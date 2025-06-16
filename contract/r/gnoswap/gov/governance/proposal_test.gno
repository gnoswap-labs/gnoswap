package governance

import (
	"errors"
	"std"
	"testing"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/gns"

	gs "gno.land/r/gnoswap/v1/gov/staker"
)

var (
	proposalAddr = testutils.TestAddress("proposal")
	toAddr       = testutils.TestAddress("to")

	voter1 = testutils.TestAddress("voter1")
	voter2 = testutils.TestAddress("voter2")

	insufficientProposer = testutils.TestAddress("insufficient")
)

func resetGlobalStateProposal(t *testing.T) {
	t.Helper()
	proposalId = 0
	proposals = avl.NewTree()
	proposalIdListByProposer = avl.NewTree()
}

func mockCheckEnoughXGnsToPropose(proposer std.Address) (bool, uint64, uint64) {
	if proposer == insufficientProposer {
		return false, 500, 1000
	}
	return true, 1000, 1000
}

func mockGetPossibleVotingAddressWithWeight(t *testing.T, timestamp uint64) (uint64, map[std.Address]uint64) {
	t.Helper()
	weights := make(map[std.Address]uint64)
	weights[voter1] = 100
	weights[voter2] = 200
	return 300, weights
}

func TestProposeText(t *testing.T) {
	// override for test
	origProposalCreationThreshold := config.ProposalCreationThreshold
	config.ProposalCreationThreshold = 0

	resetGlobalStateProposal(t)

	tests := []struct {
		name        string
		proposer    std.Address
		title       string
		description string
		expectError bool
	}{
		{
			name:        "Valid text proposal",
			proposer:    proposalAddr,
			title:       "Test Proposal",
			description: "This is a test proposal",
			expectError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var pid uint64
			var err error
			func() {
				defer func() {
					if r := recover(); r != nil {
						err = r.(error)
					}
				}()
				pid = ProposeText(cross, tt.title, tt.description)
			}()

			uassert.NoError(t, err)

			prop, exists := proposals.Get(formatUint(pid))
			uassert.True(t, exists)

			proposal := prop.(ProposalInfo)

			uassert.Equal(t, proposal.Title, tt.title)
			uassert.Equal(t, proposal.Description, tt.description)
			uassert.Equal(t, proposal.ProposalType.String(), Text.String())
			uassert.True(t, proposal.State.Created)
			uassert.True(t, proposal.State.Upcoming)
		})
	}

	config.ProposalCreationThreshold = origProposalCreationThreshold
}

func TestProposeCommunityPoolSpend(t *testing.T) {
	t.Skip("")

	resetGlobalStateProposal(t)

	testing.SetRealm(adminRealm)
	func() {
		testing.SetRealm(std.NewUserRealm(proposalAddr))
		// Setup xGNS for proposal creation
		gns.Approve(cross, govStakerAddr, int64(2000000000))
	}()

	testing.SetRealm(adminRealm)
	func() {
		testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/gov/governance"))
		gs.Delegate(cross, proposalAddr, uint64(2000000000), "") // self delegate
	}()

	testing.SkipHeights(1)

	tests := []struct {
		name        string
		proposer    std.Address
		title       string
		description string
		to          std.Address
		tokenPath   string
		amount      uint64
		expectError bool
	}{
		{
			name:        "Valid community pool spend proposal",
			proposer:    proposalAddr,
			title:       "Community Spend",
			description: "Fund community initiative",
			to:          toAddr,
			tokenPath:   "token/path",
			amount:      1000,
			expectError: false,
		},
		{
			name:        "Insufficient balance for proposal",
			proposer:    insufficientProposer,
			title:       "Invalid Spend",
			description: "Should fail",
			to:          toAddr,
			tokenPath:   "token/path",
			amount:      1000,
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var pid uint64
			var err error
			func() {
				defer func() {
					if r := recover(); r != nil {
						switch r.(type) {
						case string:
							err = errors.New(r.(string))
						case error:
							err = r.(error)
						default:
							err = errors.New("unknown error")
						}
					}
				}()
				pid = ProposeCommunityPoolSpend(
					cross,
					tt.title, tt.description, tt.to, tt.tokenPath, tt.amount)
			}()

			uassert.NoError(t, err)

			prop, exists := proposals.Get(formatUint(pid))
			uassert.True(t, exists)

			proposal := prop.(ProposalInfo)

			uassert.Equal(t, proposal.ProposalType.String(), CommunityPoolSpend.String())
			uassert.Equal(t, proposal.CommunityPoolSpend.To, tt.to)
			uassert.Equal(t, proposal.CommunityPoolSpend.Amount, tt.amount)
		})
	}
}

func TestIntegratedProposeParameterChange(t *testing.T) {
	t.Skip("The proposal needs to be modified to ensure it has sufficient xGNS.")

	tests := []struct {
		name           string
		proposer       std.Address
		title          string
		description    string
		numToExecute   uint64
		executions     string
		expectError    bool
		errorContains  string
		isRoleChange   bool
		roleName       string
		permissionName string
		action         RoleChangeAction
	}{
		{
			name:         "Valid parameter change proposal",
			proposer:     proposalAddr,
			title:        "Change Voting Period",
			description:  "Update voting period to 14 days",
			numToExecute: 2,
			executions:   "gno.land/r/gnoswap/v1/gns*EXE*SetAvgBlockTimeInMs*EXE*123*GOV*gno.land/r/gnoswap/v1/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/v1/gns,g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d,905",
			expectError:  false,
			isRoleChange: false,
		},
		{
			name:           "Valid role change proposal",
			proposer:       proposalAddr,
			title:          "Add Admin Role",
			description:    "Create new admin role with single address permission",
			numToExecute:   1,
			executions:     "ROLE_CHANGE:admin:can_manage:AddRole:SingleAddressChecker:g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d::0",
			expectError:    false,
			isRoleChange:   true,
			roleName:       "admin",
			permissionName: "can_manage",
			action:         AddRole,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetGlobalStateProposal(t)

			testing.SetRealm(adminRealm)
			func() {
				testing.SetRealm(std.NewUserRealm(proposalAddr))
				// Setup xGNS for proposal creation
				gns.Approve(cross, govStakerAddr, int64(2000000000))
			}()

			testing.SetRealm(adminRealm)
			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/gov/governance"))
				gs.Delegate(cross, proposalAddr, uint64(2000000000), "") // self delegate
				testing.SkipHeights(1)
			}()

			var pid uint64
			var err error
			func() {
				defer func() {
					if r := recover(); r != nil {
						t.Errorf("Unexpected error: %v", r)
					}
				}()
				pid = ProposeParameterChange(
					cross,
					tt.title,
					tt.description,
					tt.numToExecute,
					tt.executions,
				)
			}()

			if tt.expectError {
				uassert.Error(t, err)
				return
			}
			uassert.NoError(t, err)

			prop, exists := proposals.Get(formatUint(pid))
			uassert.True(t, exists)

			proposal := prop.(ProposalInfo)

			uassert.Equal(t, proposal.Title, tt.title)
			uassert.Equal(t, proposal.Description, tt.description)

			if tt.isRoleChange {
				uassert.Equal(t, proposal.ProposalType.String(), RoleChange.String())
				uassert.Equal(t, proposal.RoleChange.RoleName, tt.roleName)
				uassert.Equal(t, proposal.RoleChange.PermissionName, tt.permissionName)
				if tt.action != proposal.RoleChange.Action {
					t.Errorf("Expected action: %v, got: %v", tt.action, proposal.RoleChange.Action)
				}
			} else {
				uassert.Equal(t, proposal.ProposalType.String(), ParameterChange.String())
				uassert.Equal(t, proposal.Execution.Num, tt.numToExecute)
			}

			uassert.True(t, proposal.State.Created)
			uassert.True(t, proposal.State.Upcoming)
			uassert.False(t, proposal.State.Active)
			uassert.True(t, proposal.Yea.IsZero())
			uassert.True(t, proposal.Nay.IsZero())
		})
	}
}
