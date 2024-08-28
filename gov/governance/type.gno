package governance

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
)

// Config represents the configuration of the governor contract
type Config struct {
	// How long after a proposal is created does voting starrt
	VotingStartDelay uint64

	// The period during which votes are collected
	VotingPeriod uint64

	// Over how many seconds the voting weight is averaged for proposal voting as creation/cancellation threshold
	VotingWeightSmoothingDuration uint64

	// How many total votes must be collected for the proposal
	Quorum uint64

	// The munimum amount of average votes required to create a proposal
	ProposalCreationThreshold uint64

	// How much time must pass after the end of a voting period before a proposal can be executed
	ExecutionDelay uint64

	// The amount of time after the execution delay that the proposal can be executed
	ExecutionWindow uint64
}

// ExecutionState represents the state of a proposal's execution
type ExecutionState struct {
	Created   bool
	CreatedAt uint64

	Upcoming bool
	Active   bool

	Passed   bool
	PassedAt uint64

	Rejected   bool
	RejectedAt uint64

	Canceled   bool
	CanceledAt uint64

	// LABEL
	Executed   bool
	ExecutedAt uint64

	Expired   bool
	ExpiredAt uint64
}

// ProposalInfo represents all the information about a proposal
type ProposalInfo struct {
	// The address of the proposer
	Proposer std.Address

	ProposalType string

	// The execution state of the proposal
	ExecutionState ExecutionState

	// How many yes votes have been collected
	Yea *u256.Uint

	// How many no votes have been collected
	Nay *u256.Uint

	// The version of the config that this proposal was created with
	ConfigVersion uint64

	// The title of the proposal
	Title string

	// The description of the proposal
	Description string

	// The list of calls that will be executed if the proposal is successful
	ExecuteMsg string
}

// TODO: dynamic call
// Call represents a contract call
type Call struct {
	// To       std.Address
	// Selector uint64
	To  std.Address // TODO: XXX: need this ??
	Key string      // pkg_path + ":" + fn_name

	Calldata string
}

// TODO: XXX : need this ??
// hashCalls computes the hash of a list of calls
// func hashCalls(calls []Call) string {
// 	var buf strings.Builder
// 	buf.WriteString("governance::governor::Governor::hash_calls")

// 	for _, call := range calls {
// 		buf.WriteString(string(call.To))
// 		buf.WriteString(strconv.FormatUint(call.Key, 10))
// 		buf.WriteString(call.Calldata)
// 	}

// 	return buf.String()
// }

// CallFunction prepresents a function that can be called by the governor
type CallFunction func(...string) (string, error)
