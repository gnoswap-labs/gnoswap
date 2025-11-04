package governance

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestProposalScheduleStatus_NewProposalScheduleStatusInstance tests the instance creation
func TestProposalScheduleStatus_NewProposalScheduleStatusInstance(t *testing.T) {
	tests := []struct {
		name           string
		createTime     int64
		activeTime     int64
		votingEndTime  int64
		executableTime int64
		expiredTime    int64
	}{
		{
			name:           "create with standard times",
			createTime:     1000,
			activeTime:     1100,
			votingEndTime:  1300,
			executableTime: 1400,
			expiredTime:    1600,
		},
		{
			name:           "create with same times",
			createTime:     1000,
			activeTime:     1000,
			votingEndTime:  1000,
			executableTime: 1000,
			expiredTime:    1000,
		},
		{
			name:           "create with zero times",
			createTime:     0,
			activeTime:     0,
			votingEndTime:  0,
			executableTime: 0,
			expiredTime:    0,
		},
		{
			name:           "create with large time values",
			createTime:     9999999999,
			activeTime:     9999999999,
			votingEndTime:  9999999999,
			executableTime: 9999999999,
			expiredTime:    9999999999,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// when
			status := NewProposalScheduleStatusInstance(
				tt.createTime,
				tt.activeTime,
				tt.votingEndTime,
				tt.executableTime,
				tt.expiredTime,
			)

			// then
			uassert.NotNil(t, status)
			uassert.Equal(t, status.CreateTime(), tt.createTime)
			uassert.Equal(t, status.ActiveTime(), tt.activeTime)
			uassert.Equal(t, status.VotingEndTime(), tt.votingEndTime)
			uassert.Equal(t, status.ExecutableTime(), tt.executableTime)
			uassert.Equal(t, status.ExpiredTime(), tt.expiredTime)
		})
	}
}

// TestProposalScheduleStatus_Setters tests setter methods
func TestProposalScheduleStatus_Setters(t *testing.T) {
	tests := []struct {
		name              string
		initialCreate     int64
		initialActive     int64
		initialVotingEnd  int64
		initialExecutable int64
		initialExpired    int64
		newCreate         int64
		newActive         int64
		newVotingEnd      int64
		newExecutable     int64
		newExpired        int64
	}{
		{
			name:              "update all times",
			initialCreate:     1000,
			initialActive:     1100,
			initialVotingEnd:  1300,
			initialExecutable: 1400,
			initialExpired:    1600,
			newCreate:         2000,
			newActive:         2100,
			newVotingEnd:      2300,
			newExecutable:     2400,
			newExpired:        2600,
		},
		{
			name:              "update to zero",
			initialCreate:     1000,
			initialActive:     1100,
			initialVotingEnd:  1300,
			initialExecutable: 1400,
			initialExpired:    1600,
			newCreate:         0,
			newActive:         0,
			newVotingEnd:      0,
			newExecutable:     0,
			newExpired:        0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			status := NewProposalScheduleStatusInstance(
				tt.initialCreate,
				tt.initialActive,
				tt.initialVotingEnd,
				tt.initialExecutable,
				tt.initialExpired,
			)

			// when
			status.SetCreateTime(tt.newCreate)
			status.SetActiveTime(tt.newActive)
			status.SetVotingEndTime(tt.newVotingEnd)
			status.SetExecutableTime(tt.newExecutable)
			status.SetExpiredTime(tt.newExpired)

			// then
			uassert.Equal(t, status.CreateTime(), tt.newCreate)
			uassert.Equal(t, status.ActiveTime(), tt.newActive)
			uassert.Equal(t, status.VotingEndTime(), tt.newVotingEnd)
			uassert.Equal(t, status.ExecutableTime(), tt.newExecutable)
			uassert.Equal(t, status.ExpiredTime(), tt.newExpired)
		})
	}
}
