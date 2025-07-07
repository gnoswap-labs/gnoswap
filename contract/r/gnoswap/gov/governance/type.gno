package governance

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
)

// ProposalInfo represents all the information about a proposal
type ProposalInfo struct {
	Proposer      std.Address // The address of the proposer
	ConfigVersion uint64      // The version of the config
	Status        ProposalStatus
	Voting        VotingInfo
	Metadata      ProposalMetadata
	Data          ProposalData
}

// ProposalStatusEnum combines schedule and action state
// This represents the complete status information for a proposal
type ProposalStatus struct {
	Schedule    ProposalSchedule
	ActionState ActionState
}

// VotingInfo contains all voting-related information for a proposal
type VotingInfo struct {
	Yea             *u256.Uint // collected yes votes
	Nay             *u256.Uint // collected no votes
	MaxVotingWeight *u256.Uint // The max voting weight at the time of proposal creation

	// Addresses that can vote with their respective weights
	PossibleAddressWithWeight map[std.Address]uint64

	QuorumAmount uint64 // How many total votes must be collected for the proposal
}

// ProposalMetadata contains descriptive information about a proposal
type ProposalMetadata struct {
	Title       string
	Description string
}

// ProposalData contains the type-specific data for a proposal
type ProposalData struct {
	ProposalType       ProposalType
	CommunityPoolSpend CommunityPoolSpendInfo
	Execution          ExecutionInfo
	RoleChange         RoleChangeInfo
}

// ProposalSchedule represents the pre-calculated time schedule for a proposal
type ProposalSchedule struct {
	CreateTime     uint64 // When the proposal was created
	ActiveTime     uint64 // When voting starts (CreateTime + VotingStartDelay)
	VotingEndTime  uint64 // When voting ends (ActiveTime + VotingPeriod)
	ExecutableTime uint64 // When execution window starts (VotingEndTime + ExecutionDelay)
	ExpiredTime    uint64 // When execution window ends (ExecutableTime + ExecutionWindow)
}

// IsVotingPeriod checks if the given time is within the voting period
func (s ProposalSchedule) IsVotingPeriod(now uint64) bool {
	return now >= s.ActiveTime && now <= s.VotingEndTime
}

// IsExecutionPeriod checks if the given time is within the execution period
func (s ProposalSchedule) IsExecutionPeriod(now uint64) bool {
	return now >= s.ExecutableTime && now <= s.ExpiredTime
}

// IsExpired checks if the proposal has expired at the given time
func (s ProposalSchedule) IsExpired(now uint64) bool {
	return now > s.ExpiredTime
}

// ActionState represents the action-based state changes of a proposal
type ActionState struct {
	Canceled   bool
	CanceledAt uint64
	CanceledBy std.Address // Who canceled the proposal

	Executed   bool
	ExecutedAt uint64
	ExecutedBy std.Address // Who executed the proposal
}

func (a ActionState) IsCanceled() bool { return a.Canceled }
func (a ActionState) IsExecuted() bool { return a.Executed }

// IsActionTaken returns true if any action has been taken on the proposal
func (a ActionState) IsActionTaken() bool {
	return a.Canceled || a.Executed
}

type CommunityPoolSpendInfo struct {
	To        std.Address
	TokenPath string
	Amount    uint64
}

type ExecutionInfo struct {
	Num  uint64
	Msgs []string // split by *GOV*
}

type ParameterChangeInfo struct {
	PkgPath  string
	Function string
	Params   string
}

type ProposalType string

const (
	Text               ProposalType = "TEXT"
	CommunityPoolSpend ProposalType = "COMMUNITY_POOL_SPEND"
	ParameterChange    ProposalType = "PARAMETER_CHANGE"
	RoleChange         ProposalType = "ROLE_CHANGE"
)

func tryParseProposalType(v string) (ProposalType, error) {
	switch v {
	case "TEXT":
		return Text, nil
	case "COMMUNITY_POOL_SPEND":
		return CommunityPoolSpend, nil
	case "PARAMETER_CHANGE":
		return ParameterChange, nil
	case "ROLE_CHANGE":
		return RoleChange, nil
	default:
		return "", errInvalidProposalType
	}
}

func (p ProposalType) String() string {
	return string(p)
}
