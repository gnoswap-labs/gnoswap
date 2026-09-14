package governance

import (
	gnsmath "gno.land/p/gnoswap/gnsmath"

	"gno.land/r/gnoswap/gov/governance"
)

type ProposalStatusResolver struct {
	status governance.ProposalStatus
}

func MakeProposalStatusResolver(status governance.ProposalStatus) ProposalStatusResolver {
	return ProposalStatusResolver{status: status}
}

func (p ProposalStatusResolver) Value() governance.ProposalStatus {
	return p.status
}

func (p ProposalStatusResolver) Schedule() governance.ProposalScheduleStatus {
	return p.status.Schedule()
}

func (p ProposalStatusResolver) ActionStatus() governance.ProposalActionStatus {
	return p.status.ActionStatus()
}

func (p ProposalStatusResolver) VoteStatus() governance.ProposalVoteStatus {
	return p.status.VoteStatus()
}

func (p ProposalStatusResolver) TotalVoteWeight() int64 {
	return MakeProposalVoteStatusResolver(p.status.VoteStatus()).TotalVoteWeight()
}

func (p ProposalStatusResolver) StatusType(current int64) governance.ProposalStatusType {
	actionStatus := p.status.ActionStatus()
	if actionStatus.IsExecuted() {
		return governance.StatusExecuted
	}
	if actionStatus.Canceled() {
		return governance.StatusCanceled
	}
	scheduleResolver := MakeProposalScheduleStatusResolver(p.status.Schedule())
	if !scheduleResolver.IsPassedActiveAt(current) {
		return governance.StatusUpcoming
	}
	if !scheduleResolver.IsPassedVotingEndedAt(current) {
		return governance.StatusActive
	}
	if !MakeProposalVoteStatusResolver(p.status.VoteStatus()).IsPassed() {
		return governance.StatusRejected
	}
	if !actionStatus.IsExecutable() || !scheduleResolver.IsPassedExecutableAt(current) {
		return governance.StatusPassed
	}
	if !scheduleResolver.IsPassedExpiredAt(current) {
		return governance.StatusExecutable
	}
	return governance.StatusExpired
}

func (p ProposalStatusResolver) IsUpcoming(current int64) bool {
	return p.StatusType(current) == governance.StatusUpcoming
}

func (p ProposalStatusResolver) IsActive(current int64) bool {
	return p.StatusType(current) == governance.StatusActive
}

func (p ProposalStatusResolver) IsPassed(current int64) bool {
	return p.StatusType(current) == governance.StatusPassed
}

func (p ProposalStatusResolver) IsRejected(current int64) bool {
	return p.StatusType(current) == governance.StatusRejected
}

func (p ProposalStatusResolver) IsExecutable(current int64) bool {
	return p.StatusType(current) == governance.StatusExecutable
}

func (p ProposalStatusResolver) IsExpired(current int64) bool {
	return p.StatusType(current) == governance.StatusExpired
}

func (p ProposalStatusResolver) IsExecuted(current int64) bool {
	return p.StatusType(current) == governance.StatusExecuted
}

func (p ProposalStatusResolver) IsCanceled(current int64) bool {
	return p.StatusType(current) == governance.StatusCanceled
}

func (p ProposalStatusResolver) cancel(canceledAt, canceledHeight int64, canceledBy address) (ProposalStatusResolver, error) {
	actionResolver, err := MakeProposalActionStatusResolver(p.status.ActionStatus()).cancel(canceledAt, canceledHeight, canceledBy)
	if err != nil {
		return p, err
	}
	p.status = p.status.WithActionStatus(actionResolver.Value())
	return p, nil
}

func (p ProposalStatusResolver) execute(executedAt, executedHeight int64, executedBy address) (ProposalStatusResolver, error) {
	actionResolver, err := MakeProposalActionStatusResolver(p.status.ActionStatus()).Execute(executedAt, executedHeight, executedBy)
	if err != nil {
		return p, err
	}
	p.status = p.status.WithActionStatus(actionResolver.Value())
	return p, nil
}

func (p ProposalStatusResolver) vote(votedYes bool, weight int64) (ProposalStatusResolver, error) {
	voteResolver := MakeProposalVoteStatusResolver(p.status.VoteStatus())
	var err error
	if votedYes {
		voteResolver, err = voteResolver.AddYesVoteWeight(weight)
	} else {
		voteResolver, err = voteResolver.AddNoVoteWeight(weight)
	}
	if err != nil {
		return p, err
	}
	p.status = p.status.WithVoteStatus(voteResolver.Value())
	return p, nil
}

// MakeProposalStatus calculates the schedule and initial vote/action statuses.
func MakeProposalStatus(
	config governance.Config,
	maxVotingWeight int64,
	executable bool,
	createdAt int64,
	quorumWeight int64,
) governance.ProposalStatus {
	schedule := MakeProposalScheduleStatus(
		config.VotingStartDelay,
		config.VotingPeriod,
		config.ExecutionDelay,
		config.ExecutionWindow,
		createdAt,
	)
	actionStatus := governance.MakeProposalActionStatus(executable)
	quorumAmount := gnsmath.SafeMulDivInt64(quorumWeight, config.Quorum, 100)
	voteStatus := governance.MakeProposalVoteStatus(maxVotingWeight, quorumAmount)
	return governance.MakeProposalStatusBy(schedule, actionStatus, voteStatus)
}
