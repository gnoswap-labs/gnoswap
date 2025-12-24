package v1

import (
	"gno.land/r/gnoswap/gov/governance"
)

type ProposalScheduleStatusResolver struct {
	*governance.ProposalScheduleStatus
}

func NewProposalScheduleStatusResolver(status *governance.ProposalScheduleStatus) *ProposalScheduleStatusResolver {
	return &ProposalScheduleStatusResolver{status}
}

// IsPassedCreatedAt checks if the current time has passed the proposal creation time.
// This is always true once a proposal exists.
//
// Parameters:
//   - current: timestamp to check against
//
// Returns:
//   - bool: true if current time is at or after creation time
func (p *ProposalScheduleStatusResolver) IsPassedCreatedAt(current int64) bool {
	return p.CreateTime() <= current
}

// IsPassedActiveAt checks if the current time has passed the voting start time.
// When true, the proposal enters its active voting period.
//
// Parameters:
//   - current: timestamp to check against
//
// Returns:
//   - bool: true if voting period has started
func (p *ProposalScheduleStatusResolver) IsPassedActiveAt(current int64) bool {
	return p.ActiveTime() <= current
}

// IsPassedVotingEndedAt checks if the current time has passed the voting end time.
// When true, no more votes can be cast on the proposal.
//
// Parameters:
//   - current: timestamp to check against
//
// Returns:
//   - bool: true if voting period has ended
func (p *ProposalScheduleStatusResolver) IsPassedVotingEndedAt(current int64) bool {
	return p.VotingEndTime() <= current
}

// IsPassedExecutableAt checks if the current time has passed the execution start time.
// When true, approved proposals can be executed (after execution delay).
//
// Parameters:
//   - current: timestamp to check against
//
// Returns:
//   - bool: true if execution window has started
func (p *ProposalScheduleStatusResolver) IsPassedExecutableAt(current int64) bool {
	return p.ExecutableTime() <= current
}

// IsPassedExpiredAt checks if the current time has passed the execution expiration time.
// When true, the proposal can no longer be executed and has expired.
//
// Parameters:
//   - current: timestamp to check against
//
// Returns:
//   - bool: true if execution window has expired
func (p *ProposalScheduleStatusResolver) IsPassedExpiredAt(current int64) bool {
	return p.ExpiredTime() <= current
}

// NewProposalScheduleStatus creates a new schedule status with calculated timestamps.
// This constructor takes the governance timing parameters and calculates all
// important timestamps for the proposal's lifecycle.
//
// Parameters:
//   - votingStartDelay: delay before voting starts (seconds)
//   - votingPeriod: duration of voting period (seconds)
//   - executionDelay: delay before execution can start (seconds)
//   - executionWindow: window during which execution is allowed (seconds)
//   - createdAt: timestamp when proposal was created
//
// Returns:
//   - *ProposalScheduleStatus: new schedule status with calculated times
func NewProposalScheduleStatus(
	votingStartDelay,
	votingPeriod,
	executionDelay,
	executionWindow,
	createdAt int64,
) *governance.ProposalScheduleStatus {
	// Calculate all phase timestamps based on creation time and configuration
	createTime := createdAt
	activeTime := safeAddInt64(createTime, votingStartDelay)      // When voting can start
	votingEndTime := safeAddInt64(activeTime, votingPeriod)       // When voting ends
	executableTime := safeAddInt64(votingEndTime, executionDelay) // When execution can start
	expiredTime := safeAddInt64(executableTime, executionWindow)  // When execution window closes

	return governance.NewProposalScheduleStatus(createTime, activeTime, votingEndTime, executableTime, expiredTime)
}
