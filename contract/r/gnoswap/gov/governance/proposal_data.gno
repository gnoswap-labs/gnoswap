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

// NewProposalMetadata creates a new proposal metadata instance with trimmed input.
//
// Parameters:
//   - title: proposal title
//   - description: proposal description
//
// Returns:
//   - *ProposalMetadata: new metadata instance with trimmed whitespace
func NewProposalMetadata(title string, description string) *ProposalMetadata {
	return &ProposalMetadata{
		title:       strings.TrimSpace(title),
		description: strings.TrimSpace(description),
	}
}

// ProposalData contains the type-specific data for a proposal.
// This structure holds different data depending on the proposal type.
type ProposalData struct {
	proposalType              ProposalType
	communityPoolSpend        CommunityPoolSpendInfo
	communityPoolSpendPresent bool
	execution                 ExecutionInfo
	executionPresent          bool
}

// ProposalType returns the type of this proposal.
//
// Returns:
//   - ProposalType: the proposal type
func (p *ProposalData) ProposalType() ProposalType {
	return p.proposalType
}

// CommunityPoolSpend returns the community pool spending information.
//
// Returns:
//   - *CommunityPoolSpendInfo: community pool spending details
func (p *ProposalData) CommunityPoolSpend() *CommunityPoolSpendInfo {
	if !p.communityPoolSpendPresent {
		return nil
	}
	return &p.communityPoolSpend
}

func (p *ProposalData) Execution() *ExecutionInfo {
	if !p.executionPresent {
		return nil
	}
	return &p.execution
}

// NewProposalData creates a new proposal data instance with the specified components.
//
// Parameters:
//   - proposalType: type of the proposal
//   - communityPoolSpend: community pool spending information
//   - execution: parameter change execution information
//
// Returns:
//   - *ProposalData: new proposal data instance
func NewProposalData(proposalType ProposalType, communityPoolSpend *CommunityPoolSpendInfo, execution *ExecutionInfo) *ProposalData {
	data := &ProposalData{
		proposalType:              proposalType,
		communityPoolSpendPresent: communityPoolSpend != nil,
		executionPresent:          execution != nil,
	}
	if communityPoolSpend != nil {
		data.communityPoolSpend = *communityPoolSpend
	}
	if execution != nil {
		data.execution = ExecutionInfo{num: execution.num, msgs: append([]string(nil), execution.msgs...)}
	}
	return data
}

// CommunityPoolSpendInfo contains information for community pool spending proposals.
type CommunityPoolSpendInfo struct {
	to        address // Recipient address for token transfer
	tokenPath string  // Path of the token to transfer
	amount    int64   // Amount of tokens to transfer
}

func NewCommunityPoolSpendInfo(to address, tokenPath string, amount int64) *CommunityPoolSpendInfo {
	return &CommunityPoolSpendInfo{
		to:        to,
		tokenPath: tokenPath,
		amount:    amount,
	}
}

/* Getter methods */
func (i *CommunityPoolSpendInfo) To() address       { return i.to }
func (i *CommunityPoolSpendInfo) TokenPath() string { return i.tokenPath }
func (i *CommunityPoolSpendInfo) Amount() int64     { return i.amount }

// ExecutionInfo contains information for parameter change execution.
// Messages are encoded strings that specify function calls and parameters.
type ExecutionInfo struct {
	num  int64    // Number of parameter changes to execute
	msgs []string // Execution messages separated by messageSeparator (*GOV*)
}

func NewExecutionInfo(num int64, msgs []string) *ExecutionInfo {
	return &ExecutionInfo{
		num:  num,
		msgs: msgs,
	}
}

/* Getter methods */
func (i *ExecutionInfo) Num() int64 { return i.num }

func (i *ExecutionInfo) Msgs() []string {
	return append([]string(nil), i.msgs...)
}

// ParameterChangeInfo represents a single parameter change to be executed.
type ParameterChangeInfo struct {
	pkgPath  string   // Package path of the target contract
	function string   // Function name to call
	params   []string // Parameters to pass to the function
}

func NewParameterChangeInfo(pkgPath string, function string, params []string) ParameterChangeInfo {
	return ParameterChangeInfo{
		pkgPath:  pkgPath,
		function: function,
		params:   params,
	}
}

/* Getter methods */
func (i *ParameterChangeInfo) PkgPath() string  { return i.pkgPath }
func (i *ParameterChangeInfo) Function() string { return i.function }
func (i *ParameterChangeInfo) Params() []string { return i.params }

func (i *CommunityPoolSpendInfo) Clone() *CommunityPoolSpendInfo {
	if i == nil {
		return nil
	}
	return &CommunityPoolSpendInfo{to: i.to, tokenPath: i.tokenPath, amount: i.amount}
}

func (i *ExecutionInfo) Clone() *ExecutionInfo {
	if i == nil {
		return nil
	}
	return &ExecutionInfo{num: i.num, msgs: append([]string(nil), i.msgs...)}
}
