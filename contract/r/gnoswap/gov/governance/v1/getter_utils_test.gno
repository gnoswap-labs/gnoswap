package governance

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

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
