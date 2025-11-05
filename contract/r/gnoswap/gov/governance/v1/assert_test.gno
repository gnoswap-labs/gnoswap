package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/governance"
)

// TestAssert_assertCallerIsProposer tests the private assertCallerIsProposer function
func TestAssert_assertCallerIsProposer(t *testing.T) {
	tests := []struct {
		name              string
		setupProposal     func(*governanceV1) int64
		caller            address
		proposalID        int64
		expectedPanic     bool
		expectedPanicMsg  string
	}{
		{
			name: "success - caller is proposer",
			setupProposal: func(gv *governanceV1) int64 {
				proposer := testutils.TestAddress("proposer1")
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					governance.NewProposalMetadata("Test Title", "Test Description"),
					NewProposalTextData(),
					proposer,
					1,
					time.Now().Unix(),
					100,
				)
				gv.addProposal(proposal)
				return 1
			},
			caller:        testutils.TestAddress("proposer1"),
			proposalID:    1,
			expectedPanic: false,
		},
		{
			name: "panic - proposal not found",
			setupProposal: func(gv *governanceV1) int64 {
				return 999 // Non-existent proposal ID
			},
			caller:           testutils.TestAddress("proposer1"),
			proposalID:       999,
			expectedPanic:    true,
			expectedPanicMsg: errProposalNotFound.Error(),
		},
		{
			name: "panic - caller is not proposer",
			setupProposal: func(gv *governanceV1) int64 {
				proposer := testutils.TestAddress("proposer1")
				proposal := governance.NewProposal(
					2,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					governance.NewProposalMetadata("Test Title", "Test Description"),
					NewProposalTextData(),
					proposer,
					1,
					time.Now().Unix(),
					100,
				)
				gv.addProposal(proposal)
				return 2
			},
			caller:           testutils.TestAddress("not_proposer"),
			proposalID:       2,
			expectedPanic:    true,
			expectedPanicMsg: errNotProposer.Error(),
		},
		{
			name: "success - different proposer for different proposal",
			setupProposal: func(gv *governanceV1) int64 {
				proposer := testutils.TestAddress("proposer2")
				proposal := governance.NewProposal(
					3,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					governance.NewProposalMetadata("Test Title 2", "Test Description 2"),
					NewProposalTextData(),
					proposer,
					1,
					time.Now().Unix(),
					100,
				)
				gv.addProposal(proposal)
				return 3
			},
			caller:        testutils.TestAddress("proposer2"),
			proposalID:    3,
			expectedPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gv := newMockGovernance()
			tt.setupProposal(gv)

			if tt.expectedPanic {
				// when & then
				uassert.PanicsWithMessage(t, tt.expectedPanicMsg, func() {
					assertCallerIsProposer(gv, tt.proposalID, tt.caller)
				})
			} else {
				defer func() {
					if r := recover(); r != nil {
						t.Errorf("unexpected panic: %v", r)
					}
				}()

			    // then
				uassert.NotPanics(t, func() {
                    assertCallerIsProposer(gv, tt.proposalID, tt.caller)
                })
			}
		})
	}
}
