package launchpad

import (
	"gno.land/r/gnoswap/launchpad"
)

// The functions below are makeEntrySafeFn transformations handed to
// rotree.Wrap. They run on every read through a read-only view, so each one
// returns a value the caller may hold without reaching realm-owned state.

// cloneProjectEntry is the transformation for the project tree. Project is
// mutable and its setters are declared in /r/gnoswap/launchpad, so an external
// holder of the stored pointer could write realm state through it.
//
// Project.Clone leaves the project's maps nil; see it for which lookups read
// them instead.
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
