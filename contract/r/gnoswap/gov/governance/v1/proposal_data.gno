package v1

import (
	"strings"

	"gno.land/r/gnoswap/gov/governance"
)

type ProposalMetadataResolver struct {
	*governance.ProposalMetadata
}

func NewProposalMetadataResolver(metadata *governance.ProposalMetadata) *ProposalMetadataResolver {
	return &ProposalMetadataResolver{
		ProposalMetadata: metadata,
	}
}

// Validate performs comprehensive validation of the proposal metadata.
// Checks title and description length and content requirements.
//
// Returns:
//   - error: validation error if metadata is invalid
func (r *ProposalMetadataResolver) Validate() error {
	// Validate title meets requirements
	if err := r.validateTitle(r.Title()); err != nil {
		return err
	}

	// Validate description meets requirements
	if err := r.validateDescription(r.Description()); err != nil {
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
func (r *ProposalMetadataResolver) validateTitle(title string) error {
	// Title cannot be empty
	if title == "" {
		return makeErrorWithDetails(errInvalidInput, "title is empty")
	}

	// Title cannot exceed maximum length
	if len(title) > maxTitleLength {
		return makeErrorWithDetails(
			errInvalidInput,
			"title is too long, max length is 255 characters",
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
func (r *ProposalMetadataResolver) validateDescription(description string) error {
	// Description cannot be empty
	if description == "" {
		return makeErrorWithDetails(
			errInvalidInput,
			"description is empty",
		)
	}

	// Description cannot exceed maximum length
	if len(description) > maxDescriptionLength {
		return makeErrorWithDetails(
			errInvalidInput,
			"description is too long, max length is 10,000 characters",
		)
	}

	return nil
}

// ProposalDataResolver handles business logic for proposal data.
type ProposalDataResolver struct {
	*governance.ProposalData
}

func NewProposalDataResolver(proposalData *governance.ProposalData) *ProposalDataResolver {
	return &ProposalDataResolver{
		ProposalData: proposalData,
	}
}

// Validate performs type-specific validation of the proposal data.
// Different proposal types have different validation requirements.
//
// Returns:
//   - error: validation error if data is invalid
func (r *ProposalDataResolver) Validate() error {
	switch r.ProposalType() {
	case governance.Text:
		return r.validateText()
	case governance.CommunityPoolSpend:
		return r.validateCommunityPoolSpend()
	case governance.ParameterChange:
		return r.validateParameterChange()
	}
	return nil
}

// validateText validates text proposal data.
// Text proposals have no additional validation requirements.
//
// Returns:
//   - error: always nil for text proposals
func (r *ProposalDataResolver) validateText() error {
	return nil
}

// validateCommunityPoolSpend validates community pool spend proposal data.
// Checks recipient address, token path, and amount validity.
//
// Returns:
//   - error: validation error if community pool spend data is invalid
func (r *ProposalDataResolver) validateCommunityPoolSpend() error {
	// Validate recipient address
	communityPoolSpend := r.ProposalData.CommunityPoolSpend()
	if communityPoolSpend == nil {
		return makeErrorWithDetails(
			errInvalidInput, "community pool spend info is missing")
	}

	if !communityPoolSpend.To().IsValid() {
		return makeErrorWithDetails(
			errInvalidInput, "to is invalid address")
	}

	// Validate amount is greater than 0
	if communityPoolSpend.Amount() <= 0 {
		return makeErrorWithDetails(
			errInvalidInput, "amount is not positive")
	}

	return nil
}

// validateParameterChange validates parameter change proposal data.
// Performs basic structural validation of the parameter change data.
// Note: Handler existence validation is performed separately by validateExecutions
// during proposal creation to ensure the target functions are registered.
//
// Returns:
//   - error: validation error if parameter change data structure is invalid
func (r *ProposalDataResolver) validateParameterChange() error {
	execution := r.Execution()
	if execution == nil {
		return makeErrorWithDetails(
			errInvalidInput,
			"execution info is missing",
		)
	}
	num := execution.Num()
	msgs := execution.Msgs()

	// Validate execution count is positive
	if num <= 0 {
		return makeErrorWithDetails(
			errInvalidInput,
			"numToExecute is less than or equal to 0",
		)
	}

	// Validate execution messages are provided
	if len(msgs) == 0 {
		return makeErrorWithDetails(
			errInvalidInput,
			"executions is empty",
		)
	}

	// Validate execution count matches message count
	if len(msgs) != int(num) {
		return makeErrorWithDetails(errInvalidInput, "executions is not equal to numToExecute")
	}

	// Validate execution count doesn't exceed maximum
	if num > maxNumberOfExecution {
		return makeErrorWithDetails(errInvalidInput, "numToExecute is greater than 10")
	}

	// Validate parameter change message format
	parameterChangesInfos := r.ParameterChangesInfos()
	if len(parameterChangesInfos) != int(num) {
		return makeErrorWithDetails(errInvalidInput, "invalid parameter change info")
	}

	return nil
}

// ParameterChangesInfos parses the execution messages and returns structured parameter change information.
// Each message is expected to be in format: pkgPath*EXE*function*EXE*params
//
// Returns:
//   - []ParameterChangeInfo: slice of parsed parameter change information
func (r *ProposalDataResolver) ParameterChangesInfos() []governance.ParameterChangeInfo {
	infos := make([]governance.ParameterChangeInfo, 0)

	// Return empty slice if no executions
	execution := r.Execution()
	if execution == nil || execution.Num() <= 0 {
		return infos
	}

	// Parse each execution message
	for _, msg := range execution.Msgs() {
		// Split message into components: pkgPath, function, params
		params := strings.Split(msg, parameterSeparator)
		if len(params) != 3 {
			// validation rejects mismatched counts upstream.
			continue
		}

		pkgPath := params[0]
		function := params[1]
		param := strings.Split(params[2], ",")

		// Create parameter change info structure
		info := governance.NewParameterChangeInfo(pkgPath, function, param)
		infos = append(infos, info)
	}

	return infos
}

// NewProposalTextData creates proposal data for a text proposal.
// Text proposals have no additional data requirements.
//
// Returns:
//   - *ProposalData: proposal data configured for text proposal
func NewProposalTextData() *governance.ProposalData {
	return governance.NewProposalData(governance.Text, nil, nil)
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
	to address,
	amount int64,
	communityPoolPackagePath string,
) *governance.ProposalData {
	// Create execution message for the token transfer
	executionInfoMessage := makeExecuteMessage(
		communityPoolPackagePath,
		"TransferToken",
		[]string{tokenPath, to.String(), formatInt(amount)},
	)

	return governance.NewProposalData(
		governance.CommunityPoolSpend,
		governance.NewCommunityPoolSpendInfo(to, tokenPath, amount),
		governance.NewExecutionInfo(1, []string{executionInfoMessage}),
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
func NewProposalExecutionData(numToExecute int64, executions string) *governance.ProposalData {
	// Split execution string into individual messages
	msgs := strings.Split(executions, messageSeparator)

	return governance.NewProposalData(
		governance.ParameterChange,
		nil,
		governance.NewExecutionInfo(numToExecute, msgs),
	)
}

// makeExecuteMessage creates a message to execute a function.
// Message format: <pkgPath>*EXE*<function>*EXE*<params>.
func makeExecuteMessage(pkgPath, function string, params []string) string {
	messageParams := []string{
		pkgPath,
		function,
		strings.Join(params, ","),
	}
	return strings.Join(messageParams, parameterSeparator)
}
