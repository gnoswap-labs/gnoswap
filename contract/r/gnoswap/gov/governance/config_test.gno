package governance

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestConfig_IsValid(t *testing.T) {
	tests := []struct {
		name             string
		config           Config
		currentTime      int64
		expectedError    bool
		expectedErrorMsg string
	}{
		{
			name: "Valid config with normal values",
			config: Config{
				VotingStartDelay:              100,
				VotingPeriod:                  200,
				VotingWeightSmoothingDuration: 50,
				Quorum:                        50,
				ProposalCreationThreshold:     1000,
				ExecutionDelay:                100,
				ExecutionWindow:               200,
			},
			currentTime:   1000,
			expectedError: false,
		},
		{
			name: "Valid config with zero values",
			config: Config{
				VotingStartDelay:              0,
				VotingPeriod:                  0,
				VotingWeightSmoothingDuration: 0,
				Quorum:                        0,
				ProposalCreationThreshold:     0,
				ExecutionDelay:                0,
				ExecutionWindow:               0,
			},
			currentTime:   0,
			expectedError: false,
		},
		{
			name: "Valid config with max quorum",
			config: Config{
				VotingStartDelay:              100,
				VotingPeriod:                  200,
				VotingWeightSmoothingDuration: 50,
				Quorum:                        100,
				ProposalCreationThreshold:     1000,
				ExecutionDelay:                100,
				ExecutionWindow:               200,
			},
			currentTime:   1000,
			expectedError: false,
		},
		{
			name: "Invalid: negative VotingStartDelay",
			config: Config{
				VotingStartDelay:              -1,
				VotingPeriod:                  200,
				VotingWeightSmoothingDuration: 50,
				Quorum:                        50,
				ProposalCreationThreshold:     1000,
				ExecutionDelay:                100,
				ExecutionWindow:               200,
			},
			currentTime:      1000,
			expectedError:    true,
			expectedErrorMsg: "votingStartDelay cannot be negative",
		},
		{
			name: "Invalid: negative VotingPeriod",
			config: Config{
				VotingStartDelay:              100,
				VotingPeriod:                  -1,
				VotingWeightSmoothingDuration: 50,
				Quorum:                        50,
				ProposalCreationThreshold:     1000,
				ExecutionDelay:                100,
				ExecutionWindow:               200,
			},
			currentTime:      1000,
			expectedError:    true,
			expectedErrorMsg: "votingPeriod cannot be negative",
		},
		{
			name: "Invalid: negative ExecutionDelay",
			config: Config{
				VotingStartDelay:              100,
				VotingPeriod:                  200,
				VotingWeightSmoothingDuration: 50,
				Quorum:                        50,
				ProposalCreationThreshold:     1000,
				ExecutionDelay:                -1,
				ExecutionWindow:               200,
			},
			currentTime:      1000,
			expectedError:    true,
			expectedErrorMsg: "executionDelay cannot be negative",
		},
		{
			name: "Invalid: negative ExecutionWindow",
			config: Config{
				VotingStartDelay:              100,
				VotingPeriod:                  200,
				VotingWeightSmoothingDuration: 50,
				Quorum:                        50,
				ProposalCreationThreshold:     1000,
				ExecutionDelay:                100,
				ExecutionWindow:               -1,
			},
			currentTime:      1000,
			expectedError:    true,
			expectedErrorMsg: "executionWindow cannot be negative",
		},
		{
			name: "Invalid: negative VotingWeightSmoothingDuration",
			config: Config{
				VotingStartDelay:              100,
				VotingPeriod:                  200,
				VotingWeightSmoothingDuration: -1,
				Quorum:                        50,
				ProposalCreationThreshold:     1000,
				ExecutionDelay:                100,
				ExecutionWindow:               200,
			},
			currentTime:      1000,
			expectedError:    true,
			expectedErrorMsg: "votingWeightSmoothingDuration cannot be negative",
		},
		{
			name: "Invalid: negative ProposalCreationThreshold",
			config: Config{
				VotingStartDelay:              100,
				VotingPeriod:                  200,
				VotingWeightSmoothingDuration: 50,
				Quorum:                        50,
				ProposalCreationThreshold:     -1,
				ExecutionDelay:                100,
				ExecutionWindow:               200,
			},
			currentTime:      1000,
			expectedError:    true,
			expectedErrorMsg: "proposalCreationThreshold cannot be negative",
		},
		{
			name: "Invalid: Quorum below 0",
			config: Config{
				VotingStartDelay:              100,
				VotingPeriod:                  200,
				VotingWeightSmoothingDuration: 50,
				Quorum:                        -1,
				ProposalCreationThreshold:     1000,
				ExecutionDelay:                100,
				ExecutionWindow:               200,
			},
			currentTime:      1000,
			expectedError:    true,
			expectedErrorMsg: "quorum must be between 0 and 100",
		},
		{
			name: "Invalid: Quorum above 100",
			config: Config{
				VotingStartDelay:              100,
				VotingPeriod:                  200,
				VotingWeightSmoothingDuration: 50,
				Quorum:                        101,
				ProposalCreationThreshold:     1000,
				ExecutionDelay:                100,
				ExecutionWindow:               200,
			},
			currentTime:      1000,
			expectedError:    true,
			expectedErrorMsg: "quorum must be between 0 and 100",
		},
		{
			name: "Invalid: VotingStartDelay overflow when summed",
			config: Config{
				VotingStartDelay:              9223372036854775807, // max int64
				VotingPeriod:                  1,
				VotingWeightSmoothingDuration: 0,
				Quorum:                        50,
				ProposalCreationThreshold:     0,
				ExecutionDelay:                0,
				ExecutionWindow:               0,
			},
			currentTime:      0,
			expectedError:    true,
			expectedErrorMsg: "votingPeriod cannot be negative",
		},
		{
			name: "Invalid: VotingPeriod overflow when summed",
			config: Config{
				VotingStartDelay:              100,
				VotingPeriod:                  9223372036854775807, // max int64
				VotingWeightSmoothingDuration: 0,
				Quorum:                        50,
				ProposalCreationThreshold:     0,
				ExecutionDelay:                1,
				ExecutionWindow:               0,
			},
			currentTime:      0,
			expectedError:    true,
			expectedErrorMsg: "executionDelay cannot be negative",
		},
		{
			name: "Invalid: ExecutionDelay overflow when summed",
			config: Config{
				VotingStartDelay:              100,
				VotingPeriod:                  100,
				VotingWeightSmoothingDuration: 0,
				Quorum:                        50,
				ProposalCreationThreshold:     0,
				ExecutionDelay:                9223372036854775807, // max int64
				ExecutionWindow:               1,
			},
			currentTime:      0,
			expectedError:    true,
			expectedErrorMsg: "executionWindow cannot be negative",
		},
		{
			name: "Invalid: ExecutionWindow overflow when summed",
			config: Config{
				VotingStartDelay:              100,
				VotingPeriod:                  100,
				VotingWeightSmoothingDuration: 0,
				Quorum:                        50,
				ProposalCreationThreshold:     0,
				ExecutionDelay:                100,
				ExecutionWindow:               9223372036854775807, // max int64
			},
			currentTime:      1,
			expectedError:    true,
			expectedErrorMsg: "total delay cannot be negative",
		},
		{
			name: "Invalid: currentTime overflow when summed",
			config: Config{
				VotingStartDelay:              100,
				VotingPeriod:                  100,
				VotingWeightSmoothingDuration: 0,
				Quorum:                        50,
				ProposalCreationThreshold:     0,
				ExecutionDelay:                100,
				ExecutionWindow:               100,
			},
			currentTime:      9223372036854775807, // max int64
			expectedError:    true,
			expectedErrorMsg: "total delay cannot be negative",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			err := tc.config.IsValid(tc.currentTime)

			// then
			if tc.expectedError {
				uassert.NotNil(t, err)
				uassert.Equal(t, err.Error(), tc.expectedErrorMsg)
			} else {
				uassert.Nil(t, err)
			}
		})
	}
}
