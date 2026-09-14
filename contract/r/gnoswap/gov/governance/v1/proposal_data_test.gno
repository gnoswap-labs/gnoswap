package governance

import (
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/gov/governance"
)

func TestProposalMetadata_Validation(cur realm, t *testing.T) {
	tests := []struct {
		name          string
		title         string
		description   string
		expectedError bool
	}{
		{name: "Success - Valid metadata", title: "Valid Title", description: "Valid description"},
		{name: "Failure - Empty title", title: "", description: "Valid description", expectedError: true},
		{name: "Failure - Empty description", title: "Valid Title", expectedError: true},
		{name: "Failure - Title too long", title: string(make([]byte, maxTitleLength+1)), description: "Valid description", expectedError: true},
		{name: "Failure - Description too long", title: "Valid Title", description: string(make([]byte, maxDescriptionLength+1)), expectedError: true},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			metadata := governance.MakeProposalMetadata(tc.title, tc.description)
			err := MakeProposalMetadataResolver(metadata).Validate()
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

func TestProposalData_Validation(cur realm, t *testing.T) {
	validTokenPath := "gno.land/r/gnoswap/gns.GNS"
	tests := []struct {
		name                 string
		proposalType         governance.ProposalType
		spendInfo            governance.CommunityPoolSpendInfo
		execution            governance.ExecutionInfo
		expectedError        bool
		expectedErrorMessage string
	}{
		{name: "Success - Valid Text proposal", proposalType: governance.Text},
		{
			name:         "Success - Valid CommunityPoolSpend proposal",
			proposalType: governance.CommunityPoolSpend,
			spendInfo:    governance.MakeCommunityPoolSpendInfo(testutils.TestAddress("g1recipient"), validTokenPath, 1000),
		},
		{
			name:         "Success - Valid ParameterChange proposal",
			proposalType: governance.ParameterChange,
			execution:    governance.MakeExecutionInfo(1, []string{"gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0"}),
		},
		{
			name:         "Success - Valid ParameterChange proposal with one-sided CollectProtocol",
			proposalType: governance.ParameterChange,
			execution:    governance.MakeExecutionInfo(1, []string{"gno.land/r/gnoswap/pool*EXE*CollectProtocol*EXE*gno.land/r/gnoswap/gns.GNS,gno.land/r/gnoswap/test_token/foo,500," + testutils.TestAddress("recipient").String() + ",0,100"}),
		},
		{
			name:                 "Failure - CommunityPoolSpend with invalid address",
			proposalType:         governance.CommunityPoolSpend,
			spendInfo:            governance.MakeCommunityPoolSpendInfo(address(""), validTokenPath, 1000),
			expectedError:        true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-001] invalid input || to is invalid address",
		},
		{
			name:                 "Failure - CommunityPoolSpend with zero amount",
			proposalType:         governance.CommunityPoolSpend,
			spendInfo:            governance.MakeCommunityPoolSpendInfo(testutils.TestAddress("g1recipient"), validTokenPath, 0),
			expectedError:        true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-001] invalid input || amount is not positive",
		},
		{
			name:                 "Failure - CommunityPoolSpend with negative amount",
			proposalType:         governance.CommunityPoolSpend,
			spendInfo:            governance.MakeCommunityPoolSpendInfo(testutils.TestAddress("g1recipient"), validTokenPath, -100),
			expectedError:        true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-001] invalid input || amount is not positive",
		},
		{
			name:                 "Failure - Invalid ParameterChange proposal",
			proposalType:         governance.ParameterChange,
			execution:            governance.MakeExecutionInfo(0, []string{}),
			expectedError:        true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-001] invalid input || numToExecute is less than or equal to 0",
		},
		{
			name:                 "Failure - ParameterChange invalid CollectProtocol amount",
			proposalType:         governance.ParameterChange,
			execution:            governance.MakeExecutionInfo(1, []string{"gno.land/r/gnoswap/pool*EXE*CollectProtocol*EXE*gno.land/r/gnoswap/gns.GNS,gno.land/r/gnoswap/test_token/foo,500," + testutils.TestAddress("recipient").String() + ",invalid,100"}),
			expectedError:        true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-001] invalid input || execution[0]: param[4]: invalid int64 value: invalid",
		},
		{
			name:                 "Failure - ParameterChange invalid RBAC admin update",
			proposalType:         governance.ParameterChange,
			execution:            governance.MakeExecutionInfo(1, []string{"gno.land/r/gnoswap/rbac*EXE*UpdateRoleAddress*EXE*admin," + testutils.TestAddress("role").String()}),
			expectedError:        true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-001] invalid input || execution[0]: param[0]: admin role cannot be updated: admin",
		},
		{
			name:                 "Failure - ParameterChange max execution count takes precedence over mismatch",
			proposalType:         governance.ParameterChange,
			execution:            governance.MakeExecutionInfo(11, []string{"pkg1*EXE*func1*EXE*param1"}),
			expectedError:        true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-001] invalid input || numToExecute is greater than 10",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			data := governance.MakeProposalData(tc.proposalType, tc.spendInfo, tc.execution)
			err := MakeProposalDataResolver(data).Validate()
			if tc.expectedError {
				uassert.Error(t, err)
				uassert.Equal(t, err.Error(), tc.expectedErrorMessage)
				return
			}

			uassert.NoError(t, err)
			uassert.Equal(t, data.ProposalType().String(), tc.proposalType.String())
			if tc.proposalType == governance.CommunityPoolSpend {
				spend, ok := data.CommunityPoolSpend()
				uassert.True(t, ok)
				uassert.Equal(t, spend.To(), tc.spendInfo.To())
				uassert.Equal(t, spend.TokenPath(), tc.spendInfo.TokenPath())
				uassert.Equal(t, spend.Amount(), tc.spendInfo.Amount())
			}
			if tc.proposalType == governance.ParameterChange {
				execution, ok := data.Execution()
				uassert.True(t, ok)
				uassert.Equal(t, execution.Num(), tc.execution.Num())
				for i := int64(0); i < execution.Num(); i++ {
					uassert.Equal(t, execution.Msgs()[i], tc.execution.Msgs()[i])
				}
			}
		})
	}
}

func TestParameterChangeInfo_Parsing(cur realm, t *testing.T) {
	tests := []struct {
		name          string
		num           int64
		msgs          []string
		expectedInfos []governance.ParameterChangeInfo
	}{
		{
			name: "Success - Valid parameter changes",
			num:  2,
			msgs: []string{"pkg1*EXE*func1*EXE*param1,param2", "pkg2*EXE*func2*EXE*param3,param4"},
			expectedInfos: []governance.ParameterChangeInfo{
				governance.MakeParameterChangeInfo("pkg1", "func1", []string{"param1", "param2"}),
				governance.MakeParameterChangeInfo("pkg2", "func2", []string{"param3", "param4"}),
			},
		},
		{name: "Success - Empty parameter changes", num: 0, msgs: []string{}, expectedInfos: []governance.ParameterChangeInfo{}},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			info := governance.MakeExecutionInfo(tc.num, tc.msgs)
			data := governance.MakeProposalData(governance.ParameterChange, governance.DefaultCommunityPoolSpendInfo(), info)
			infos, err := MakeProposalDataResolver(data).ParameterChangesInfos()
			uassert.NoError(t, err)
			uassert.Equal(t, len(infos), len(tc.expectedInfos))
			for i, expectedInfo := range tc.expectedInfos {
				uassert.Equal(t, infos[i].PkgPath(), expectedInfo.PkgPath())
				uassert.Equal(t, infos[i].Function(), expectedInfo.Function())
				uassert.Equal(t, len(infos[i].Params()), len(expectedInfo.Params()))
			}
		})
	}
}

func TestProposalData_ParameterChangesInfos_MalformedMessage(cur realm, t *testing.T) {
	info := governance.MakeExecutionInfo(1, []string{"pkg1*EXE*func1"})
	data := governance.MakeProposalData(governance.ParameterChange, governance.DefaultCommunityPoolSpendInfo(), info)
	infos, err := MakeProposalDataResolver(data).ParameterChangesInfos()
	uassert.Equal(t, len(infos), 0)
	uassert.ErrorContains(t, err, "malformed execution message")
}

func TestMakeExecuteMessage(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		pkgPath  string
		function string
		params   []string
		expected string
	}{
		{name: "Create message with no params", pkgPath: "test/pkg", function: "testFunc", params: []string{}, expected: "test/pkg*EXE*testFunc*EXE*"},
		{name: "Create message with params", pkgPath: "test/pkg", function: "testFunc", params: []string{"param1", "param2"}, expected: "test/pkg*EXE*testFunc*EXE*param1,param2"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			result := makeExecuteMessage(tc.pkgPath, tc.function, tc.params)
			uassert.Equal(t, result, tc.expected)
		})
	}
}
