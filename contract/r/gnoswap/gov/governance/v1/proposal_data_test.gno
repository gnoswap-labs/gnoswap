package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/governance"
)

// TestProposalMetadata_Validation tests metadata validation
func TestProposalMetadata_Validation(t *testing.T) {
	tests := []struct {
		name          string
		title         string
		description   string
		expectedError bool
	}{
		{
			name:          "Success - Valid metadata",
			title:         "Valid Title",
			description:   "Valid description",
			expectedError: false,
		},
		{
			name:          "Failure - Empty title",
			title:         "",
			description:   "Valid description",
			expectedError: true,
		},
		{
			name:          "Failure - Empty description",
			title:         "Valid Title",
			description:   "",
			expectedError: true,
		},
		{
			name:          "Failure - Title too long",
			title:         string(make([]byte, maxTitleLength+1)),
			description:   "Valid description",
			expectedError: true,
		},
		{
			name:          "Failure - Description too long",
			title:         "Valid Title",
			description:   string(make([]byte, maxDescriptionLength+1)),
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			metadata := governance.NewProposalMetadata(tc.title, tc.description)

			// when
			err := NewProposalMetadataResolver(metadata).Validate()

			// then
			if tc.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, metadata.Title(), tc.title)
				uassert.Equal(t, metadata.Description(), tc.description)
			}
		})
	}
}

// TestProposalData_Validation tests proposal data validation
func TestProposalData_Validation(t *testing.T) {
	validTokenPath := "gno.land/r/gnoswap/gns"
	tests := []struct {
		name                 string
		proposalType         governance.ProposalType
		spendInfo            *governance.CommunityPoolSpendInfo
		execution            *governance.ExecutionInfo
		expectedError        bool
		expectedErrorMessage string
	}{
		{
			name:          "Success - Valid Text proposal",
			proposalType:  governance.Text,
			expectedError: false,
		},
		{
			name:          "Success - Valid CommunityPoolSpend proposal",
			proposalType:  governance.CommunityPoolSpend,
			spendInfo:     governance.NewCommunityPoolSpendInfo(testutils.TestAddress("g1recipient"), validTokenPath, 1000),
			expectedError: false,
		},
		{
			name:          "Success - Valid ParameterChange proposal",
			proposalType:  governance.ParameterChange,
			execution:     governance.NewExecutionInfo(1, []string{"pkg1*EXE*func1*EXE*param1,param2"}),
			expectedError: false,
		},
		{
			name:                 "Failure - CommunityPoolSpend with invalid address",
			proposalType:         governance.CommunityPoolSpend,
			spendInfo:            governance.NewCommunityPoolSpendInfo(address(""), validTokenPath, 1000),
			expectedError:        true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-002] invalid input || to is invalid address",
		},
		{
			name:                 "Failure - CommunityPoolSpend with empty tokenPath",
			proposalType:         governance.CommunityPoolSpend,
			spendInfo:            governance.NewCommunityPoolSpendInfo(testutils.TestAddress("g1recipient"), "", 1000),
			expectedError:        true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-002] invalid input || tokenPath is empty",
		},
		{
			name:                 "Failure - CommunityPoolSpend with zero amount",
			proposalType:         governance.CommunityPoolSpend,
			spendInfo:            governance.NewCommunityPoolSpendInfo(testutils.TestAddress("g1recipient"), validTokenPath, 0),
			expectedError:        true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-002] invalid input || amount is not positive",
		},
		{
			name:                 "Failure - CommunityPoolSpend with negative amount",
			proposalType:         governance.CommunityPoolSpend,
			spendInfo:            governance.NewCommunityPoolSpendInfo(testutils.TestAddress("g1recipient"), validTokenPath, -100),
			expectedError:        true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-002] invalid input || amount is not positive",
		},
		{
			name:                 "Failure - Invalid ParameterChange proposal",
			proposalType:         governance.ParameterChange,
			execution:            governance.NewExecutionInfo(0, []string{}),
			expectedError:        true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-002] invalid input || numToExecute is less than or equal to 0",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			data := governance.NewProposalData(tc.proposalType, tc.spendInfo, tc.execution)

			// when
			err := NewProposalDataResolver(data).Validate()

			// then
			if tc.expectedError {
				uassert.Error(t, err)
				uassert.Equal(t, err.Error(), tc.expectedErrorMessage)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, data.ProposalType().String(), tc.proposalType.String())

				if tc.proposalType == governance.CommunityPoolSpend {
					uassert.Equal(t, data.CommunityPoolSpend().To(), tc.spendInfo.To())
					uassert.Equal(t, data.CommunityPoolSpend().TokenPath(), tc.spendInfo.TokenPath())
					uassert.Equal(t, data.CommunityPoolSpend().Amount(), tc.spendInfo.Amount())
				}

				if tc.proposalType == governance.ParameterChange {
					uassert.Equal(t, data.Execution().Num(), tc.execution.Num())
					for i := int64(0); i < data.Execution().Num(); i++ {
						uassert.Equal(t, data.Execution().Msgs()[i], tc.execution.Msgs()[i])
					}
				}
			}
		})
	}
}

// TestParameterChangeInfo tests parameter change info functionality
func TestParameterChangeInfo_Parsing(t *testing.T) {
	tests := []struct {
		name          string
		num           int64
		msgs          []string
		expectedInfos []governance.ParameterChangeInfo
	}{
		{
			name: "Success - Valid parameter changes",
			num:  2,
			msgs: []string{
				"pkg1*EXE*func1*EXE*param1,param2",
				"pkg2*EXE*func2*EXE*param3,param4",
			},
			expectedInfos: []governance.ParameterChangeInfo{
				governance.NewParameterChangeInfo("pkg1", "func1", []string{"param1", "param2"}),
				governance.NewParameterChangeInfo("pkg2", "func2", []string{"param3", "param4"}),
			},
		},
		{
			name:          "Success - Empty parameter changes",
			num:           0,
			msgs:          []string{},
			expectedInfos: []governance.ParameterChangeInfo{},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			info := governance.NewExecutionInfo(tc.num, tc.msgs)

			// when
			infos := NewProposalDataResolver(governance.NewProposalData(governance.ParameterChange, nil, info)).ParameterChangesInfos()

			// then
			uassert.Equal(t, len(infos), len(tc.expectedInfos))
			for i, expectedInfo := range tc.expectedInfos {
				uassert.Equal(t, infos[i].PkgPath(), expectedInfo.PkgPath())
				uassert.Equal(t, infos[i].Function(), expectedInfo.Function())
				uassert.Equal(t, len(infos[i].Params()), len(expectedInfo.Params()))
			}
		})
	}
}

// TestMakeExecuteMessage tests message creation
func TestMakeExecuteMessage(t *testing.T) {
	tests := []struct {
		name     string
		pkgPath  string
		function string
		params   []string
		expected string
	}{
		{
			name:     "Create message with no params",
			pkgPath:  "test/pkg",
			function: "testFunc",
			params:   []string{},
			expected: "test/pkg*EXE*testFunc*EXE*",
		},
		{
			name:     "Create message with params",
			pkgPath:  "test/pkg",
			function: "testFunc",
			params:   []string{"param1", "param2"},
			expected: "test/pkg*EXE*testFunc*EXE*param1,param2",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := makeExecuteMessage(tc.pkgPath, tc.function, tc.params)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}
