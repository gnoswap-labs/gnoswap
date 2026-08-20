package governance

import (
	"testing"

	bptree "gno.land/p/nt/bptree/v0"
	rotree "gno.land/p/nt/bptree/v0/rotree"
	uassert "gno.land/p/nt/uassert/v0"
)

func newProposalFixture() *Proposal {
	schedule := NewProposalScheduleStatus(10, 20, 30, 40, 50)
	actionStatus := NewProposalActionStatus(true)
	voteStatus := NewProposalVoteStatus(100, 60)
	status := NewProposalStatusBy(schedule, actionStatus, voteStatus)
	metadata := NewProposalMetadata("title", "description")
	data := NewProposalData(ParameterChange, NewCommunityPoolSpendInfo(adminAddr, "token", 70), NewExecutionInfo(2, []string{"msg1", "msg2"}))
	return NewProposal(1, status, metadata, data, adminAddr, 2, 80, 100)
}

func newVotingInfoFixture() *VotingInfo {
	votingInfo := NewVotingInfo(100)
	votingInfo.SetVoted(true)
	votingInfo.SetVotedYes(true)
	votingInfo.SetVotedWeight(90)
	votingInfo.SetVotedHeight(80)
	votingInfo.SetVotedAt(70)
	return votingInfo
}

func TestMutableGovernanceGetterIsolation(cur realm, t *testing.T) {
	tests := []struct {
		name      string
		setup     func(m *MockGovernance)
		getter    func(t *testing.T) any
		mutate    func(result any)
		assertRaw func(t *testing.T, m *MockGovernance)
	}{
		{
			name:  "GetProposal",
			setup: func(m *MockGovernance) { m.Response.Set("GetProposal", newProposalFixture(), nil) },
			getter: func(t *testing.T) any {
				proposal, err := GetProposal(1)
				uassert.NoError(t, err)
				return proposal
			},
			mutate: func(result any) {
				proposal := result.(*Proposal)
				proposal.status.schedule.createTime = 111
				proposal.status.schedule.activeTime = 222
				proposal.status.voteStatus.yea = 333
				proposal.status.voteStatus.nay = 444
				proposal.status.actionStatus.executed = true
				proposal.metadata.title = "mutated title"
				proposal.metadata.description = "mutated description"
				proposal.data.execution.num = 9
				proposal.data.execution.msgs[0] = "mutated-msg"
				proposal.data.execution.msgs = append(proposal.data.execution.msgs, "extra")
				proposal.data.communityPoolSpend.amount = 555
			},
			assertRaw: func(t *testing.T, m *MockGovernance) {
				proposal := m.Response.data["GetProposal"][0].(*Proposal)
				uassert.Equal(t, int64(10), proposal.status.schedule.createTime)
				uassert.Equal(t, int64(20), proposal.status.schedule.activeTime)
				uassert.Equal(t, int64(0), proposal.status.voteStatus.yea)
				uassert.Equal(t, int64(0), proposal.status.voteStatus.nay)
				uassert.Equal(t, false, proposal.status.actionStatus.executed)
				uassert.Equal(t, "title", proposal.metadata.title)
				uassert.Equal(t, "description", proposal.metadata.description)
				uassert.Equal(t, int64(2), proposal.data.execution.num)
				uassert.Equal(t, "msg1", proposal.data.execution.msgs[0])
				uassert.Equal(t, 2, len(proposal.data.execution.msgs))
				uassert.Equal(t, int64(70), proposal.data.communityPoolSpend.amount)
			},
		},
		{
			name:  "GetVotingInfo",
			setup: func(m *MockGovernance) { m.Response.Set("GetVotingInfo", newVotingInfoFixture(), nil) },
			getter: func(t *testing.T) any {
				votingInfo, err := GetVotingInfo(1, adminAddr)
				uassert.NoError(t, err)
				return votingInfo
			},
			mutate: func(result any) {
				votingInfo := result.(*VotingInfo)
				votingInfo.SetAvailableVoteWeight(1)
				votingInfo.SetVotedWeight(2)
				votingInfo.SetVotedHeight(3)
				votingInfo.SetVotedAt(4)
				votingInfo.SetVotedYes(false)
				votingInfo.SetVoted(false)
			},
			assertRaw: func(t *testing.T, m *MockGovernance) {
				votingInfo := m.Response.data["GetVotingInfo"][0].(*VotingInfo)
				uassert.Equal(t, int64(100), votingInfo.AvailableVoteWeight())
				uassert.Equal(t, int64(90), votingInfo.VotedWeight())
				uassert.Equal(t, int64(80), votingInfo.VotedHeight())
				uassert.Equal(t, int64(70), votingInfo.VotedAt())
				uassert.Equal(t, true, votingInfo.VotedYes())
				uassert.Equal(t, true, votingInfo.IsVoted())
			},
		},
		{
			name:  "GetProposalCommunityPoolSpendInfo",
			setup: func(m *MockGovernance) { m.Response.Set("GetProposal", newProposalFixture(), nil) },
			getter: func(t *testing.T) any {
				info, err := GetProposalCommunityPoolSpendInfo(1)
				uassert.NoError(t, err)
				return info
			},
			mutate: func(result any) {
				info := result.(*CommunityPoolSpendInfo)
				info.tokenPath = "mutated"
				info.amount = 999
			},
			assertRaw: func(t *testing.T, m *MockGovernance) {
				info := m.Response.data["GetProposal"][0].(*Proposal).data.communityPoolSpend
				uassert.Equal(t, "token", info.tokenPath)
				uassert.Equal(t, int64(70), info.amount)
			},
		},
		{
			name:  "GetProposalExecutionInfo",
			setup: func(m *MockGovernance) { m.Response.Set("GetProposal", newProposalFixture(), nil) },
			getter: func(t *testing.T) any {
				info, err := GetProposalExecutionInfo(1)
				uassert.NoError(t, err)
				return info
			},
			mutate: func(result any) {
				info := result.(*ExecutionInfo)
				info.num = 999
				info.msgs[0] = "mutated"
				info.msgs = append(info.msgs, "extra")
			},
			assertRaw: func(t *testing.T, m *MockGovernance) {
				info := m.Response.data["GetProposal"][0].(*Proposal).data.execution
				uassert.Equal(t, int64(2), info.num)
				uassert.Equal(t, "msg1", info.msgs[0])
				uassert.Equal(t, 2, len(info.msgs))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			mockGovernance := newMockGovernance("v1")
			implementation = mockGovernance
			tt.setup(mockGovernance)
			result := tt.getter(t)
			tt.mutate(result)
			tt.assertRaw(t, mockGovernance)
		})
	}
}

func TestReadOnlyTreeGetters(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		method   string
		getter   func() *rotree.ReadOnlyTree
		wantKeys []string
	}{
		{
			name:     "GetProposals",
			method:   "GetProposals",
			getter:   func() *rotree.ReadOnlyTree { return GetProposals() },
			wantKeys: []string{"1", "2"},
		},
		{
			name:     "GetVotingInfos",
			method:   "GetVotingInfos",
			getter:   func() *rotree.ReadOnlyTree { return GetVotingInfos(1) },
			wantKeys: []string{adminAddr.String()},
		},
		{
			name:     "GetUserProposals",
			method:   "GetUserProposals",
			getter:   func() *rotree.ReadOnlyTree { return GetUserProposals() },
			wantKeys: []string{adminAddr.String()},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			mockGovernance := newMockGovernance("v1")
			implementation = mockGovernance

			stored := bptree.NewBPTree32()
			for i, key := range tt.wantKeys {
				stored.Set(key, i)
			}
			mockGovernance.Response.Set(tt.method, rotree.Wrap(stored, nil))

			got := tt.getter()
			uassert.Equal(t, len(tt.wantKeys), got.Size())

			keys := make([]string, 0, got.Size())
			got.IterateByOffset(0, got.Size(), func(key string, _ any) bool {
				keys = append(keys, key)
				return false
			})
			for i, want := range tt.wantKeys {
				uassert.Equal(t, want, keys[i])
			}

			// The view refuses writes, so the stored tree stays untouched.
			uassert.PanicsWithMessage(t, cur, "Set operation not supported on ReadOnlyTree", func() {
				got.Set("mutated", 0)
			})
			uassert.PanicsWithMessage(t, cur, "Remove operation not supported on ReadOnlyTree", func() {
				got.Remove(tt.wantKeys[0])
			})
			uassert.Equal(t, len(tt.wantKeys), stored.Size())
		})
	}
}

func TestReadOnlyTreeGetters_NoImplementationResponse(cur realm, t *testing.T) {
	resetTestState(t)
	mockGovernance := newMockGovernance("v1")
	implementation = mockGovernance

	uassert.True(t, GetProposals() == nil)
	uassert.True(t, GetVotingInfos(1) == nil)
	uassert.True(t, GetUserProposals() == nil)
}
