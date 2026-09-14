package governance

import (
	"testing"
	"time"

	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/gov/governance"
)

// TestProposalStatus_StatusType tests status type determination
func TestProposalStatus_StatusType(cur realm, t *testing.T) {
	baseTime := time.Unix(1000, 0)
	config := governance.NewConfig(100, 200, 0, 50, 0, 100, 200)

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
			name:            "Status Rejected - voting ended with no votes",
			currentTime:     baseTime.Add(time.Duration(350) * time.Second),
			maxVotingWeight: 1000,
			executable:      true,
			voteYes:         0,
			voteNo:          0,
			expectedStatus:  governance.StatusRejected,
		},
		{
			name:            "Status Rejected - voting ended with quorum not reached",
			currentTime:     baseTime.Add(time.Duration(350) * time.Second),
			maxVotingWeight: 1000,
			executable:      true,
			voteYes:         400,
			voteNo:          0,
			expectedStatus:  governance.StatusRejected,
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
			name:            "Status Rejected - tie but quorum not reached",
			currentTime:     baseTime.Add(time.Duration(350) * time.Second),
			maxVotingWeight: 1000,
			executable:      true,
			voteYes:         200,
			voteNo:          200,
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
			name:            "Status Rejected - tie with quorum reached",
			currentTime:     baseTime.Add(time.Duration(350) * time.Second),
			maxVotingWeight: 1000,
			executable:      true,
			voteYes:         500,
			voteNo:          500,
			expectedStatus:  governance.StatusRejected,
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
		t.Run(tc.name, func(cur realm, t *testing.T) {
			// given
			status := MakeProposalStatus(
				config, tc.maxVotingWeight, tc.executable, baseTime.Unix(),
				tc.maxVotingWeight,
			)
			resolver := NewProposalStatusResolver(status)

			// Add votes if specified
			var err error
			if tc.voteYes > 0 {
				err = resolver.vote(true, tc.voteYes)
			}
			if err == nil && tc.voteNo > 0 {
				err = resolver.vote(false, tc.voteNo)
			}

			// Execute or cancel if specified
			if err == nil && tc.isExecuted {
				err = resolver.execute(tc.currentTime.Unix(), 100, address("g1executor"))
			}
			if err == nil && tc.isCanceled {
				err = resolver.cancel(tc.currentTime.Unix(), 100, address("g1canceler"))
			}
			uassert.NoError(t, err)

			// when
			statusType := resolver.StatusType(tc.currentTime.Unix())

			// then
			uassert.Equal(t, statusType.String(), tc.expectedStatus.String())
		})
	}
}

// TestProposalStatus_VotingOperations tests voting operations
func TestProposalStatus_VotingOperations(cur realm, t *testing.T) {
	tests := []struct {
		name            string
		maxVotingWeight int64
		quorum          int64
		voteYes         int64
		voteNo          int64
		expectedTotal   int64
	}{
		{
			name:            "Voting with majority yes",
			maxVotingWeight: 1000,
			quorum:          500,
			voteYes:         600,
			voteNo:          300,
			expectedTotal:   900,
		},
		{
			name:            "Voting with majority no",
			maxVotingWeight: 1000,
			quorum:          500,
			voteYes:         300,
			voteNo:          600,
			expectedTotal:   900,
		},
		{
			name:            "Equal votes",
			maxVotingWeight: 1000,
			quorum:          500,
			voteYes:         400,
			voteNo:          400,
			expectedTotal:   800,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			// given
			config := governance.NewConfig(100, 200, 0, tc.quorum, 0, 100, 200)
			status := MakeProposalStatus(
				config, tc.maxVotingWeight, true, time.Now().Unix(),
				tc.maxVotingWeight,
			)
			resolver := NewProposalStatusResolver(status)

			// when
			var err error
			if tc.voteYes > 0 {
				err = resolver.vote(true, tc.voteYes)
			}
			if err == nil && tc.voteNo > 0 {
				err = resolver.vote(false, tc.voteNo)
			}
			uassert.NoError(t, err)

			// then
			uassert.Equal(t, resolver.VoteStatus().YesWeight(), tc.voteYes)
			uassert.Equal(t, resolver.VoteStatus().NoWeight(), tc.voteNo)

			statusResolver := NewProposalStatusResolver(resolver.ProposalStatus)
			uassert.Equal(t, statusResolver.TotalVoteWeight(), tc.expectedTotal)
		})
	}
}

// TestProposalStatusResolver_PrivateMethods tests private methods of proposal status resolver.
func TestProposalStatusResolver_PrivateMethods(cur realm, t *testing.T) {
	baseTime := time.Unix(1000, 0)
	config := governance.NewConfig(100, 200, 0, 50, 0, 100, 200)

	tests := []struct {
		name   string
		setup  func() *ProposalStatusResolver
		action func(*ProposalStatusResolver) error
		verify func(*testing.T, *ProposalStatusResolver, error)
	}{
		{
			name: "cancel - success",
			setup: func() *ProposalStatusResolver {
				status := MakeProposalStatus(config, 1000, true, baseTime.Unix(), 1000)
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
				status := MakeProposalStatus(config, 1000, true, baseTime.Unix(), 1000)
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
				status := MakeProposalStatus(config, 1000, true, baseTime.Unix(), 1000)
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
				status := MakeProposalStatus(config, 1000, true, baseTime.Unix(), 1000)
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
				status := MakeProposalStatus(config, 1000, true, baseTime.Unix(), 1000)
				resolver := NewProposalStatusResolver(status)
				uassert.NoError(t, resolver.vote(true, 300))
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
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			resolver := tc.setup()
			err := tc.action(resolver)
			tc.verify(t, resolver, err)
		})
	}
}

// TestProposalStatus_MakeProposalStatus tests the MakeProposalStatus constructor
func TestProposalStatus_MakeProposalStatus(cur realm, t *testing.T) {
	tests := []struct {
		name            string
		config          governance.Config
		maxVotingWeight int64
		executable      bool
		createdAt       int64
	}{
		{
			name:            "Create with standard config",
			config:          governance.NewConfig(100, 200, 0, 50, 0, 100, 200),
			maxVotingWeight: 10_000_000_000,
			executable:      true,
			createdAt:       1000,
		},
		{
			name:            "Create with zero delays",
			config:          governance.NewConfig(0, 0, 0, 0, 0, 0, 0),
			maxVotingWeight: 0,
			executable:      false,
			createdAt:       0,
		},
		{
			name:            "Create with negative delays",
			config:          governance.NewConfig(-1, -1, 0, -1, 0, -1, -1),
			maxVotingWeight: -1,
			executable:      true,
			createdAt:       -1,
		},
		{
			name:            "Create non-executable proposal",
			config:          governance.NewConfig(100, 200, 0, 50, 0, 100, 200),
			maxVotingWeight: 10_000_000_000,
			executable:      false,
			createdAt:       time.Now().Unix(),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			// when
			status := MakeProposalStatus(
				tc.config, tc.maxVotingWeight, tc.executable, tc.createdAt,
				tc.maxVotingWeight,
			)

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

func TestMakeProposalStatus_UsesCurrentXGnsSupplyForQuorum(cur realm, t *testing.T) {
	// Regression for GSW-2813: quorum must be based on total xGNS supply, not the smoothed voting weight.
	config := governance.NewConfig(100, 200, 86400, 50, 0, 100, 200)
	status := MakeProposalStatus(config, 500000, true, time.Now().Unix(), 1000000)

	uassert.Equal(t, int64(500000), status.VoteStatus().MaxVotingWeight())
	uassert.Equal(t, int64(500000), status.VoteStatus().QuorumAmount())
}
