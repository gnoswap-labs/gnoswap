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
func (p *ProposalMetadata) Title() string {
	return p.title
}

// Description returns the proposal description.
//
// Returns:
//   - string: proposal description
func (p *ProposalMetadata) Description() string {
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
	proposalType       ProposalType            // Type of proposal (Text, CommunityPoolSpend, ParameterChange)
	communityPoolSpend *CommunityPoolSpendInfo // Data for community pool spending proposals
	execution          *ExecutionInfo          // Data for parameter change proposals
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
	return p.communityPoolSpend
}

// Execution returns the execution information for parameter changes.
//
// Returns:
//   - *ExecutionInfo: parameter change execution details
func (p *ProposalData) Execution() *ExecutionInfo {
	return p.execution
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
	return &ProposalData{
		proposalType:       proposalType,
		communityPoolSpend: communityPoolSpend,
		execution:          execution,
	}
}

// CommunityPoolSpendInfo contains information for community pool spending proposals.
type CommunityPoolSpendInfo struct {
	to        address // Recipient address for token transfer
	tokenPath string  // Path of the token to transfer
	amount    int64   // Amount of tokens to transfer
}

// NewCommunityPoolSpendInfo creates community-pool spend data.
//
// Parameters:
//   - to: Recipient address that receives the community-pool transfer.
//   - tokenPath: Registered token path of the asset to transfer.
//   - amount: Transfer amount in the token's smallest unit.
//
// Returns:
//   - *CommunityPoolSpendInfo: spend data containing the recipient, token path, and amount.
func NewCommunityPoolSpendInfo(to address, tokenPath string, amount int64) *CommunityPoolSpendInfo {
	return &CommunityPoolSpendInfo{
		to:        to,
		tokenPath: tokenPath,
		amount:    amount,
	}
}

/* Getter methods */
// Returns:
//   - address: recipient address configured for the community-pool spend.
//
func (i *CommunityPoolSpendInfo) To() address { return i.to }

// Returns:
//   - string: registered token path configured for the community-pool spend.
func (i *CommunityPoolSpendInfo) TokenPath() string { return i.tokenPath }

// Returns:
//   - int64: transfer amount in the token's smallest unit.
func (i *CommunityPoolSpendInfo) Amount() int64 { return i.amount }

// ExecutionInfo contains information for parameter change execution.
// Messages are encoded strings that specify function calls and parameters.
type ExecutionInfo struct {
	num  int64    // Number of parameter changes to execute
	msgs []string // Execution messages separated by messageSeparator (*GOV*)
}

// NewExecutionInfo creates execution data for a parameter-change proposal.
//
// Parameters:
//   - num: Number of encoded parameter-change messages to execute.
//   - msgs: Encoded parameter-change messages, one message per execution.
//
// Returns:
//   - *ExecutionInfo: execution data containing the declared count and messages.
func NewExecutionInfo(num int64, msgs []string) *ExecutionInfo {
	return &ExecutionInfo{
		num:  num,
		msgs: msgs,
	}
}

/* Getter methods */
// Returns:
//   - int64: declared number of parameter-change messages.
//
func (i *ExecutionInfo) Num() int64 { return i.num }

// Returns:
//   - []string: encoded parameter-change messages in execution order.
func (i *ExecutionInfo) Msgs() []string { return i.msgs }

// ParameterChangeInfo represents a single parameter change to be executed.
type ParameterChangeInfo struct {
	pkgPath  string   // Package path of the target contract
	function string   // Function name to call
	params   []string // Parameters to pass to the function
}

// NewParameterChangeInfo creates one encoded parameter-change target description.
//
// Parameters:
//   - pkgPath: Package path containing the parameter-change handler.
//   - function: Handler function name to invoke.
//   - params: String arguments passed to the handler in order.
//
// Returns:
//   - ParameterChangeInfo: parameter-change target and its encoded arguments.
func NewParameterChangeInfo(pkgPath string, function string, params []string) ParameterChangeInfo {
	return ParameterChangeInfo{
		pkgPath:  pkgPath,
		function: function,
		params:   params,
	}
}

/* Getter methods */
// Returns:
//   - string: package path of the parameter-change handler.
//
func (i *ParameterChangeInfo) PkgPath() string { return i.pkgPath }

// Returns:
//   - string: function name of the parameter-change handler.
func (i *ParameterChangeInfo) Function() string { return i.function }

// Returns:
//   - []string: encoded arguments passed to the parameter-change handler.
func (i *ParameterChangeInfo) Params() []string { return i.params }

// Clone creates a deep copy of the ProposalMetadata.
// Returns:
//   - *ProposalMetadata: independent metadata copy, or nil when the receiver is nil.
func (p *ProposalMetadata) Clone() *ProposalMetadata {
	if p == nil {
		return nil
	}

	return &ProposalMetadata{
		title:       p.title,
		description: p.description,
	}
}

// Clone creates a deep copy of the CommunityPoolSpendInfo.
// Returns:
//   - *CommunityPoolSpendInfo: independent spend-data copy, or nil when the receiver is nil.
func (i *CommunityPoolSpendInfo) Clone() *CommunityPoolSpendInfo {
	if i == nil {
		return nil
	}

	return &CommunityPoolSpendInfo{
		to:        i.to,
		tokenPath: i.tokenPath,
		amount:    i.amount,
	}
}

// Clone creates a deep copy of the ExecutionInfo.
// Returns:
//   - *ExecutionInfo: independent execution-data copy including a copied message slice, or nil when the receiver is nil.
func (i *ExecutionInfo) Clone() *ExecutionInfo {
	if i == nil {
		return nil
	}

	clonedMsgs := make([]string, len(i.msgs))
	copy(clonedMsgs, i.msgs)

	return &ExecutionInfo{
		num:  i.num,
		msgs: clonedMsgs,
	}
}

// Clone creates a deep copy of the ProposalData.
// Returns:
//   - *ProposalData: independent proposal-data copy with cloned nested values, or nil when the receiver is nil.
func (p *ProposalData) Clone() *ProposalData {
	if p == nil {
		return nil
	}

	return &ProposalData{
		proposalType:       p.proposalType,
		communityPoolSpend: p.communityPoolSpend.Clone(),
		execution:          p.execution.Clone(),
	}
}
