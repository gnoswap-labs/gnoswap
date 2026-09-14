package governance

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestProposalStatusUpdatesPreserveOriginal(t *testing.T) {
	original := MakeProposalStatusBy(
		MakeProposalScheduleStatus(10, 20, 30, 40, 50),
		MakeProposalActionStatus(true),
		MakeProposalVoteStatus(1000, 50),
	)
	updated := original.WithVoteStatus(original.VoteStatus().WithYesWeight(600))
	updated = updated.WithActionStatus(updated.ActionStatus().WithExecuted(true))
	uassert.Equal(t, int64(0), original.YesWeight())
	uassert.Equal(t, int64(600), updated.YesWeight())
	uassert.False(t, original.ActionStatus().IsExecuted())
	uassert.True(t, updated.ActionStatus().IsExecuted())
}
