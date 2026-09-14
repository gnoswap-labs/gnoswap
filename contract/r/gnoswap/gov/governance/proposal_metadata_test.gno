package governance

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestProposalMetadataReturnsValue(t *testing.T) {
	proposal := NewProposal(1, nil, NewProposalMetadata("title", "description"), nil, "", 0, 0, 0)
	metadata := proposal.Metadata()
	uassert.Equal(t, "title", metadata.Title())
	uassert.Equal(t, "description", metadata.Description())
}
