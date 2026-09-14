package governance

import (
	"strings"

	"gno.land/p/gnoswap/utils"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/gov/governance"
)

type ProposalMetadataResolver struct {
	metadata governance.ProposalMetadata
}

func MakeProposalMetadataResolver(metadata governance.ProposalMetadata) ProposalMetadataResolver {
	return ProposalMetadataResolver{metadata: metadata}
}

func (r ProposalMetadataResolver) Value() governance.ProposalMetadata {
	return r.metadata
}

func (r ProposalMetadataResolver) Validate() error {
	if err := r.validateTitle(r.metadata.Title()); err != nil {
		return err
	}
	return r.validateDescription(r.metadata.Description())
}

func (r ProposalMetadataResolver) validateTitle(title string) error {
	if title == "" {
		return makeErrorWithDetails(errInvalidInput, "title is empty")
	}
	if len(title) > maxTitleLength {
		return makeErrorWithDetails(
			errInvalidInput,
			"title is too long, max length is 255 characters",
		)
	}
	return nil
}

func (r ProposalMetadataResolver) validateDescription(description string) error {
	if description == "" {
		return makeErrorWithDetails(errInvalidInput, "description is empty")
	}
	if len(description) > maxDescriptionLength {
		return makeErrorWithDetails(
			errInvalidInput,
			"description is too long, max length is 10,000 characters",
		)
	}
	return nil
}

type ProposalDataResolver struct {
	data governance.ProposalData
}

func MakeProposalDataResolver(data governance.ProposalData) ProposalDataResolver {
	return ProposalDataResolver{data: data}
}

func (r ProposalDataResolver) Value() governance.ProposalData {
	return r.data
}

func (r ProposalDataResolver) Validate() error {
	switch r.data.ProposalType() {
	case governance.Text:
		return r.validateText()
	case governance.CommunityPoolSpend:
		return r.validateCommunityPoolSpend()
	case governance.ParameterChange:
		return r.validateParameterChange()
	}
	return nil
}

func (r ProposalDataResolver) validateText() error {
	return nil
}

func (r ProposalDataResolver) validateCommunityPoolSpend() error {
	communityPoolSpend, ok := r.data.CommunityPoolSpend()
	if !ok {
		return makeErrorWithDetails(errInvalidInput, "community pool spend info is missing")
	}
	if !communityPoolSpend.To().IsValid() {
		return makeErrorWithDetails(errInvalidInput, "to is invalid address")
	}
	if communityPoolSpend.Amount() <= 0 {
		return makeErrorWithDetails(errInvalidInput, "amount is not positive")
	}
	return nil
}

func (r ProposalDataResolver) validateParameterChange() error {
	execution, ok := r.data.Execution()
	if !ok {
		return makeErrorWithDetails(errInvalidInput, "execution info is missing")
	}
	return validateExecutions(execution.Num(), execution.Msgs())
}

func (r ProposalDataResolver) ParameterChangesInfos() ([]governance.ParameterChangeInfo, error) {
	infos := make([]governance.ParameterChangeInfo, 0)
	execution, ok := r.data.Execution()
	if !ok || execution.Num() <= 0 {
		return infos, nil
	}

	for _, msg := range execution.Msgs() {
		pkgPath, function, params, partCount := parseExecutionMessage(msg)
		if partCount != 3 {
			return nil, makeErrorWithDetails(
				errInvalidMessageFormat,
				ufmt.Sprintf("malformed execution message: expected 3 parts (pkgPath, function, params), got %d", partCount),
			)
		}
		infos = append(infos, governance.MakeParameterChangeInfo(pkgPath, function, params))
	}
	return infos, nil
}

// DefaultProposalTextData creates data for a text proposal.
func DefaultProposalTextData() governance.ProposalData {
	return governance.MakeProposalData(
		governance.Text,
		governance.DefaultCommunityPoolSpendInfo(),
		governance.DefaultExecutionInfo(),
	)
}

func MakeProposalCommunityPoolSpendData(
	tokenPath string,
	to address,
	amount int64,
	communityPoolPackagePath string,
) governance.ProposalData {
	executionInfoMessage := makeExecuteMessage(
		communityPoolPackagePath,
		"TransferToken",
		[]string{tokenPath, to.String(), utils.FormatInt(amount)},
	)
	return governance.MakeProposalData(
		governance.CommunityPoolSpend,
		governance.MakeCommunityPoolSpendInfo(to, tokenPath, amount),
		governance.MakeExecutionInfo(1, []string{executionInfoMessage}),
	)
}

func MakeProposalExecutionData(numToExecute int64, executions string) governance.ProposalData {
	return governance.MakeProposalData(
		governance.ParameterChange,
		governance.DefaultCommunityPoolSpendInfo(),
		governance.MakeExecutionInfo(numToExecute, splitExecutionsRaw(executions)),
	)
}

func makeExecuteMessage(pkgPath, function string, params []string) string {
	messageParams := []string{pkgPath, function, strings.Join(params, ",")}
	return strings.Join(messageParams, parameterSeparator)
}
