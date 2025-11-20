package v1

import (
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/launchpad"
	gs "gno.land/r/gnoswap/gov/staker"
)

// ApiGetProjectRecipientRewardByProjectId retrieves the claimable reward for a project recipient by project ID.
func (lp *launchpadV1) ApiGetProjectRecipientRewardByProjectId(projectId string) string {
	projects := lp.store.GetProjects()
	project, exist := projects.Get(projectId)
	if !exist {
		return "0"
	}

	proj, ok := project.(*launchpad.Project)
	if !ok {
		panic(ufmt.Sprintf("failed to cast project to *launchpad.Project: %T", project))
	}
	return gs.GetClaimableRewardByAddress(proj.Recipient())
}

// ApiGetProjectRecipientRewardByAddress retrieves the claimable reward for a recipient by address.
func (lp *launchpadV1) ApiGetProjectRecipientRewardByAddress(address address) string {
	if !address.IsValid() {
		return "0"
	}

	return gs.GetClaimableRewardByAddress(address)
}
