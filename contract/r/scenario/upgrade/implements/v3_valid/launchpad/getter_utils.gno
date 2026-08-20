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

	return project.CloneShallow()
}

// cloneRewardStateEntry is the transformation for a project tier's reward
// tree.
func cloneRewardStateEntry(value any) any {
	rewardState, ok := value.(*launchpad.RewardState)
	if !ok {
		return nil
	}

	return rewardState.Clone()
}
