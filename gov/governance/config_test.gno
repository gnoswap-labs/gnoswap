package governance

import (
	"std"
	"strings"
	"testing"

	"gno.land/r/gnoswap/v2/consts"
)

func TestReconfigure(t *testing.T) {
	// Helper function to set the caller to the governance itself
	setGovernorAsCaller := func() {
		// origCaller := std.GetOrigCaller
		// std.TestSetOrigCaller(std.GetOrigPkgAddr())

		govRealm := std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
		std.TestSetRealm(govRealm)
	}

	t.Run("Successful reconfiguration", func(t *testing.T) {
		setGovernorAsCaller()

		newConfigJSON := `{
            "votingStartDelay": 200,
            "votingPeriod": 2000,
            "votingWeightSmoothingDuration": 200,
            "quorum": 1000,
            "proposalCreationThreshold": 200,
            "executionDelay": 200,
            "executionWindow": 2000
        }`

		newVersion := Reconfigure(newConfigJSON)

		if newVersion != 2 {
			t.Errorf("Expected new version to be 2, got %d", newVersion)
		}

		if len(configVersions) != 2 {
			t.Errorf("Expected config versions to have 2 entries, got %d", len(configVersions))
		}

		newConfig := GetConfigVersion(0) // 0 will return the latest config
		if newConfig.VotingStartDelay != 200 ||
			newConfig.VotingPeriod != 2000 ||
			newConfig.VotingWeightSmoothingDuration != 200 ||
			newConfig.Quorum != 1000 ||
			newConfig.ProposalCreationThreshold != 200 ||
			newConfig.ExecutionDelay != 200 ||
			newConfig.ExecutionWindow != 2000 {
			t.Errorf("New configuration does not match expected values")
		}
	})

	t.Run("Not called by governor", func(t *testing.T) {
		// Set the caller to be a different address
		dummyRealm := std.NewCodeRealm("dummy")
		std.TestSetRealm(dummyRealm)

		newConfigJSON := `{"votingStartDelay":200,"votingPeriod":2000,"votingWeightSmoothingDuration":200,"quorum":1000,"proposalCreationThreshold":200,"executionDelay":200,"executionWindow":2000}`
		/*
			{
			  "votingStartDelay": 200,
			  "votingPeriod": 2000,
			  "votingWeightSmoothingDuration": 200,
			  "quorum": 1000,
			  "proposalCreationThreshold": 200,
			  "executionDelay": 200,
			  "executionWindow": 2000
			}
		*/

		defer func() {
			if r := recover(); r == nil {
				t.Errorf("The code did not panic")
			} else if !strings.HasPrefix(string(r), "Reconfigure can only be called by the governance contract") {
				t.Errorf("Unexpected panic message: %v", r)
			}
		}()

		Reconfigure(newConfigJSON)
	})
}
