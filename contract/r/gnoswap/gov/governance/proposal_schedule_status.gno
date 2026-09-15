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

// NewProposalScheduleStatus creates a proposal schedule from its lifecycle timestamps.
//
// Parameters:
//   - createTime: Unix timestamp when the proposal was created
//   - activeTime: Unix timestamp when voting starts
//   - votingEndTime: Unix timestamp when voting ends
//   - executableTime: Unix timestamp when the execution window starts
//   - expiredTime: Unix timestamp when the execution window closes
//
// Returns:
//   - *ProposalScheduleStatus: schedule containing the supplied lifecycle timestamps
func NewProposalScheduleStatus(
	createTime int64,
	activeTime int64,
	votingEndTime int64,
	executableTime int64,
	expiredTime int64,
) *ProposalScheduleStatus {
	return &ProposalScheduleStatus{
		createTime:     createTime,
		activeTime:     activeTime,
		votingEndTime:  votingEndTime,
		executableTime: executableTime,
		expiredTime:    expiredTime,
	}
}

/* Getter methods */
// CreateTime returns the Unix timestamp when the proposal was created.
//
// Returns:
//   - int64: proposal creation timestamp
func (p *ProposalScheduleStatus) CreateTime() int64 { return p.createTime }

// ActiveTime returns the Unix timestamp when proposal voting starts.
//
// Returns:
//   - int64: voting start timestamp
func (p *ProposalScheduleStatus) ActiveTime() int64 { return p.activeTime }

// VotingEndTime returns the Unix timestamp when proposal voting ends.
//
// Returns:
//   - int64: voting end timestamp
func (p *ProposalScheduleStatus) VotingEndTime() int64 { return p.votingEndTime }

// ExecutableTime returns the Unix timestamp when the execution window starts.
//
// Returns:
//   - int64: execution start timestamp
func (p *ProposalScheduleStatus) ExecutableTime() int64 { return p.executableTime }

// ExpiredTime returns the Unix timestamp when the execution window closes.
//
// Returns:
//   - int64: execution expiration timestamp
func (p *ProposalScheduleStatus) ExpiredTime() int64 { return p.expiredTime }

/* Setter methods */
// SetCreateTime updates the proposal creation timestamp.
//
// Parameters:
//   - createTime: Unix timestamp when the proposal was created
func (p *ProposalScheduleStatus) SetCreateTime(createTime int64) {
	p.createTime = createTime
}

// SetActiveTime updates the timestamp when proposal voting starts.
//
// Parameters:
//   - activeTime: Unix timestamp when voting starts
func (p *ProposalScheduleStatus) SetActiveTime(activeTime int64) {
	p.activeTime = activeTime
}

// SetVotingEndTime updates the timestamp when proposal voting ends.
//
// Parameters:
//   - votingEndTime: Unix timestamp when voting ends
func (p *ProposalScheduleStatus) SetVotingEndTime(votingEndTime int64) {
	p.votingEndTime = votingEndTime
}

// SetExecutableTime updates the timestamp when proposal execution can start.
//
// Parameters:
//   - executableTime: Unix timestamp when the execution window starts
func (p *ProposalScheduleStatus) SetExecutableTime(executableTime int64) {
	p.executableTime = executableTime
}

// SetExpiredTime updates the timestamp when proposal execution expires.
//
// Parameters:
//   - expiredTime: Unix timestamp when the execution window closes
func (p *ProposalScheduleStatus) SetExpiredTime(expiredTime int64) {
	p.expiredTime = expiredTime
}

// Clone creates a deep copy of the ProposalScheduleStatus.
//
// Returns:
//   - *ProposalScheduleStatus: copied schedule, or nil when the receiver is nil
func (p *ProposalScheduleStatus) Clone() *ProposalScheduleStatus {
	if p == nil {
		return nil
	}

	return &ProposalScheduleStatus{
		createTime:     p.createTime,
		activeTime:     p.activeTime,
		votingEndTime:  p.votingEndTime,
		executableTime: p.executableTime,
		expiredTime:    p.expiredTime,
	}
}
