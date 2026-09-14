package governance

import (
	"time"

	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"
)

// RemoveInactiveProposalFromIndexByAdmin removes one inactive proposal from the
// snapshot index without deleting its proposal or voting history.
func (gv *governanceV1) RemoveInactiveProposalFromIndexByAdmin(_ int, rlm realm, proposalID int64) {
	access.AssertIsRlmCurrent(0, rlm)
	access.AssertIsAdmin(rlm.Previous().Address())

	proposal, exists := gv.getProposal(proposalID)
	if !exists {
		panic(makeErrorWithDetails(errProposalNotFound, ufmt.Sprintf("proposalID: %d", proposalID)))
	}
	if NewProposalResolver(proposal).IsActive(time.Now().Unix()) {
		panic(makeErrorWithDetails(errInvalidInput, ufmt.Sprintf("proposal %d is still active", proposalID)))
	}
	if err := gv.removeActiveProposal(0, rlm, proposal); err != nil {
		panic(err)
	}
}
