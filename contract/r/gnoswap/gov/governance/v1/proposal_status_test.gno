package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/governance"
)

// TestProposalStatus_StatusType tests status type determination
func TestProposalStatus_StatusType(t *testing.T) {
	baseTime := time.Unix(1000, 0)
	config := governance.Config{
		VotingStartDelay: 100,
		VotingPeriod:     200,
		ExecutionDelay:   100,
		ExecutionWindow:  200,
		Quorum:           50,
	}

	tests := []struct {
		name            string
		currentTime     time.Time
		maxVotingWeight int64
		executable      bool
		isExecuted      bool
		isCanceled      bool
		voteYes         int64
		voteNo          int64
		expectedStatus  governance.ProposalStatusType
	}{
		{
			name:            "Status Upcoming",
			currentTime:     baseTime.Add(time.Duration(50) * time.Second),
			maxVotingWeight: 1000,
			executable:      true,
			expectedStatus:  governance.StatusUpcoming,
		},
		{
			name:            "Status Active",
			currentTime:     baseTime.Add(time.Duration(150) * time.Second),
			maxVotingWeight: 1000,
			executable:      true,
			expectedStatus:  governance.StatusActive,
		},
		{
			name:            "Status Rejected - no votes win and voting finished",
			currentTime:     baseTime.Add(time.Duration(350) * time.Second), // After voting ended (1300)
			maxVotingWeight: 1000,
			executable:      true,
			voteYes:         200, // 20% - below 50% quorum
			voteNo:          600, // 60% - clearly rejected, remaining(200) - diff(400) = -200 <= 0
			expectedStatus:  governance.StatusRejected,
		},
		{
			name:            "Status Rejected - quorum met but no majority",
			currentTime:     baseTime.Add(time.Duration(350) * time.Second),
			maxVotingWeight: 1000,
			executable:      true,
			voteYes:         400, // 40% - below quorum
			voteNo:          500, // 50% - remaining(100) - diff(100) = 0 <= 0, voting finished
			expectedStatus:  governance.StatusRejected,
		},
		{
			name:            "Status Passed - in execution delay",
			currentTime:     baseTime.Add(time.Duration(350) * time.Second), // After voting (1300), before executable (1400)
			maxVotingWeight: 1000,
			executable:      true,
			voteYes:         600, // 60% - passed quorum and majority
			voteNo:          300,
			expectedStatus:  governance.StatusPassed,
		},
		{
			name:            "Status Passed - non-executable proposal",
			currentTime:     baseTime.Add(time.Duration(350) * time.Second),
			maxVotingWeight: 1000,
			executable:      false, // Text proposals are not executable
			voteYes:         600,
			voteNo:          300,
			expectedStatus:  governance.StatusPassed,
		},
		{
			name:            "Status Executable",
			currentTime:     baseTime.Add(time.Duration(450) * time.Second), // After executable time (1400), before expiration (1600)
			maxVotingWeight: 1000,
			executable:      true,
			voteYes:         600,
			voteNo:          300,
			expectedStatus:  governance.StatusExecutable,
		},
		{
			name:            "Status Expired",
			currentTime:     baseTime.Add(time.Duration(650) * time.Second), // After expiration (1600)
			maxVotingWeight: 1000,
			executable:      true,
			voteYes:         600,
			voteNo:          300,
			expectedStatus:  governance.StatusExpired,
		},
		{
			name:            "Status Executed",
			currentTime:     baseTime.Add(time.Duration(150) * time.Second),
			maxVotingWeight: 1000,
			executable:      true,
			isExecuted:      true,
			expectedStatus:  governance.StatusExecuted,
		},
		{
			name:            "Status Canceled",
			currentTime:     baseTime.Add(time.Duration(150) * time.Second),
			maxVotingWeight: 1000,
			executable:      true,
			isCanceled:      true,
			expectedStatus:  governance.StatusCanceled,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			status := NewProposalStatus(config, tc.maxVotingWeight, tc.executable, baseTime.Unix())
			resolver := NewProposalStatusResolver(status)

			// Add votes if specified
			if tc.voteYes > 0 {
				resolver.vote(true, tc.voteYes)
			}
			if tc.voteNo > 0 {
				resolver.vote(false, tc.voteNo)
			}

			// Execute or cancel if specified
			if tc.isExecuted {
				resolver.execute(tc.currentTime.Unix(), 100, address("g1executor"))
			}
			if tc.isCanceled {
				resolver.cancel(tc.currentTime.Unix(), 100, address("g1canceler"))
			}

			// when
			statusType := resolver.StatusType(tc.currentTime.Unix())

			// then
			uassert.Equal(t, statusType.String(), tc.expectedStatus.String())
		})
	}
}

// TestProposalStatus_VotingOperations tests voting operations
func TestProposalStatus_VotingOperations(t *testing.T) {
	tests := []struct {
		name            string
		maxVotingWeight int64
		quorum          int64
		voteYes         int64
		voteNo          int64
		expectedTotal   int64
		expectedDiff    int64
	}{
		{
			name:            "Voting with majority yes",
			maxVotingWeight: 1000,
			quorum:          500,
			voteYes:         600,
			voteNo:          300,
			expectedTotal:   900,
			expectedDiff:    300,
		},
		{
			name:            "Voting with majority no",
			maxVotingWeight: 1000,
			quorum:          500,
			voteYes:         300,
			voteNo:          600,
			expectedTotal:   900,
			expectedDiff:    300,
		},
		{
			name:            "Equal votes",
			maxVotingWeight: 1000,
			quorum:          500,
			voteYes:         400,
			voteNo:          400,
			expectedTotal:   800,
			expectedDiff:    0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			config := governance.Config{
				VotingStartDelay: 100,
				VotingPeriod:     200,
				ExecutionDelay:   100,
				ExecutionWindow:  200,
				Quorum:           tc.quorum,
			}
			status := NewProposalStatus(config, tc.maxVotingWeight, true, time.Now().Unix())
			resolver := NewProposalStatusResolver(status)

			// when
			if tc.voteYes > 0 {
				_ = resolver.vote(true, tc.voteYes)
			}
			if tc.voteNo > 0 {
				_ = resolver.vote(false, tc.voteNo)
			}

			// then
			uassert.Equal(t, status.YesWeight(), tc.voteYes)
			uassert.Equal(t, status.NoWeight(), tc.voteNo)

			statusResolver := NewProposalStatusResolver(status)
			uassert.Equal(t, statusResolver.TotalVoteWeight(), tc.expectedTotal)
			uassert.Equal(t, statusResolver.DiffVoteWeight(), tc.expectedDiff)
		})
	}
}

// TestProposalStatusResolver_PrivateMethods tests private methods of proposal status resolver
func TestProposalStatusResolver_PrivateMethods(t *testing.T) {
	baseTime := time.Unix(1000, 0)
	config := governance.Config{
		VotingStartDelay: 100,
		VotingPeriod:     200,
		ExecutionDelay:   100,
		ExecutionWindow:  200,
		Quorum:           50,
	}

	tests := []struct {
		name   string
		setup  func() *ProposalStatusResolver
		action func(*ProposalStatusResolver) error
		verify func(*testing.T, *ProposalStatusResolver, error)
	}{
		{
			name: "cancel - success",
			setup: func() *ProposalStatusResolver {
				status := NewProposalStatus(config, 1000, true, baseTime.Unix())
				return NewProposalStatusResolver(status)
			},
			action: func(resolver *ProposalStatusResolver) error {
				return resolver.cancel(baseTime.Unix()+50, 100, address("g1canceler"))
			},
			verify: func(t *testing.T, resolver *ProposalStatusResolver, err error) {
				uassert.Nil(t, err)
				uassert.True(t, resolver.ActionStatus().Canceled())
				uassert.Equal(t, resolver.ActionStatus().CanceledBy().String(), address("g1canceler").String())
			},
		},
		{
			name: "execute - success",
			setup: func() *ProposalStatusResolver {
				status := NewProposalStatus(config, 1000, true, baseTime.Unix())
				return NewProposalStatusResolver(status)
			},
			action: func(resolver *ProposalStatusResolver) error {
				return resolver.execute(baseTime.Unix()+500, 100, address("g1executor"))
			},
			verify: func(t *testing.T, resolver *ProposalStatusResolver, err error) {
				uassert.Nil(t, err)
				uassert.True(t, resolver.ActionStatus().IsExecuted())
				uassert.Equal(t, resolver.ActionStatus().ExecutedBy().String(), address("g1executor").String())
			},
		},
		{
			name: "vote - add yes vote",
			setup: func() *ProposalStatusResolver {
				status := NewProposalStatus(config, 1000, true, baseTime.Unix())
				return NewProposalStatusResolver(status)
			},
			action: func(resolver *ProposalStatusResolver) error {
				return resolver.vote(true, 600)
			},
			verify: func(t *testing.T, resolver *ProposalStatusResolver, err error) {
				uassert.Nil(t, err)
				uassert.Equal(t, resolver.VoteStatus().YesWeight(), int64(600))
				uassert.Equal(t, resolver.VoteStatus().NoWeight(), int64(0))
			},
		},
		{
			name: "vote - add no vote",
			setup: func() *ProposalStatusResolver {
				status := NewProposalStatus(config, 1000, true, baseTime.Unix())
				return NewProposalStatusResolver(status)
			},
			action: func(resolver *ProposalStatusResolver) error {
				return resolver.vote(false, 400)
			},
			verify: func(t *testing.T, resolver *ProposalStatusResolver, err error) {
				uassert.Nil(t, err)
				uassert.Equal(t, resolver.VoteStatus().YesWeight(), int64(0))
				uassert.Equal(t, resolver.VoteStatus().NoWeight(), int64(400))
			},
		},
		{
			name: "vote - multiple votes",
			setup: func() *ProposalStatusResolver {
				status := NewProposalStatus(config, 1000, true, baseTime.Unix())
				resolver := NewProposalStatusResolver(status)
				_ = resolver.vote(true, 300)
				return resolver
			},
			action: func(resolver *ProposalStatusResolver) error {
				return resolver.vote(true, 200)
			},
			verify: func(t *testing.T, resolver *ProposalStatusResolver, err error) {
				uassert.Nil(t, err)
				uassert.Equal(t, resolver.VoteStatus().YesWeight(), int64(500))
			},
		},
		{
			name: "updateVoteStatus - increase max weight and quorum",
			setup: func() *ProposalStatusResolver {
				status := NewProposalStatus(config, 1000, true, baseTime.Unix())
				return NewProposalStatusResolver(status)
			},
			action: func(resolver *ProposalStatusResolver) error {
				return resolver.updateVoteStatus(2000, 60)
			},
			verify: func(t *testing.T, resolver *ProposalStatusResolver, err error) {
				uassert.Nil(t, err)
				voteResolver := NewProposalVoteStatusResolver(resolver.VoteStatus())
				uassert.Equal(t, voteResolver.MaxVotingWeight(), int64(2000))
				uassert.Equal(t, voteResolver.QuorumAmount(), int64(1200)) // 2000 * 60 / 100
			},
		},
		{
			name: "updateVoteStatus - decrease max weight and quorum",
			setup: func() *ProposalStatusResolver {
				status := NewProposalStatus(config, 1000, true, baseTime.Unix())
				return NewProposalStatusResolver(status)
			},
			action: func(resolver *ProposalStatusResolver) error {
				return resolver.updateVoteStatus(500, 40)
			},
			verify: func(t *testing.T, resolver *ProposalStatusResolver, err error) {
				uassert.Nil(t, err)
				voteResolver := NewProposalVoteStatusResolver(resolver.VoteStatus())
				uassert.Equal(t, voteResolver.MaxVotingWeight(), int64(500))
				uassert.Equal(t, voteResolver.QuorumAmount(), int64(200)) // 500 * 40 / 100
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := tc.setup()

			// when
			err := tc.action(resolver)

			// then
			tc.verify(t, resolver, err)
		})
	}
}

// TestProposalStatus_NewProposalStatus tests the NewProposalStatus constructor
func TestProposalStatus_NewProposalStatus(t *testing.T) {
	tests := []struct {
		name            string
		config          governance.Config
		maxVotingWeight int64
		executable      bool
		createdAt       int64
	}{
		{
			name: "Create with standard config",
			config: governance.Config{
				VotingStartDelay: 100,
				VotingPeriod:     200,
				ExecutionDelay:   100,
				ExecutionWindow:  200,
				Quorum:           50,
			},
			maxVotingWeight: 10_000_000_000,
			executable:      true,
			createdAt:       1000,
		},
		{
			name: "Create with zero delays",
			config: governance.Config{
				VotingStartDelay: 0,
				VotingPeriod:     0,
				ExecutionDelay:   0,
				ExecutionWindow:  0,
				Quorum:           0,
			},
			maxVotingWeight: 0,
			executable:      false,
			createdAt:       0,
		},
		{
			name: "Create with negative delays",
			config: governance.Config{
				VotingStartDelay: -1,
				VotingPeriod:     -1,
				ExecutionDelay:   -1,
				ExecutionWindow:  -1,
				Quorum:           -1,
			},
			maxVotingWeight: -1,
			executable:      true,
			createdAt:       -1,
		},
		{
			name: "Create non-executable proposal",
			config: governance.Config{
				VotingStartDelay: 100,
				VotingPeriod:     200,
				ExecutionDelay:   100,
				ExecutionWindow:  200,
				Quorum:           50,
			},
			maxVotingWeight: 10_000_000_000,
			executable:      false,
			createdAt:       time.Now().Unix(),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			status := NewProposalStatus(tc.config, tc.maxVotingWeight, tc.executable, tc.createdAt)

			// then
			uassert.NotNil(t, status)

			// Verify schedule status
			schedule := status.Schedule()
			uassert.NotNil(t, schedule)
			uassert.Equal(t, schedule.CreateTime(), tc.createdAt)
			uassert.Equal(t, schedule.ActiveTime(), tc.createdAt+tc.config.VotingStartDelay)
			uassert.Equal(t, schedule.VotingEndTime(), tc.createdAt+tc.config.VotingStartDelay+tc.config.VotingPeriod)
			uassert.Equal(t, schedule.ExecutableTime(), tc.createdAt+tc.config.VotingStartDelay+tc.config.VotingPeriod+tc.config.ExecutionDelay)
			uassert.Equal(t, schedule.ExpiredTime(), tc.createdAt+tc.config.VotingStartDelay+tc.config.VotingPeriod+tc.config.ExecutionDelay+tc.config.ExecutionWindow)

			// Verify action status
			actionStatus := status.ActionStatus()
			uassert.NotNil(t, actionStatus)
			uassert.Equal(t, actionStatus.IsExecutable(), tc.executable)
			uassert.False(t, actionStatus.IsExecuted())
			uassert.False(t, actionStatus.Canceled())

			// Verify vote status
			voteStatus := status.VoteStatus()
			uassert.NotNil(t, voteStatus)
			uassert.Equal(t, voteStatus.MaxVotingWeight(), tc.maxVotingWeight)
			uassert.Equal(t, voteStatus.QuorumAmount(), tc.maxVotingWeight*tc.config.Quorum/100)
			uassert.Equal(t, voteStatus.YesWeight(), int64(0))
			uassert.Equal(t, voteStatus.NoWeight(), int64(0))
		})
	}
}
