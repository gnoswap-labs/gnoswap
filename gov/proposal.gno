package gov

import (
	"std"

	"time"
)

type ProposalType uint8

const (
	ProposalTypeText ProposalType = iota
	ProposalTypeCommunityPoolSpend
	ProposalTypeMint
	ProposalTypeEmergencyHalt
	ProposalTypeParameterChange
	/*
		ProposalTypeSwapParameterProtocolFee
		ProposalTypeStakerParameterInflationRate
		ProposalTypeStakerParameterStakingRewards
		ProposalTypeGovParameterDepositPeriod
		ProposalTypeGovParameterDepositMinimum
		ProposalTypeGovParameterVotingPeriod
		ProposalTypeGovParameterVoteQuorum
	*/
)

type ProposalData interface {
	ProposalType() ProposalType
	isProposalData()

	// execute() should not panic
	// proposals are executed in order from the queue, so if one proposal panics, the whole governance module will be halted.
	execute() error
}

type ProposalStatus uint8

const (
	ProposalStatusNil ProposalStatus = iota
	ProposalStatusDepositPeriod
	ProposalStatusVotingPeriod
	ProposalStatusPassed
	ProposalStatusRejected
	ProposalStatusFailed
)

type Deposit struct {
	Depositor std.Address
	Amount    uint64
}

type Proposal struct {
	// Proposal metadata
	ProposalID     uint64
	ProposalStatus ProposalStatus
	ProposalType   ProposalType
	Proposer       std.Address

	// Proposal content
	Title    string
	Summary  string
	Metadata string

	// Deposit data
	TotalDeposit uint64

	// Voting data
	Passed       bool
	YesVotes     uint64
	NoVotes      uint64
	AbstainVotes uint64 // Explicitly abstained votes, excluding non-voters

	// Internal timestamps
	SubmitTime      uint64
	DepositEndTime  uint64
	VotingStartTime uint64
	VotingEndTime   uint64
	ExecutedTime    uint64

	// Cached gov parameters, set at proposal creation time
	// Governance parameter changes are not retroactive
	DepositPeriod  uint64
	DepositMinimum uint64
	VotingPeriod   uint64
	VoteQuorum     VoteQuorum

	// Execution data
	ProposalData ProposalData
}

func newProposal(
	proposalID uint64,
	proposer std.Address,

	initialDeposit uint64,

	title string,
	summary string,
	metadata string,

	data ProposalData,
) *Proposal {
	depositPeriod := getDepositPeriod()
	depositMinimum := getDepositMinimum()
	votingPeriod := getVotePeriod()
	voteQuorum := getVoteQuorum()
	deposits := make([]Deposit, 0)
	if initialDeposit > 0 {
		deposits = append(deposits, Deposit{
			Depositor: proposer,
			Amount:    initialDeposit,
		})
	}

	return &Proposal{
		ProposalID:     proposalID,
		ProposalStatus: ProposalStatusDepositPeriod,
		ProposalType:   data.ProposalType(),
		Proposer:       proposer,

		Title:    title,
		Summary:  summary,
		Metadata: metadata,

		TotalDeposit: initialDeposit,

		Passed:       false,
		YesVotes:     0,
		NoVotes:      0,
		AbstainVotes: 0,

		SubmitTime:      uint64(time.Now().Unix()),
		DepositEndTime:  uint64(time.Now().Unix() + int64(depositPeriod)),
		VotingStartTime: 0,
		VotingEndTime:   0,

		DepositPeriod:  depositPeriod,
		DepositMinimum: depositMinimum,
		VotingPeriod:   votingPeriod,
		VoteQuorum:     voteQuorum,

		ProposalData: data,
	}
}

func (p Proposal) isActive() bool {
	return p.ProposalStatus == ProposalStatusDepositPeriod || p.ProposalStatus == ProposalStatusVotingPeriod
}

func (p Proposal) hasMetEndTime(currentTime uint64) bool {
	return p.ProposalStatus == ProposalStatusDepositPeriod && p.DepositEndTime <= currentTime ||
		p.ProposalStatus == ProposalStatusVotingPeriod && p.VotingEndTime <= currentTime
}
