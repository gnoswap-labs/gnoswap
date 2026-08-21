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
			name:  "GetProposalCommunityPoolSpendInfo",
			setup: func(m *MockGovernance) {
				stored := newProposalFixture()
				m.Response.Set("GetProposalCommunityPoolSpendInfo", stored.data.communityPoolSpend, nil)
				m.Response.Set("storedProposal", stored)
			},
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
				info := storedTestProposal(m).data.communityPoolSpend
				uassert.Equal(t, "token", info.tokenPath)
				uassert.Equal(t, int64(70), info.amount)
			},
		},
		{
			name:  "GetProposalExecutionInfo",
			setup: func(m *MockGovernance) {
				stored := newProposalFixture()
				m.Response.Set("GetProposalExecutionInfo", stored.data.execution, nil)
				m.Response.Set("storedProposal", stored)
			},
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
				info := storedTestProposal(m).data.execution
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

// storedTestProposal returns the proposal the mock's read-only view wraps, so a
// test can assert the stored copy was not reached through the view.
func storedTestProposal(m *MockGovernance) *Proposal {
	return m.Response.data["storedProposal"][0].(*Proposal)
}
