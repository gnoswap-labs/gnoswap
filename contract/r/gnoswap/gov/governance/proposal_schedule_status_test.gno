package governance

import (
	"testing"
	"time"

	"gno.land/p/demo/uassert"
)

// TestProposalScheduleStatus_TimeChecks tests all time-related checks
func TestProposalScheduleStatus_TimeChecks(t *testing.T) {
	// Base time values for testing
	baseTime := time.Unix(1000, 0)
	votingStartDelay := int64(100)
	votingPeriod := int64(200)
	executionDelay := int64(100)
	executionWindow := int64(200)

	tests := []struct {
		name           string
		currentTime    time.Time
		expectedStates map[string]bool // map of state check functions to expected results
	}{
		{
			name:        "Before active time",
			currentTime: baseTime.Add(time.Duration(50) * time.Second),
			expectedStates: map[string]bool{
				"IsPassedCreatedAt":     true,
				"IsPassedActiveAt":      false,
				"IsPassedVotingEndedAt": false,
				"IsPassedExecutableAt":  false,
				"IsPassedExpiredAt":     false,
			},
		},
		{
			name:        "During voting period",
			currentTime: baseTime.Add(time.Duration(150) * time.Second),
			expectedStates: map[string]bool{
				"IsPassedCreatedAt":     true,
				"IsPassedActiveAt":      true,
				"IsPassedVotingEndedAt": false,
				"IsPassedExecutableAt":  false,
				"IsPassedExpiredAt":     false,
			},
		},
		{
			name:        "After voting period",
			currentTime: baseTime.Add(time.Duration(350) * time.Second),
			expectedStates: map[string]bool{
				"IsPassedCreatedAt":     true,
				"IsPassedActiveAt":      true,
				"IsPassedVotingEndedAt": true,
				"IsPassedExecutableAt":  false,
				"IsPassedExpiredAt":     false,
			},
		},
		{
			name:        "During execution window",
			currentTime: baseTime.Add(time.Duration(500) * time.Second),
			expectedStates: map[string]bool{
				"IsPassedCreatedAt":     true,
				"IsPassedActiveAt":      true,
				"IsPassedVotingEndedAt": true,
				"IsPassedExecutableAt":  true,
				"IsPassedExpiredAt":     false,
			},
		},
		{
			name:        "After expiration",
			currentTime: baseTime.Add(time.Duration(700) * time.Second),
			expectedStates: map[string]bool{
				"IsPassedCreatedAt":     true,
				"IsPassedActiveAt":      true,
				"IsPassedVotingEndedAt": true,
				"IsPassedExecutableAt":  true,
				"IsPassedExpiredAt":     true,
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			status := NewProposalScheduleStatus(
				votingStartDelay,
				votingPeriod,
				executionDelay,
				executionWindow,
				baseTime.Unix(),
			)

			// when & then
			for stateName, expectedResult := range tc.expectedStates {
				var result bool
				switch stateName {
				case "IsPassedCreatedAt":
					result = status.IsPassedCreatedAt(tc.currentTime.Unix())
				case "IsPassedActiveAt":
					result = status.IsPassedActiveAt(tc.currentTime.Unix())
				case "IsPassedVotingEndedAt":
					result = status.IsPassedVotingEndedAt(tc.currentTime.Unix())
				case "IsPassedExecutableAt":
					result = status.IsPassedExecutableAt(tc.currentTime.Unix())
				case "IsPassedExpiredAt":
					result = status.IsPassedExpiredAt(tc.currentTime.Unix())
				}
				
				uassert.Equal(t, result, expectedResult)
			}
		})
	}
}

// TestNewProposalScheduleStatus tests the creation of new schedule status
func TestNewProposalScheduleStatus(t *testing.T) {
	tests := []struct {
		name             string
		votingStartDelay int64
		votingPeriod     int64
		executionDelay   int64
		executionWindow  int64
		createdAt        int64
	}{
		{
			name:             "Create with standard delays",
			votingStartDelay: 100,
			votingPeriod:     200,
			executionDelay:   100,
			executionWindow:  200,
			createdAt:        1000,
		},
		{
			name:             "Create with zero delays",
			votingStartDelay: 0,
			votingPeriod:     0,
			executionDelay:   0,
			executionWindow:  0,
			createdAt:        1000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			status := NewProposalScheduleStatus(
				tc.votingStartDelay,
				tc.votingPeriod,
				tc.executionDelay,
				tc.executionWindow,
				tc.createdAt,
			)

			// then
			uassert.NotNil(t, status)
			uassert.Equal(t, status.createTime, tc.createdAt)
			uassert.Equal(t, status.activeTime, tc.createdAt+tc.votingStartDelay)
			uassert.Equal(t, status.votingEndTime, status.activeTime+tc.votingPeriod)
			uassert.Equal(t, status.executableTime, status.votingEndTime+tc.executionDelay)
			uassert.Equal(t, status.expiredTime, status.executableTime+tc.executionWindow)
		})
	}
} 