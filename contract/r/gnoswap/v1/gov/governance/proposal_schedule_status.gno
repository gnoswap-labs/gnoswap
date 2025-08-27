package governance

// ProposalScheduleStatus represents the pre-calculated time schedule for a proposal.
// This structure defines all the important timestamps in a proposal's lifecycle,
// from creation through voting to execution and expiration.
type ProposalScheduleStatus struct {
	createTime     int64 // When the proposal was created
	activeTime     int64 // When voting starts (CreateTime + VotingStartDelay)
	votingEndTime  int64 // When voting ends (ActiveTime + VotingPeriod)
	executableTime int64 // When execution window starts (VotingEndTime + ExecutionDelay)
	expiredTime    int64 // When execution window ends (ExecutableTime + ExecutionWindow)
}

// IsPassedCreatedAt checks if the current time has passed the proposal creation time.
// This is always true once a proposal exists.
//
// Parameters:
//   - current: timestamp to check against
//
// Returns:
//   - bool: true if current time is at or after creation time
func (p *ProposalScheduleStatus) IsPassedCreatedAt(current int64) bool {
	return p.createTime <= current
}

// IsPassedActiveAt checks if the current time has passed the voting start time.
// When true, the proposal enters its active voting period.
//
// Parameters:
//   - current: timestamp to check against
//
// Returns:
//   - bool: true if voting period has started
func (p *ProposalScheduleStatus) IsPassedActiveAt(current int64) bool {
	return p.activeTime <= current
}

// IsPassedVotingEndedAt checks if the current time has passed the voting end time.
// When true, no more votes can be cast on the proposal.
//
// Parameters:
//   - current: timestamp to check against
//
// Returns:
//   - bool: true if voting period has ended
func (p *ProposalScheduleStatus) IsPassedVotingEndedAt(current int64) bool {
	return p.votingEndTime <= current
}

// IsPassedExecutableAt checks if the current time has passed the execution start time.
// When true, approved proposals can be executed (after execution delay).
//
// Parameters:
//   - current: timestamp to check against
//
// Returns:
//   - bool: true if execution window has started
func (p *ProposalScheduleStatus) IsPassedExecutableAt(current int64) bool {
	return p.executableTime <= current
}

// IsPassedExpiredAt checks if the current time has passed the execution expiration time.
// When true, the proposal can no longer be executed and has expired.
//
// Parameters:
//   - current: timestamp to check against
//
// Returns:
//   - bool: true if execution window has expired
func (p *ProposalScheduleStatus) IsPassedExpiredAt(current int64) bool {
	return p.expiredTime <= current
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
) *ProposalScheduleStatus {
	// Calculate all phase timestamps based on creation time and configuration
	createTime := createdAt
	activeTime := createTime + votingStartDelay      // When voting can start
	votingEndTime := activeTime + votingPeriod       // When voting ends
	executableTime := votingEndTime + executionDelay // When execution can start
	expiredTime := executableTime + executionWindow  // When execution window closes

	return &ProposalScheduleStatus{
		createTime:     createTime,
		activeTime:     activeTime,
		votingEndTime:  votingEndTime,
		executableTime: executableTime,
		expiredTime:    expiredTime,
	}
}
