package governance

import (
	"strings"
)

// ProposalMetadata contains descriptive information about a proposal.
// This includes the title and description that are displayed to voters.
type ProposalMetadata struct {
	title       string // Proposal title (max 255 characters)
	description string // Detailed proposal description (max 10,000 characters)
}

// Title returns the proposal title.
//
// Returns:
//   - string: proposal title
func (p ProposalMetadata) Title() string {
	return p.title
}

// Description returns the proposal description.
//
// Returns:
//   - string: proposal description
func (p ProposalMetadata) Description() string {
	return p.description
}

// MakeProposalMetadata creates a new proposal metadata value with trimmed input.
//
// Parameters:
//   - title: proposal title
//   - description: proposal description
//
// Returns:
//   - ProposalMetadata: new metadata value with trimmed whitespace
func MakeProposalMetadata(title string, description string) ProposalMetadata {
	return ProposalMetadata{
		title:       strings.TrimSpace(title),
		description: strings.TrimSpace(description),
	}
}

// ProposalData contains the type-specific data for a proposal.
// The proposal type determines which payload is present.
type ProposalData struct {
	proposalType       ProposalType           // Type of proposal (Text, CommunityPoolSpend, ParameterChange)
	communityPoolSpend CommunityPoolSpendInfo // Data for community pool spending proposals
	execution          ExecutionInfo          // Data for parameter change proposals
}

// ProposalType returns the type of this proposal.
//
// Returns:
//   - ProposalType: the proposal type
func (p ProposalData) ProposalType() ProposalType {
	return p.proposalType
}

// CommunityPoolSpend returns the community pool spending information as a value.
// The boolean is true only for CommunityPoolSpend proposals; otherwise the zero
// value and false are returned.
//
// Returns:
//   - CommunityPoolSpendInfo: community pool spending details
//   - bool: whether community pool spending information is present
func (p ProposalData) CommunityPoolSpend() (CommunityPoolSpendInfo, bool) {
	if p.proposalType != CommunityPoolSpend {
		return DefaultCommunityPoolSpendInfo(), false
	}
	return p.communityPoolSpend, true
}

// Execution returns execution information for parameter changes and community
// pool spending proposals as a value. The boolean reports whether this payload
// is present for the proposal type.
//
// Returns:
//   - ExecutionInfo: execution details
//   - bool: whether execution information is present
func (p ProposalData) Execution() (ExecutionInfo, bool) {
	if p.proposalType != ParameterChange && p.proposalType != CommunityPoolSpend {
		return DefaultExecutionInfo(), false
	}
	return p.execution, true
}

// MakeProposalData creates a new proposal data value with the specified
// components.
//
// Parameters:
//   - proposalType: type of the proposal
//   - communityPoolSpend: community pool spending information
//   - execution: parameter change execution information
//
// Returns:
//   - ProposalData: new proposal data value. The proposal type determines
//     which type-specific payload is returned by its accessor.
func MakeProposalData(
	proposalType ProposalType,
	communityPoolSpend CommunityPoolSpendInfo,
	execution ExecutionInfo,
) ProposalData {
	return ProposalData{
		proposalType:       proposalType,
		communityPoolSpend: communityPoolSpend,
		execution:          execution,
	}
}

// WithCommunityPoolSpend returns a copy with updated community pool spend
// information.
func (p ProposalData) WithCommunityPoolSpend(communityPoolSpend CommunityPoolSpendInfo) ProposalData {
	p.communityPoolSpend = communityPoolSpend
	return p
}

// WithExecution returns a copy with updated execution information.
func (p ProposalData) WithExecution(execution ExecutionInfo) ProposalData {
	p.execution = execution
	return p
}

// CommunityPoolSpendInfo contains information for community pool spending proposals.
type CommunityPoolSpendInfo struct {
	to        address // Recipient address for token transfer
	tokenPath string  // Path of the token to transfer
	amount    int64   // Amount of tokens to transfer
}

// MakeCommunityPoolSpendInfo creates a community pool spend information value.
//
// Parameters:
//   - to: recipient address for the token transfer
//   - tokenPath: path of the token to transfer
//   - amount: amount of tokens to transfer
//
// Returns:
//   - CommunityPoolSpendInfo: new community pool spend information value
func MakeCommunityPoolSpendInfo(to address, tokenPath string, amount int64) CommunityPoolSpendInfo {
	return CommunityPoolSpendInfo{
		to:        to,
		tokenPath: tokenPath,
		amount:    amount,
	}
}

// DefaultCommunityPoolSpendInfo returns an empty community pool spend
// information value for unused proposal payloads.
func DefaultCommunityPoolSpendInfo() CommunityPoolSpendInfo {
	return CommunityPoolSpendInfo{}
}

/* Getter methods */
func (i CommunityPoolSpendInfo) To() address       { return i.to }
func (i CommunityPoolSpendInfo) TokenPath() string { return i.tokenPath }
func (i CommunityPoolSpendInfo) Amount() int64     { return i.amount }

// ExecutionInfo contains information for parameter change execution.
// Messages are encoded strings that specify function calls and parameters.
type ExecutionInfo struct {
	num  int64    // Number of parameter changes to execute
	msgs []string // Execution messages separated by messageSeparator (*GOV*)
}

// MakeExecutionInfo creates an execution information value. The input message
// slice is copied so the value owns its storage.
func MakeExecutionInfo(num int64, msgs []string) ExecutionInfo {
	return ExecutionInfo{
		num:  num,
		msgs: append([]string(nil), msgs...),
	}
}

// DefaultExecutionInfo returns an empty execution information value for
// unused proposal payloads.
func DefaultExecutionInfo() ExecutionInfo {
	return ExecutionInfo{}
}

/* Getter methods */
func (i ExecutionInfo) Num() int64 { return i.num }

func (i ExecutionInfo) Msgs() []string {
	return append([]string(nil), i.msgs...)
}

// ParameterChangeInfo represents a single parameter change to be executed.
type ParameterChangeInfo struct {
	pkgPath  string   // Package path of the target contract
	function string   // Function name to call
	params   []string // Parameters to pass to the function
}

func MakeParameterChangeInfo(pkgPath string, function string, params []string) ParameterChangeInfo {
	return ParameterChangeInfo{
		pkgPath:  pkgPath,
		function: function,
		params:   params,
	}
}

/* Getter methods */
func (i ParameterChangeInfo) PkgPath() string  { return i.pkgPath }
func (i ParameterChangeInfo) Function() string { return i.function }
func (i ParameterChangeInfo) Params() []string { return i.params }
