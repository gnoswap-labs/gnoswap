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
			err := metadata.Validate()

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
	tests := []struct {
		name          string
		proposalType  governance.ProposalType
		spendInfo     governance.CommunityPoolSpendInfo
		execution     governance.ExecutionInfo
		expectedError bool
	}{
		{
			name:          "Success - Valid Text proposal",
			proposalType:  governance.Text,
			expectedError: false,
		},
		{
			name:         "Success - Valid CommunityPoolSpend proposal",
			proposalType: governance.CommunityPoolSpend,
			spendInfo: governance.NewCommunityPoolSpendInfo(testutils.TestAddress("g1recipient"), "test/token", 1000),
			expectedError: false,
		},
		{
			name:         "Success - Valid ParameterChange proposal",
			proposalType: governance.ParameterChange,
			execution: governance.NewExecutionInfo(1, []string{"pkg1*EXE*func1*EXE*param1,param2"}),
			expectedError: false,
		},
		{
			name:         "Failure - Invalid CommunityPoolSpend proposal",
			proposalType: governance.CommunityPoolSpend,
			spendInfo: governance.NewCommunityPoolSpendInfo(address(""), "", 0),
			expectedError: true,
		},
		{
			name:         "Failure - Invalid ParameterChange proposal",
			proposalType: ParameterChange,
			execution: governance.NewExecutionInfo(0, []string{}),
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			data := NewProposalData(tc.proposalType, tc.spendInfo, tc.execution)

			// when
			err := data.Validate()

			// then
			if tc.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, data.ProposalType().String(), tc.proposalType.String())

				if tc.proposalType == CommunityPoolSpend {
					uassert.Equal(t, data.CommunityPoolSpend().to, tc.spendInfo.to)
					uassert.Equal(t, data.CommunityPoolSpend().tokenPath, tc.spendInfo.tokenPath)
					uassert.Equal(t, data.CommunityPoolSpend().amount, tc.spendInfo.amount)
				}

				if tc.proposalType == ParameterChange {
					uassert.Equal(t, data.Execution().num, tc.execution.num)
					for i := int64(0); i < data.Execution().num; i++ {
						uassert.Equal(t, data.Execution().msgs[i], tc.execution.msgs[i])
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
				{pkgPath: "pkg1", function: "func1", params: []string{"param1", "param2"}},
				{pkgPath: "pkg2", function: "func2", params: []string{"param3", "param4"}},
			},
		},
		{
			name:          "Success - Empty parameter changes",
			num:           0,
			msgs:          []string{},
			expectedInfos: []ParameterChangeInfo{},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			info := ExecutionInfo{num: tc.num, msgs: tc.msgs}

			// when
			infos := info.ParameterChangesInfos()

			// then
			uassert.Equal(t, len(infos), len(tc.expectedInfos))
			for i, expectedInfo := range tc.expectedInfos {
				uassert.Equal(t, infos[i].pkgPath, expectedInfo.pkgPath)
				uassert.Equal(t, infos[i].function, expectedInfo.function)
				uassert.Equal(t, len(infos[i].params), len(expectedInfo.params))
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
