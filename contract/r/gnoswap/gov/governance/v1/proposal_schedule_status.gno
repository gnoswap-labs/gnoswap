package governance

import (
	gnsmath "gno.land/p/gnoswap/gnsmath"

	"gno.land/r/gnoswap/gov/governance"
)

type ProposalScheduleStatusResolver struct {
	status governance.ProposalScheduleStatus
}

func MakeProposalScheduleStatusResolver(status governance.ProposalScheduleStatus) ProposalScheduleStatusResolver {
	return ProposalScheduleStatusResolver{status: status}
}

func (p ProposalScheduleStatusResolver) Value() governance.ProposalScheduleStatus {
	return p.status
}

func (p ProposalScheduleStatusResolver) IsPassedCreatedAt(current int64) bool {
	return p.status.CreateTime() <= current
}

func (p ProposalScheduleStatusResolver) IsPassedActiveAt(current int64) bool {
	return p.status.ActiveTime() <= current
}

func (p ProposalScheduleStatusResolver) IsPassedVotingEndedAt(current int64) bool {
	return p.status.VotingEndTime() <= current
}

func (p ProposalScheduleStatusResolver) IsPassedExecutableAt(current int64) bool {
	return p.status.ExecutableTime() <= current
}

func (p ProposalScheduleStatusResolver) IsPassedExpiredAt(current int64) bool {
	return p.status.ExpiredTime() <= current
}

// MakeProposalScheduleStatus calculates the proposal lifecycle timestamps.
func MakeProposalScheduleStatus(
	votingStartDelay,
	votingPeriod,
	executionDelay,
	executionWindow,
	createdAt int64,
) governance.ProposalScheduleStatus {
	createTime := createdAt
	activeTime := gnsmath.SafeAddInt64(createTime, votingStartDelay)
	votingEndTime := gnsmath.SafeAddInt64(activeTime, votingPeriod)
	executableTime := gnsmath.SafeAddInt64(votingEndTime, executionDelay)
	expiredTime := gnsmath.SafeAddInt64(executableTime, executionWindow)

	return governance.MakeProposalScheduleStatus(
		createTime,
		activeTime,
		votingEndTime,
		executableTime,
		expiredTime,
	)
}
