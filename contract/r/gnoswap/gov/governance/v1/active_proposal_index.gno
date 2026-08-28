package governance

import (
	"time"

	"gno.land/r/gnoswap/access"
)

// PruneInactiveProposals removes ended proposals from the active proposal index.
// Proposal records and their voting information remain available as permanent history.
// Only gov/staker may call this before it cleans delegation snapshots.
func (gv *governanceV1) PruneInactiveProposals(_ int, rlm realm) {
	access.AssertIsRlmCurrent(0, rlm)
	access.AssertIsGovStaker(rlm.Previous().Address())

	if err := gv.pruneInactiveProposals(0, rlm, time.Now().Unix()); err != nil {
		panic(err)
	}
}
