package governance

import (
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
)

// maxProposalsPrunedPerCall caps deadline entries processed, including active
// proposals rescheduled from voting end to expiration.
const maxProposalsPrunedPerCall = 200

// PruneInactiveProposals processes a bounded batch of elapsed lifecycle deadlines.
// Admins may call it independently so progress persists even when snapshot cleanup
// is not yet safe. Gov/staker also calls it before delegation-history cleanup.
// processed counts removals and reschedules; hasMore reports remaining due deadlines.
func (gv *governanceV1) PruneInactiveProposals(_ int, rlm realm) (processed int, hasMore bool) {
	access.AssertIsRlmCurrent(0, rlm)
	access.AssertHasAnyRole(rlm.Previous().Address(), prbac.ROLE_ADMIN.String(), prbac.ROLE_GOV_STAKER.String())

	processed, hasMore, err := gv.pruneInactiveProposals(0, rlm, time.Now().Unix(), maxProposalsPrunedPerCall)
	if err != nil {
		panic(err)
	}
	return processed, hasMore
}
