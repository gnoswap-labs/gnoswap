package v1

import (
	"strings"

	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/gov/governance"
)

type ProposalMetadataResolver struct{}

func NewProposalMetadataResolver() *ProposalMetadataResolver {
	return &ProposalMetadataResolver{}
}

// Validate performs comprehensive validation of the proposal metadata.
// Checks title and description length and content requirements.
//
// Returns:
//   - error: validation error if metadata is invalid
func (r *ProposalMetadataResolver) Validate(metadata *governance.ProposalMetadata) error {
	// Validate title meets requirements
	if err := r.validateTitle(metadata.Title()); err != nil {
		return err
	}

	// Validate description meets requirements
	if err := r.validateDescription(metadata.Description()); err != nil {
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
func (r *ProposalMetadataResolver) validateDescription(description string) error {
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

// ProposalDataResolver handles business logic for proposal data.
type ProposalDataResolver struct{}

func NewProposalDataResolver() *ProposalDataResolver {
	return &ProposalDataResolver{}
}

// Validate performs type-specific validation of the proposal data.
// Different proposal types have different validation requirements.
//
// Returns:
//   - error: validation error if data is invalid
func (r *ProposalDataResolver) Validate(data *governance.ProposalData) error {
	switch data.ProposalType() {
	case governance.Text:
		return r.validateText(data)
	case governance.CommunityPoolSpend:
		return r.validateCommunityPoolSpend(data)
	case governance.ParameterChange:
		return r.validateParameterChange(data)
	}
	return nil
}

// validateText validates text proposal data.
// Text proposals have no additional validation requirements.
//
// Returns:
//   - error: always nil for text proposals
func (r *ProposalDataResolver) validateText(_ *governance.ProposalData) error {
	return nil
}

// validateCommunityPoolSpend validates community pool spend proposal data.
// Checks recipient address, token path, and amount validity.
//
// Returns:
//   - error: validation error if community pool spend data is invalid
func (r *ProposalDataResolver) validateCommunityPoolSpend(data *governance.ProposalData) error {
	// Validate recipient address
	communityPoolSpend := data.CommunityPoolSpend()
	if !communityPoolSpend.To().IsValid() {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("to is invalid address"),
		)
	}

	// Validate token path is provided
	if communityPoolSpend.TokenPath() == "" {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("tokenPath is empty"),
		)
	}

	// Validate amount is positive
	if communityPoolSpend.Amount() == 0 {
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
func (r *ProposalDataResolver) validateParameterChange(data *governance.ProposalData) error {
	execution := data.Execution()
	num := execution.Num()
	msgs := execution.Msgs()

	// Validate execution count is positive
	if num <= 0 {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("numToExecute is less than or equal to 0"),
		)
	}

	// Validate execution messages are provided
	if len(msgs) == 0 {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("executions is empty"),
		)
	}

	// Validate execution count matches message count
	if len(msgs) != int(num) {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("executions is not equal to numToExecute"),
		)
	}

	// Validate execution count doesn't exceed maximum
	if num > maxNumberOfExecution {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("numToExecute is greater than %d", maxNumberOfExecution),
		)
	}

	// Validate parameter change message format
	parameterChangesInfos := r.ParameterChangesInfos(execution)
	if len(parameterChangesInfos) != int(num) {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("invalid parameter change info"),
		)
	}

	return nil
}

// ParameterChangesInfos parses the execution messages and returns structured parameter change information.
// Each message is expected to be in format: pkgPath*EXE*function*EXE*params
//
// Returns:
//   - []ParameterChangeInfo: slice of parsed parameter change information
func (r *ProposalDataResolver) ParameterChangesInfos(execution *governance.ExecutionInfo) []governance.ParameterChangeInfo {
	infos := make([]governance.ParameterChangeInfo, 0)

	// Return empty slice if no executions
	if execution.Num() <= 0 {
		return infos
	}

	// Parse each execution message
	for _, msg := range execution.Msgs() {
		// Split message into components: pkgPath, function, params
		params := strings.Split(msg, parameterSeparator)
		if len(params) != 3 {
			continue // Skip malformed messages
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
	return governance.NewProposalData(
		governance.Text,
		governance.CommunityPoolSpendInfo{},
		governance.ExecutionInfo{},
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
	to address,
	amount int64,
	communityPoolPackagePath string,
) *governance.ProposalData {
	// Create execution message for the token transfer
	executionInfoMessage := makeExecuteMessage(
		communityPoolPackagePath,
		"TransferToken",
		[]string{tokenPath, to.String(), ufmt.Sprintf("%d", amount)},
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
		governance.NewCommunityPoolSpendInfo(address(""), "", 0),
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
