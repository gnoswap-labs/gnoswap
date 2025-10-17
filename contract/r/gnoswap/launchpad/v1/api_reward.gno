package v1

import gs "gno.land/r/gnoswap/v1/gov/staker"

// ApiGetProjectRecipientRewardByProjectId retrieves the claimable reward for a project recipient by project ID.
func (lp *launchpadV1) ApiGetProjectRecipientRewardByProjectId(projectId string) string {
	state := lp.getLaunchpadState()
	project, exist := state.projects.Get(projectId)
	if !exist {
		return "0"
	}

	return gs.GetClaimableRewardByAddress(project.(*Project).recipient)
}

// ApiGetProjectRecipientRewardByAddress retrieves the claimable reward for a recipient by address.
func (lp *launchpadV1) ApiGetProjectRecipientRewardByAddress(address address) string {
	if !address.IsValid() {
		return "0"
	}

	return gs.GetClaimableRewardByAddress(address)
}
