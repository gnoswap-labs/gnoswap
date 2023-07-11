package gov

import (
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

type ProposalContent interface {
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
	Depositor string
	Amount bigint
}

type Proposal struct {
	// Proposal metadata
	ProposalID  uint64
	ProposalStatus ProposalStatus
	ProposalType ProposalType
	Proposer     Address

	// Proposal content
	Title      string
	Summary    string
	Metadata   string

	// Deposit data
	TotalDeposit bigint
	Deposits     []Deposit

	// Voting data
	Passed       bool
	YesVotes     bigint
	NoVotes      bigint
	AbstainVotes bigint // Explicitly abstained votes, excluding non-voters
	
	// Internal timestamps
	SubmitTime   uint64
	DepositEndTime uint64
	VotingStartTime uint64
	VotingEndTime uint64
	ExecutedTime uint64

	// Cached gov parameters, set at proposal creation time
	// Governance parameter changes are not retroactive
	DepositPeriod uint64
	DepositMinimum bigint
	VotingPeriod uint64
	VoteQuorum VoteQuorum

	// Execution data
	ProposalData ProposalData
}

func newProposal(
	proposalID uint64,
	proposalType ProposalType,
	proposer Address,

	initialDeposit bigint,

	title string,
	summary string,
	metadata string,

	data ProposalData,
) Proposal {
	depositPeriod := getDepositPeriod()
	depositMinimum := getDepositMinimum()
	votingPeriod := getVotingPeriod()
	voteQuorum := getVoteQuorum()
	deposits := make([]Deposit, 0)
	if initialDeposit > 0 {
		deposits = append(deposits, Deposit{
			Depositor: proposer,
			Amount: initialDeposit,
		})
	}

	return Proposal{
		ProposalID: proposalID,
		ProposalStatus: ProposalStatusDepositPeriod,
		ProposalType: data.ProposalType(),
		Proposer: proposer,

		Title: title,
		Summary: summary,
		Metadata: metadata,

		TotalDeposit: initialDeposit,
		Deposits: deposits,

		Passed: false,
		YesVotes: 0,
		NoVotes: 0,
		AbstainVotes: 0,

		SubmitTime: time.Now(),
		DepositEndTime: time.Now().Add(depositPeriod),
		VotingStartTime: 0,
		VotingEndTime: 0,

		DepositPeriod: depositPeriod,
		DepositMinimum: depositMinimum,
		VotingPeriod: votingPeriod,
		VoteQuorum: voteQuorum,

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