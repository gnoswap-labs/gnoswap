package governance

import (
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"
)

// maxProposalsPrunedPerCall caps deadline entries processed, including active
// proposals rescheduled from voting end to expiration.
const maxProposalsPrunedPerCall = 200

// PruneInactiveProposals processes up to limit elapsed lifecycle deadlines.
// The limit must be between 1 and maxProposalsPrunedPerCall, inclusive.
// Call in a separate transaction when delegation-history cleanup requires it.
// processed counts removals and reschedules; hasMore reports remaining due deadlines.
func (gv *governanceV1) PruneInactiveProposals(_ int, rlm realm, limit int) (processed int, hasMore bool) {
	access.AssertIsRlmCurrent(0, rlm)
	access.AssertHasAnyRole(rlm.Previous().Address(), prbac.ROLE_ADMIN.String(), prbac.ROLE_GOV_STAKER.String())

	if limit < 1 || limit > maxProposalsPrunedPerCall {
		panic(makeErrorWithDetails(errInvalidInput, ufmt.Sprintf(
			"pruning limit must be between 1 and %d (requested:%d)", maxProposalsPrunedPerCall, limit,
		)))
	}

	processed, hasMore, err := gv.pruneInactiveProposals(0, rlm, time.Now().Unix(), limit)
	if err != nil {
		panic(err)
	}
	return processed, hasMore
}
