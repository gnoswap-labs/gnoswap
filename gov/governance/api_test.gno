package governance

import (
	"testing"

	"gno.land/p/demo/testutils"
)

func TestCreateProposalJsonNode(t *testing.T) {
	propAddr := testutils.TestAddress("proposal")
	title := "Test Proposal"
	desc := "This is a test proposal"

	testProposal := ProposalInfo{
		ConfigVersion: 1,
		Proposer: propAddr,
		ProposalType: Text,
		Title:        title,
		Description:  desc,
	}

	result := createProposalJsonNode(123, testProposal)

	expectedFields := []struct {
		key      string
		expected string
	}{
		{"id", "123"},
		{"configVersion", "1"},
		{"proposer", propAddr.String()},
		{"type", Text.String()},
		{"title", title},
		{"description", desc},
	}

	for _, field := range expectedFields {
		node, err := result.GetKey(field.key)
		if err != nil {
			t.Errorf("field not found: %s", field.key)
			continue
		}

		value, err := node.GetString()
		if err != nil {
			t.Errorf("failed to get value: %s", err)
			continue
		}

		if value != field.expected {
			t.Errorf("value not match: %s, expected: %s, actual: %s", 
				field.key, field.expected, value)
		}
	}

	encodedFields := []string{"status", "vote", "extra"}
	for _, field := range encodedFields {
		node, err := result.GetKey(field)
		if err != nil {
			t.Errorf("field not found: %s", field)
			continue
		}

		value, err := node.GetString()
		if err != nil {
			t.Errorf("failed to get value: %s", err)
			continue
		}

		_, err = b64Decode(value)
		if err != nil {
			t.Errorf("failed to decode: %s", err)
		}
	}
}

func TestCreateProposalJsonNodeEdgeCases(t *testing.T) {
	emptyProposal := ProposalInfo{
		ConfigVersion: 0,
		Proposer:     testutils.TestAddress("proposal"),
		ProposalType: Text,
		Title:        "",
		Description:  "",
	}

	result := createProposalJsonNode(0, emptyProposal)

	requiredFields := []string{
		"id", "configVersion", "proposer", "status", 
		"type", "title", "description", "vote", "extra",
	}

	for _, field := range requiredFields {
		if _, err := result.GetKey(field); err != nil {
			t.Errorf("field not found: %s", field)
		}
	}
}