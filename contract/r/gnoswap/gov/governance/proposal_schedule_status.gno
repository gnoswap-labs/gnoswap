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

func NewProposalScheduleStatusInstance(
	createTime int64,
	activeTime int64,
	votingEndTime int64,
	executableTime int64,
	expiredTime int64,
) *ProposalScheduleStatus {
	return &ProposalScheduleStatus{
		createTime: createTime,
		activeTime: activeTime,
		votingEndTime: votingEndTime,
		executableTime: executableTime,
		expiredTime: expiredTime,
	}
}

/* Getter methods */
func (p *ProposalScheduleStatus) CreateTime() int64 { return p.createTime }
func (p *ProposalScheduleStatus) ActiveTime() int64 { return p.activeTime }
func (p *ProposalScheduleStatus) VotingEndTime() int64 { return p.votingEndTime }
func (p *ProposalScheduleStatus) ExecutableTime() int64 { return p.executableTime }
func (p *ProposalScheduleStatus) ExpiredTime() int64 { return p.expiredTime }

/* Setter methods */
func (p *ProposalScheduleStatus) SetCreateTime(createTime int64) { p.createTime = createTime }
func (p *ProposalScheduleStatus) SetActiveTime(activeTime int64) { p.activeTime = activeTime }
func (p *ProposalScheduleStatus) SetVotingEndTime(votingEndTime int64) { p.votingEndTime = votingEndTime }
func (p *ProposalScheduleStatus) SetExecutableTime(executableTime int64) { p.executableTime = executableTime }
func (p *ProposalScheduleStatus) SetExpiredTime(expiredTime int64) { p.expiredTime = expiredTime }
