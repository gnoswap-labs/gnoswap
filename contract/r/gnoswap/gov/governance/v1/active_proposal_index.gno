package governance

import (
	"time"

	"gno.land/r/gnoswap/access"
)

// maxProposalsPrunedPerCall bounds how many terminal proposals a single
// PruneInactiveProposals call removes from the active index. This keeps the
// call's gas cost predictable even if cleanup is neglected for a long time;
// gov/staker calls this again on its next cleanup to keep making progress.
const maxProposalsPrunedPerCall = 200

// PruneInactiveProposals removes ended proposals from the active proposal index.
// Proposal records and their voting information remain available as permanent history.
// Only gov/staker may call this before it cleans delegation snapshots.
func (gv *governanceV1) PruneInactiveProposals(_ int, rlm realm) {
	access.AssertIsRlmCurrent(0, rlm)
	access.AssertIsGovStaker(rlm.Previous().Address())

	if err := gv.pruneInactiveProposals(0, rlm, time.Now().Unix(), maxProposalsPrunedPerCall); err != nil {
		panic(err)
	}
}
