package launchpad

import (
	"gno.land/r/gnoswap/launchpad"
)

// cloneRewardStateEntry is the transformation for a project tier's reward
// tree. RewardState is mutable and its setters are declared in
// /r/gnoswap/launchpad, so an external holder of the stored pointer could
// write realm state through it.
func cloneRewardStateEntry(value any) any {
	rewardState, ok := value.(*launchpad.RewardState)
	if !ok {
		return nil
	}

	return rewardState.Clone()
}
