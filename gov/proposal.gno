package gov

type ProposalType uint8

const (
	ProposalTypeText ProposalType = iota	
	ProposalTypeCommunityPoolSpend
	ProposalTypeMint
	ProposalTypeEmergencyHalt
	ProposalTypeSwapParameterProtocolFee
	ProposalTypeSwapParameterStakingRewards
	ProposalTypeSwapParameterInflationRate
	ProposalTypeGovParameterDepositPeriod
	ProposalTypeGovParameterDepositMinimum
	ProposalTypeGovParameterVotingPeriod
	ProposalTypeGovParameterVoteQuorum
)

type ProposalData interface {
	ProposalType() ProposalType
	isProposalData()
	isValid() bool

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
	TotalDeposit      bigint

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
	DepositMinimumNumerator bigint
	DepositMinimumDenominator bigint
	VotingPeriod uint64
	VoteQuorumNumerator bigint
	VoteQuorumDenominator bigint

	// Execution data
	ProposalData ProposalData
}

func (p Proposal) isLive() bool {
	return p.ProposalStatus == ProposalStatusDepositPeriod || p.ProposalStatus == ProposalStatusVotingPeriod
}

func (p Proposal) hasMetEndTime(currentTime uint64) bool {
	return p.ProposalStatus == ProposalStatusDepositPeriod && p.DepositEndTime <= currentTime ||
		p.ProposalStatus == ProposalStatusVotingPeriod && p.VotingEndTime <= currentTime
}