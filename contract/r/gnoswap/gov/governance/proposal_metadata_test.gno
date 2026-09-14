package governance

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestProposalMetadataReturnsValueWithPresence(t *testing.T) {
	withMetadata := NewProposal(1, nil, NewProposalMetadata("title", "description"), nil, "", 0, 0, 0)
	metadata, present := withMetadata.Metadata()
	uassert.True(t, present)
	uassert.Equal(t, "title", metadata.Title())
	uassert.Equal(t, "description", metadata.Description())

	withoutMetadata := NewProposal(2, nil, nil, nil, "", 0, 0, 0)
	metadata, present = withoutMetadata.Metadata()
	uassert.False(t, present)
	uassert.Equal(t, "", metadata.Title())
	uassert.Equal(t, "", metadata.Description())
}
