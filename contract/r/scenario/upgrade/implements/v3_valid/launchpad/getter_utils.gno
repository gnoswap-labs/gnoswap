package v3_valid

import (
	"gno.land/r/gnoswap/launchpad"
)

// The functions below are makeEntrySafeFn transformations handed to
// rotree.Wrap. They run on every read through a read-only view, so each one
// returns a value the caller may hold without reaching realm-owned state.

// cloneProjectEntry is the transformation for the project tree.
func cloneProjectEntry(value any) any {
	project, ok := value.(*launchpad.Project)
	if !ok {
		return nil
	}

	return project.Clone()
}

// cloneRewardStateEntry is the transformation for a project tier's reward
// tree. Stored values are cloned before they cross the read-only API boundary.
func cloneRewardStateEntry(value any) any {
	switch rewardState := value.(type) {
	case launchpad.RewardState:
		return rewardState.Clone()
	default:
		return nil
	}
}
