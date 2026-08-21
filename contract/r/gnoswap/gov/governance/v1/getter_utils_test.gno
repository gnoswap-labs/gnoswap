package governance

import (
	"chain/runtime"
	"testing"
	"time"

	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/gov/governance"
)

func newCloneTestProposal(cur realm, t *testing.T) *governance.Proposal {
	t.Helper()

	gv := setupGetterTest(cur, t)
	config, _ := gv.store.GetConfig(1)
	baseTime := time.Now().Unix()

	return governance.NewProposal(
		1,
		NewProposalStatus(config, 1000, governance.Text.IsExecutable(), baseTime, 1000),
		governance.NewProposalMetadata("Test Proposal", "Test Description"),
		governance.NewProposalData(governance.Text, nil, nil),
		address("g1proposer"),
		1,
		baseTime,
		runtime.ChainHeight(),
	)
}

func TestCloneProposalEntry(cur realm, t *testing.T) {
	t.Run("returns nil for a value that is not a proposal", func(cur realm, t *testing.T) {
		uassert.Equal(t, nil, cloneProposalEntry("not a proposal"))
		uassert.Equal(t, nil, cloneProposalEntry(nil))
	})

	t.Run("returns a distinct copy per read", func(cur realm, t *testing.T) {
		stored := newCloneTestProposal(cur, t)

		first, ok := cloneProposalEntry(stored).(*governance.Proposal)
		uassert.True(t, ok)
		second, ok := cloneProposalEntry(stored).(*governance.Proposal)
		uassert.True(t, ok)

		uassert.False(t, first == stored)
		uassert.False(t, first == second)
		uassert.Equal(t, stored.ID(), first.ID())
		uassert.Equal(t, stored.Title(), first.Title())
	})
}

func TestCloneVotingInfoEntry(cur realm, t *testing.T) {
	t.Run("returns nil for a value that is not a voting info", func(cur realm, t *testing.T) {
		uassert.Equal(t, nil, cloneVotingInfoEntry("not a voting info"))
		uassert.Equal(t, nil, cloneVotingInfoEntry(nil))
	})

	t.Run("returns a copy the caller cannot write back through", func(cur realm, t *testing.T) {
		stored := governance.NewVotingInfo(1000)
		stored.SetVotedYes(true)

		cloned, ok := cloneVotingInfoEntry(stored).(*governance.VotingInfo)
		uassert.True(t, ok)
		uassert.False(t, cloned == stored)
		uassert.Equal(t, stored.VotedYes(), cloned.VotedYes())

		cloned.SetVotedYes(false)
		uassert.True(t, stored.VotedYes())
	})
}

func TestCloneProposalIDsEntry(cur realm, t *testing.T) {
	t.Run("returns nil for a value that is not an ID slice", func(cur realm, t *testing.T) {
		uassert.Equal(t, nil, cloneProposalIDsEntry("not a slice"))
		uassert.Equal(t, nil, cloneProposalIDsEntry([]string{"1"}))
		uassert.Equal(t, nil, cloneProposalIDsEntry(nil))
	})

	t.Run("returns a copy the caller cannot write back through", func(cur realm, t *testing.T) {
		stored := []int64{1, 2, 3}

		cloned, ok := cloneProposalIDsEntry(stored).([]int64)
		uassert.True(t, ok)
		uassert.Equal(t, len(stored), len(cloned))

		cloned[0] = 999
		uassert.Equal(t, int64(1), stored[0])
	})

	t.Run("preserves an empty slice", func(cur realm, t *testing.T) {
		cloned, ok := cloneProposalIDsEntry([]int64{}).([]int64)
		uassert.True(t, ok)
		uassert.Equal(t, 0, len(cloned))
	})
}
