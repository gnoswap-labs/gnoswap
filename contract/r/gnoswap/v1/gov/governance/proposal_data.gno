package governance

import (
	"std"
	"strings"

	"gno.land/p/nt/ufmt"
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

// Validate performs comprehensive validation of the proposal metadata.
// Checks title and description length and content requirements.
//
// Returns:
//   - error: validation error if metadata is invalid
func (p *ProposalMetadata) Validate() error {
	// Validate title meets requirements
	if err := p.validateTitle(p.title); err != nil {
		return err
	}

	// Validate description meets requirements
	if err := p.validateDescription(p.description); err != nil {
		return err
	}

	return nil
}

// validateTitle checks if the proposal title meets length and content requirements.
//
// Parameters:
//   - title: title string to validate
//
// Returns:
//   - error: validation error if title is invalid
func (p *ProposalMetadata) validateTitle(title string) error {
	// Title cannot be empty
	if title == "" {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("title is empty"),
		)
	}

	// Title cannot exceed maximum length
	if len(title) > maxTitleLength {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("title is too long, max length is %d", maxTitleLength),
		)
	}

	return nil
}

// validateDescription checks if the proposal description meets length and content requirements.
//
// Parameters:
//   - description: description string to validate
//
// Returns:
//   - error: validation error if description is invalid
func (p *ProposalMetadata) validateDescription(description string) error {
	// Description cannot be empty
	if description == "" {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("description is empty"),
		)
	}

	// Description cannot exceed maximum length
	if len(description) > maxDescriptionLength {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("description is too long, max length is %d", maxDescriptionLength),
		)
	}

	return nil
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
	proposalType       ProposalType           // Type of proposal (Text, CommunityPoolSpend, ParameterChange)
	communityPoolSpend CommunityPoolSpendInfo // Data for community pool spending proposals
	execution          ExecutionInfo          // Data for parameter change proposals
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
//   - CommunityPoolSpendInfo: community pool spending details
func (p *ProposalData) CommunityPoolSpend() CommunityPoolSpendInfo {
	return p.communityPoolSpend
}

// Execution returns the execution information for parameter changes.
//
// Returns:
//   - ExecutionInfo: parameter change execution details
func (p *ProposalData) Execution() ExecutionInfo {
	return p.execution
}

// Validate performs type-specific validation of the proposal data.
// Different proposal types have different validation requirements.
//
// Returns:
//   - error: validation error if data is invalid
func (p *ProposalData) Validate() error {
	// Validate based on proposal type
	if p.proposalType == Text {
		return p.validateText()
	}

	if p.proposalType == CommunityPoolSpend {
		return p.validateCommunityPoolSpend()
	}

	if p.proposalType == ParameterChange {
		return p.validateParameterChange()
	}

	return nil
}

// validateText validates text proposal data.
// Text proposals have no additional validation requirements.
//
// Returns:
//   - error: always nil for text proposals
func (p *ProposalData) validateText() error {
	return nil
}

// validateCommunityPoolSpend validates community pool spend proposal data.
// Checks recipient address, token path, and amount validity.
//
// Returns:
//   - error: validation error if community pool spend data is invalid
func (p *ProposalData) validateCommunityPoolSpend() error {
	// Validate recipient address
	if !p.communityPoolSpend.to.IsValid() {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("to is invalid address"),
		)
	}

	// Validate token path is provided
	if p.communityPoolSpend.tokenPath == "" {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("tokenPath is empty"),
		)
	}

	// Validate amount is positive
	if p.communityPoolSpend.amount == 0 {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("amount is 0"),
		)
	}

	return nil
}

// validateParameterChange validates parameter change proposal data.
// Checks execution count, message format, and parameter validity.
//
// Returns:
//   - error: validation error if parameter change data is invalid
func (p *ProposalData) validateParameterChange() error {
	// Validate execution count is positive
	if p.execution.num <= 0 {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("numToExecute is less than or equal to 0"),
		)
	}

	// Validate execution messages are provided
	if len(p.execution.msgs) == 0 {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("executions is empty"),
		)
	}

	// Validate execution count matches message count
	if len(p.execution.msgs) != int(p.execution.num) {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("executions is not equal to numToExecute"),
		)
	}

	// Validate execution count doesn't exceed maximum
	if p.execution.num > maxNumberOfExecution {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("numToExecute is greater than %d", maxNumberOfExecution),
		)
	}

	// Validate parameter change message format
	parameterChangesInfos := p.execution.ParameterChangesInfos()
	if len(parameterChangesInfos) != int(p.execution.num) {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("invalid parameter change info"),
		)
	}

	return nil
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
func NewProposalData(proposalType ProposalType, communityPoolSpend CommunityPoolSpendInfo, execution ExecutionInfo) *ProposalData {
	return &ProposalData{
		proposalType:       proposalType,
		communityPoolSpend: communityPoolSpend,
		execution:          execution,
	}
}

// NewProposalTextData creates proposal data for a text proposal.
// Text proposals have no additional data requirements.
//
// Returns:
//   - *ProposalData: proposal data configured for text proposal
func NewProposalTextData() *ProposalData {
	return NewProposalData(
		Text,
		CommunityPoolSpendInfo{},
		ExecutionInfo{},
	)
}

// NewProposalCommunityPoolSpendData creates proposal data for a community pool spend proposal.
// Automatically generates the execution message for the token transfer.
//
// Parameters:
//   - tokenPath: path of the token to transfer
//   - to: recipient address for the transfer
//   - amount: amount of tokens to transfer
//   - communityPoolPackagePath: package path of the community pool contract
//
// Returns:
//   - *ProposalData: proposal data configured for community pool spending
func NewProposalCommunityPoolSpendData(
	tokenPath string,
	to std.Address,
	amount int64,
	communityPoolPackagePath string,
) *ProposalData {
	// Create execution message for the token transfer
	executionInfoMessage := makeExecuteMessage(
		communityPoolPackagePath,
		"TransferToken",
		[]string{tokenPath, to.String(), ufmt.Sprintf("%d", amount)},
	)

	return NewProposalData(
		CommunityPoolSpend,
		CommunityPoolSpendInfo{to, tokenPath, amount},
		ExecutionInfo{
			num:  1,
			msgs: []string{executionInfoMessage},
		},
	)
}

// NewProposalExecutionData creates proposal data for a parameter change proposal.
// Parses the execution string to create the execution structure.
//
// Parameters:
//   - numToExecute: number of parameter changes to execute
//   - executions: encoded execution string with parameter changes
//
// Returns:
//   - *ProposalData: proposal data configured for parameter changes
func NewProposalExecutionData(numToExecute int64, executions string) *ProposalData {
	// Split execution string into individual messages
	msgs := strings.Split(executions, messageSeparator)

	return NewProposalData(
		ParameterChange,
		CommunityPoolSpendInfo{},
		ExecutionInfo{numToExecute, msgs},
	)
}

// CommunityPoolSpendInfo contains information for community pool spending proposals.
type CommunityPoolSpendInfo struct {
	to        std.Address // Recipient address for token transfer
	tokenPath string      // Path of the token to transfer
	amount    int64       // Amount of tokens to transfer
}

// ExecutionInfo contains information for parameter change execution.
// Messages are encoded strings that specify function calls and parameters.
type ExecutionInfo struct {
	num  int64    // Number of parameter changes to execute
	msgs []string // Execution messages separated by messageSeparator (*GOV*)
}

// ParameterChangesInfos parses the execution messages and returns structured parameter change information.
// Each message is expected to be in format: pkgPath*EXE*function*EXE*params
//
// Returns:
//   - []ParameterChangeInfo: slice of parsed parameter change information
func (e *ExecutionInfo) ParameterChangesInfos() []ParameterChangeInfo {
	// Return empty slice if no executions
	if e.num <= 0 {
		return []ParameterChangeInfo{}
	}

	infos := make([]ParameterChangeInfo, 0)

	// Parse each execution message
	for _, msg := range e.msgs {
		// Split message into components: pkgPath, function, params
		params := strings.Split(msg, parameterSeparator)
		if len(params) != 3 {
			continue // Skip malformed messages
		}

		pkgPath := params[0]
		function := params[1]
		executionParams := strings.Split(params[2], ",")

		// Create parameter change info structure
		infos = append(infos, ParameterChangeInfo{
			pkgPath:  pkgPath,
			function: function,
			params:   executionParams,
		})
	}

	return infos
}

// ParameterChangeInfo represents a single parameter change to be executed.
type ParameterChangeInfo struct {
	pkgPath  string   // Package path of the target contract
	function string   // Function name to call
	params   []string // Parameters to pass to the function
}
