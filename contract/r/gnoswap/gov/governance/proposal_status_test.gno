package governance

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestProposalStatus_NewProposalStatusBy tests the creation of proposal status with components
func TestProposalStatus_NewProposalStatusBy(t *testing.T) {
	tests := []struct {
		name            string
		schedule        *ProposalScheduleStatus
		actionExecutable bool
		quorumPercent   int64
		setupAction     func(*ProposalActionStatus)
		setupVote       func(*ProposalVoteStatus)
	}{
		{
			name: "create with all components",
			schedule: NewProposalScheduleStatusInstance(
				1000, 1100, 1300, 1400, 1600,
			),
			actionExecutable: true,
			quorumPercent:    50,
			setupAction:      func(a *ProposalActionStatus) {}, // default values
			setupVote:        func(v *ProposalVoteStatus) {},   // default values
		},
		{
			name: "create with executed status",
			schedule: NewProposalScheduleStatusInstance(
				1000, 1100, 1300, 1400, 1600,
			),
			actionExecutable: true,
			quorumPercent:    50,
			setupAction: func(a *ProposalActionStatus) {
				a.SetExecuted(true)
				a.SetExecutedAt(1500)
				a.SetExecutedHeight(150)
				a.SetExecutedBy(address("g1executor"))
			},
			setupVote: func(v *ProposalVoteStatus) {
				v.SetYesWeight(600)
				v.SetNoWeight(300)
			},
		},
		{
			name: "create with canceled status",
			schedule: NewProposalScheduleStatusInstance(
				1000, 1100, 1300, 1400, 1600,
			),
			actionExecutable: true,
			quorumPercent:    50,
			setupAction: func(a *ProposalActionStatus) {
				a.SetCanceled(true)
				a.SetCanceledAt(1200)
				a.SetCanceledHeight(120)
				a.SetCanceledBy(address("g1canceler"))
			},
			setupVote: func(v *ProposalVoteStatus) {
				v.SetYesWeight(200)
				v.SetNoWeight(300)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			actionStatus := NewProposalActionStatus(tt.actionExecutable)
			voteStatus := NewProposalVoteStatus(1000, tt.quorumPercent)

			tt.setupAction(actionStatus)
			tt.setupVote(voteStatus)

			// when
			status := NewProposalStatusBy(
				tt.schedule,
				actionStatus,
				voteStatus,
			)

			// then
			uassert.NotNil(t, status)
			uassert.NotNil(t, status.Schedule())
			uassert.NotNil(t, status.ActionStatus())
			uassert.NotNil(t, status.VoteStatus())

			// Verify delegated getters
			uassert.Equal(t, status.YesWeight(), voteStatus.YesWeight())
			uassert.Equal(t, status.NoWeight(), voteStatus.NoWeight())
		})
	}
}

// TestProposalStatus_DelegatedMethods tests methods delegated to vote status
func TestProposalStatus_DelegatedMethods(t *testing.T) {
	tests := []struct {
		name      string
		yesWeight int64
		noWeight  int64
	}{
		{
			name:      "yes majority",
			yesWeight: 600,
			noWeight:  300,
		},
		{
			name:      "no majority",
			yesWeight: 300,
			noWeight:  700,
		},
		{
			name:      "equal votes",
			yesWeight: 500,
			noWeight:  500,
		},
		{
			name:      "no votes",
			yesWeight: 0,
			noWeight:  0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			schedule := NewProposalScheduleStatusInstance(1000, 1100, 1300, 1400, 1600)
			actionStatus := NewProposalActionStatus(true)
			voteStatus := NewProposalVoteStatus(1000, 50)
			voteStatus.SetYesWeight(tt.yesWeight)
			voteStatus.SetNoWeight(tt.noWeight)

			// when
			status := NewProposalStatusBy(schedule, actionStatus, voteStatus)

			// then
			uassert.Equal(t, status.YesWeight(), tt.yesWeight)
			uassert.Equal(t, status.NoWeight(), tt.noWeight)
		})
	}
}
