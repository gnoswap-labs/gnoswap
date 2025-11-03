package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

func TestLaunchpadProject_isGovernanceToken(t *testing.T) {
	tests := []struct {
		name           string
		tokenPath      string
		expectedResult bool
	}{
		{
			name:           "returns true for governance token",
			tokenPath:      GOV_XGNS_PATH,
			expectedResult: true,
		},
		{
			name:           "returns true for xgns token path",
			tokenPath:      "gno.land/r/gnoswap/gov/xgns",
			expectedResult: true,
		},
		{
			name:           "returns false for gns token",
			tokenPath:      GNS_PATH,
			expectedResult: false,
		},
		{
			name:           "returns false for other token",
			tokenPath:      "gno.land/r/demo/token",
			expectedResult: false,
		},
		{
			name:           "returns false for empty string",
			tokenPath:      "",
			expectedResult: false,
		},
		{
			name:           "returns false for similar but not exact path",
			tokenPath:      "gno.land/r/gnoswap/gov/xgns2",
			expectedResult: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isGovernanceToken(tt.tokenPath)
			uassert.Equal(t, result, tt.expectedResult)
		})
	}
}

func TestLaunchpadProject_validateRefundProject(t *testing.T) {
	testAddr := testutils.TestAddress("recipient")
	invalidAddr := address("")

	tests := []struct {
		name                  string
		tierStartTime         int64
		tierEndTime           int64
		totalDistributeAmount int64
		totalCollectedAmount  int64
		recipient             address
		currentTime           int64
		expectedHasError      bool
		expectedError         string
	}{
		{
			name:                  "valid refund - project ended and has remaining amount",
			tierStartTime:         1000,
			tierEndTime:           2000,
			totalDistributeAmount: 100_000_000,
			totalCollectedAmount:  50_000_000,
			recipient:             testAddr,
			currentTime:           2001,
			expectedHasError:      false,
		},
		{
			name:                  "error when recipient address is invalid",
			tierStartTime:         1000,
			tierEndTime:           2000,
			totalDistributeAmount: 100_000_000,
			totalCollectedAmount:  50_000_000,
			recipient:             invalidAddr,
			currentTime:           2001,
			expectedHasError:      true,
			expectedError:         "invalid recipient address",
		},
		{
			name:                  "error when project has no remaining amount",
			tierStartTime:         1000,
			tierEndTime:           2000,
			totalDistributeAmount: 100_000_000,
			totalCollectedAmount:  100_000_000,
			recipient:             testAddr,
			currentTime:           2001,
			expectedHasError:      true,
			expectedError:         "no remaining amount",
		},
		{
			name:                  "error when project not ended yet",
			tierStartTime:         1000,
			tierEndTime:           2000,
			totalDistributeAmount: 100_000_000,
			totalCollectedAmount:  50_000_000,
			recipient:             testAddr,
			currentTime:           1500,
			expectedHasError:      true,
			expectedError:         "project not ended yet",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create a project with tier
			tier := &ProjectTier{
				id:                    "test:180",
				totalDistributeAmount: tt.totalDistributeAmount,
				totalCollectedAmount:  tt.totalCollectedAmount,
				startTime:             tt.tierStartTime,
				endTime:               tt.tierEndTime,
			}

			project := &Project{
				id:    "test:100",
				tiers: make(map[int64]*ProjectTier),
			}
			project.tiers[projectTier180] = tier

			err := validateRefundProject(project, tt.recipient, tt.currentTime)

			if tt.expectedHasError {
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}
