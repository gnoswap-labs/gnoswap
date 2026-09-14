package governance

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestProposalMetadataReturnsValue(t *testing.T) {
	proposal := MakeProposal(1, ProposalStatus{}, MakeProposalMetadata("title", "description"), ProposalData{}, "", 0, 0, 0)
	metadata := proposal.Metadata()
	uassert.Equal(t, "title", metadata.Title())
	uassert.Equal(t, "description", metadata.Description())
}
