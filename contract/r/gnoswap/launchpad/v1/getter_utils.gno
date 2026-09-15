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
// Project.Clone deep-copies the conditions, tiers, and tier-ratio maps and their
// entries, so the read-only view does not expose realm-owned state.
//
// Parameters:
//   - value: project-tree entry expected to be a *launchpad.Project.
//
// Returns:
//   - clone: cloned project entry as any; nil when value is not a *launchpad.Project.
func cloneProjectEntry(value any) any {
	project, ok := value.(*launchpad.Project)
	if !ok {
		return nil
	}

	return project.Clone()
}

// cloneRewardStateEntry is the transformation for a project tier's reward
// tree. RewardState is mutable and its setters are declared in
// /r/gnoswap/launchpad, so an external holder of the stored pointer could
// write realm state through it.
//
// Parameters:
//   - value: reward-tree entry expected to be a *launchpad.RewardState.
//
// Returns:
//   - clone: cloned reward state as any; nil when value is not a *launchpad.RewardState.
func cloneRewardStateEntry(value any) any {
	rewardState, ok := value.(*launchpad.RewardState)
	if !ok {
		return nil
	}

	return rewardState.Clone()
}
