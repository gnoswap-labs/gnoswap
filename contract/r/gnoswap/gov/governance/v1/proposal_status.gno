package governance

import (
	gnsmath "gno.land/p/gnoswap/gnsmath"

	"gno.land/r/gnoswap/gov/governance"
)

type ProposalStatusResolver struct {
	status               governance.ProposalStatus
	scheduleResolver     ProposalScheduleStatusResolver
	actionStatusResolver ProposalActionStatusResolver
	voteStatusResolver   ProposalVoteStatusResolver
}

func MakeProposalStatusResolver(status governance.ProposalStatus) ProposalStatusResolver {
	return ProposalStatusResolver{
		status:               status,
		scheduleResolver:     MakeProposalScheduleStatusResolver(status.Schedule()),
		actionStatusResolver: MakeProposalActionStatusResolver(status.ActionStatus()),
		voteStatusResolver:   MakeProposalVoteStatusResolver(status.VoteStatus()),
	}
}

func (p ProposalStatusResolver) Value() governance.ProposalStatus {
	status := p.status
	status = status.WithSchedule(p.scheduleResolver.Value())
	status = status.WithActionStatus(p.actionStatusResolver.Value())
	status = status.WithVoteStatus(p.voteStatusResolver.Value())
	return status
}

func (p ProposalStatusResolver) Schedule() governance.ProposalScheduleStatus {
	return p.scheduleResolver.Value()
}

func (p ProposalStatusResolver) ActionStatus() governance.ProposalActionStatus {
	return p.actionStatusResolver.Value()
}

func (p ProposalStatusResolver) VoteStatus() governance.ProposalVoteStatus {
	return p.voteStatusResolver.Value()
}

func (p ProposalStatusResolver) TotalVoteWeight() int64 {
	return p.voteStatusResolver.TotalVoteWeight()
}

func (p ProposalStatusResolver) StatusType(current int64) governance.ProposalStatusType {
	if p.actionStatusResolver.IsExecuted() {
		return governance.StatusExecuted
	}
	if p.actionStatusResolver.Canceled() {
		return governance.StatusCanceled
	}
	if !p.scheduleResolver.IsPassedActiveAt(current) {
		return governance.StatusUpcoming
	}
	if !p.scheduleResolver.IsPassedVotingEndedAt(current) {
		return governance.StatusActive
	}
	if !p.voteStatusResolver.IsPassed() {
		return governance.StatusRejected
	}
	if !p.actionStatusResolver.IsExecutable() || !p.scheduleResolver.IsPassedExecutableAt(current) {
		return governance.StatusPassed
	}
	if !p.scheduleResolver.IsPassedExpiredAt(current) {
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
	actionResolver, err := p.actionStatusResolver.cancel(canceledAt, canceledHeight, canceledBy)
	if err != nil {
		return p, err
	}
	p.actionStatusResolver = actionResolver
	p.status = p.status.WithActionStatus(actionResolver.Value())
	return p, nil
}

func (p ProposalStatusResolver) execute(executedAt, executedHeight int64, executedBy address) (ProposalStatusResolver, error) {
	actionResolver, err := p.actionStatusResolver.Execute(executedAt, executedHeight, executedBy)
	if err != nil {
		return p, err
	}
	p.actionStatusResolver = actionResolver
	p.status = p.status.WithActionStatus(actionResolver.Value())
	return p, nil
}

func (p ProposalStatusResolver) vote(votedYes bool, weight int64) (ProposalStatusResolver, error) {
	var (
		voteResolver ProposalVoteStatusResolver
		err          error
	)
	if votedYes {
		voteResolver, err = p.voteStatusResolver.AddYesVoteWeight(weight)
	} else {
		voteResolver, err = p.voteStatusResolver.AddNoVoteWeight(weight)
	}
	if err != nil {
		return p, err
	}
	p.voteStatusResolver = voteResolver
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
