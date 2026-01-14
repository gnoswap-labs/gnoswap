package v1

import (
	"errors"
	"testing"

	"gno.land/p/nt/testutils"

	"gno.land/p/nt/uassert"
)

// TestParameterRegistry_RegisterAndHandler tests registration and handler retrieval
func TestParameterRegistry_RegisterAndHandler(t *testing.T) {
	tests := []struct {
		name             string
		pkgPath          string
		function         string
		paramCount       int
		handlerFunc      func([]string) error
		expectedError    bool
		expectedErrorMsg string
	}{
		{
			name:       "Success - Register and retrieve handler",
			pkgPath:    "test/pkg",
			function:   "testFunc",
			paramCount: 1,
			handlerFunc: func([]string) error {
				return nil
			},
			expectedError: false,
		},
		{
			name:             "Failure - Handler not found",
			pkgPath:          "nonexistent/pkg",
			function:         "nonexistentFunc",
			paramCount:       0,
			handlerFunc:      nil,
			expectedError:    true,
			expectedErrorMsg: "handler not found for nonexistent/pkg:nonexistentFunc",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			registry := NewParameterRegistry()

			if tc.handlerFunc != nil {
				handler := ParameterHandlerOptions{
					pkgPath:     tc.pkgPath,
					function:    tc.function,
					paramCount:  tc.paramCount,
					handlerFunc: tc.handlerFunc,
				}
				registry.Register(handler)
			}

			// when
			key := makeHandlerKey(tc.pkgPath, tc.function)
			handler, err := registry.Handler(key)

			// then
			if tc.expectedError {
				uassert.NotNil(t, err)
				uassert.Equal(t, err.Error(), tc.expectedErrorMsg)
			} else {
				uassert.Nil(t, err)
				uassert.NotNil(t, handler)
			}
		})
	}
}

// TestParameterHandlerOptions_Execute tests parameter handler execution
func TestParameterHandlerOptions_Execute(t *testing.T) {
	tests := []struct {
		name             string
		paramCount       int
		params           []string
		handlerFunc      func([]string) error
		expectedError    bool
		expectedErrorMsg string
	}{
		{
			name:       "Success - Execute with correct param count",
			paramCount: 2,
			params:     []string{"param1", "param2"},
			handlerFunc: func([]string) error {
				return nil
			},
			expectedError: false,
		},
		{
			name:       "Failure - Wrong param count",
			paramCount: 2,
			params:     []string{"param1"},
			handlerFunc: func([]string) error {
				return nil
			},
			expectedError:    true,
			expectedErrorMsg: "expected 2 parameters, got 1",
		},
		{
			name:       "Failure - Handler error",
			paramCount: 1,
			params:     []string{"param1"},
			handlerFunc: func([]string) error {
				return errors.New("handler error")
			},
			expectedError:    true,
			expectedErrorMsg: "handler error",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			handler := NewParameterHandlerOptions(
				"test/pkg",
				"testFunc",
				tc.paramCount,
				tc.handlerFunc,
			)

			// when
			err := handler.Execute(tc.params)

			// then
			if tc.expectedError {
				uassert.NotNil(t, err)
				uassert.Equal(t, err.Error(), tc.expectedErrorMsg)
			} else {
				uassert.Nil(t, err)
			}
		})
	}
}

// TestCreateParameterHandlers tests the creation of all parameter handlers
func TestCreateParameterHandlers(t *testing.T) {
	// given & when
	registry := CreateParameterHandlers()

	// then
	uassert.NotNil(t, registry)
	uassert.NotNil(t, registry.handlers)

	// Test some known handlers
	testCases := []struct {
		pkgPath  string
		function string
	}{
		{"gno.land/r/gnoswap/halt", "SetHaltLevel"},
		{"gno.land/r/gnoswap/community_pool", "TransferToken"},
		{"gno.land/r/gnoswap/emission", "ChangeDistributionPct"},
	}

	for _, tc := range testCases {
		key := makeHandlerKey(tc.pkgPath, tc.function)
		handler, err := registry.Handler(key)
		uassert.Nil(t, err)
		uassert.NotNil(t, handler)
	}
}

// TestParseNumber tests number parsing
func TestParseNumber(t *testing.T) {
	tests := []struct {
		name                 string
		input                string
		kind                 numberKind
		expected             interface{}
		expectedPanic        bool
		expectedPanicMessage string
	}{
		{
			name:     "Parse int",
			input:    "123",
			kind:     kindInt,
			expected: int(123),
		},
		{
			name:     "Parse int64",
			input:    "123456789",
			kind:     kindInt64,
			expected: int64(123456789),
		},
		{
			name:     "Parse uint64",
			input:    "123456789",
			kind:     kindUint64,
			expected: uint64(123456789),
		},
		{
			name:                 "Invalid number",
			input:                "invalid",
			kind:                 kindInt,
			expectedPanic:        true,
			expectedPanicMessage: "invalid int value: invalid",
		},
		{
			name:                 "Invalid kind",
			input:                "123",
			kind:                 numberKind(999),
			expectedPanic:        true,
			expectedPanicMessage: "unsupported number kind: %!v((unhandled))",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMessage, func() {
					parseNumber(tc.input, tc.kind)
				})
			} else {
				result := parseNumber(tc.input, tc.kind)
				uassert.Equal(t, result, tc.expected)
			}
		})
	}
}

// TestParseBool tests boolean parsing
func TestParseBool(t *testing.T) {
	tests := []struct {
		name                 string
		input                string
		expected             bool
		expectedPanic        bool
		expectedPanicMessage string
	}{
		{
			name:     "Parse true",
			input:    "true",
			expected: true,
		},
		{
			name:     "Parse false",
			input:    "false",
			expected: false,
		},
		{
			name:                 "Invalid boolean",
			input:                "invalid",
			expectedPanic:        true,
			expectedPanicMessage: "invalid bool value: invalid",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMessage, func() {
					parseBool(tc.input)
				})
			} else {
				result := parseBool(tc.input)
				uassert.Equal(t, result, tc.expected)
			}
		})
	}
}

func TestValidateExecutions(t *testing.T) {
	tests := []struct {
		name                  string
		numToExecute          int64
		executions            string
		expectedError         bool
		expectedErrorContains string
	}{
		/* Success cases for all handler functions */
		// community_pool
		{
			name:          "Success - community_pool TransferToken",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/gns," + testutils.TestAddress("valid").String() + ",1000000",
			expectedError: false,
		},
		{
			name:          "Success - community_pool TransferToken empty address",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/gns," + address("").String() + ",1000000",
			expectedError: false,
		},
		// emission
		{
			name:          "Success - emission SetDistributionStartTime",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/emission*EXE*SetDistributionStartTime*EXE*1234567890",
			expectedError: false,
		},
		{
			name:          "Success - emission ChangeDistributionPct",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/emission*EXE*ChangeDistributionPct*EXE*1,2500,2,2500,3,2500,4,2500",
			expectedError: false,
		},
		// gov/governance
		{
			name:          "Success - gov/governance Reconfigure",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/gov/governance*EXE*Reconfigure*EXE*86400,604800,3600,500000,1000,86400,259200",
			expectedError: false,
		},
		// halt
		{
			name:          "Success - halt SetHaltLevel",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE",
			expectedError: false,
		},
		{
			name:          "Success - halt SetOperationStatus",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/halt*EXE*SetOperationStatus*EXE*POOL,true",
			expectedError: false,
		},
		// pool
		{
			name:          "Success - pool CollectProtocol",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/pool*EXE*CollectProtocol*EXE*gno.land/r/gnoswap/gns,gno.land/r/gnoland/wugnot,3000," + testutils.TestAddress("recipient").String() + ",1000000,1000000",
			expectedError: false,
		},
		{
			name:          "Success - pool SetFeeProtocol",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/pool*EXE*SetFeeProtocol*EXE*1,2",
			expectedError: false,
		},
		{
			name:          "Success - pool SetPoolCreationFee",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/pool*EXE*SetPoolCreationFee*EXE*1000",
			expectedError: false,
		},
		{
			name:          "Success - pool SetWithdrawalFee",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/pool*EXE*SetWithdrawalFee*EXE*100",
			expectedError: false,
		},
		// protocol_fee
		{
			name:          "Success - protocol_fee SetDevOpsPct",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/protocol_fee*EXE*SetDevOpsPct*EXE*5000",
			expectedError: false,
		},
		// dust_converter
		{
			name:          "Success - dust_converter SetDustMinAmount",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/dust_converter*EXE*SetDustMinAmount*EXE*10",
			expectedError: false,
		},
		{
			name:          "Success - dust_converter SetDustMaxAmount",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/dust_converter*EXE*SetDustMaxAmount*EXE*100",
			expectedError: false,
		},
		{
			name:          "Success - dust_converter SetCooldownSeconds",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/dust_converter*EXE*SetCooldownSeconds*EXE*3600",
			expectedError: false,
		},
		{
			name:          "Success - dust_converter AddTargetAsset",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/dust_converter*EXE*AddTargetAsset*EXE*gno.land/r/gnoswap/gns",
			expectedError: false,
		},
		{
			name:          "Success - dust_converter RemoveTargetAsset",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/dust_converter*EXE*RemoveTargetAsset*EXE*gno.land/r/gnoswap/gns",
			expectedError: false,
		},
		// rbac
		{
			name:          "Success - rbac RegisterRole",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/rbac*EXE*RegisterRole*EXE*newRole," + testutils.TestAddress("roleAddr").String(),
			expectedError: false,
		},
		{
			name:          "Success - rbac UpdateRoleAddress",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/rbac*EXE*UpdateRoleAddress*EXE*existingRole," + testutils.TestAddress("newRoleAddr").String(),
			expectedError: false,
		},
		{
			name:          "Success - rbac RemoveRole",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/rbac*EXE*RemoveRole*EXE*roleToRemove",
			expectedError: false,
		},
		// router
		{
			name:          "Success - router SetSwapFee",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/router*EXE*SetSwapFee*EXE*15",
			expectedError: false,
		},
		// staker
		{
			name:          "Success - staker SetDepositGnsAmount",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/staker*EXE*SetDepositGnsAmount*EXE*1000000000",
			expectedError: false,
		},
		{
			name:          "Success - staker SetMinimumRewardAmount",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/staker*EXE*SetMinimumRewardAmount*EXE*1000000",
			expectedError: false,
		},
		{
			name:          "Success - staker SetTokenMinimumRewardAmount",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/staker*EXE*SetTokenMinimumRewardAmount*EXE*gno.land/r/gnoswap/gns:1000000",
			expectedError: false,
		},
		{
			name:          "Success - staker SetPoolTier",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/staker*EXE*SetPoolTier*EXE*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:3000,1",
			expectedError: false,
		},
		{
			name:          "Success - staker ChangePoolTier",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/staker*EXE*ChangePoolTier*EXE*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:3000,2",
			expectedError: false,
		},
		{
			name:          "Success - staker RemovePoolTier",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/staker*EXE*RemovePoolTier*EXE*poolId",
			expectedError: false,
		},
		{
			name:          "Success - staker SetUnStakingFee",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*100",
			expectedError: false,
		},
		{
			name:          "Success - staker SetWarmUp",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/staker*EXE*SetWarmUp*EXE*100,1000",
			expectedError: false,
		},
		// Multiple executions
		{
			name:          "Success - multiple valid executions",
			numToExecute:  2,
			executions:    "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*gno.land/r/gnoswap/pool*EXE*SetPoolCreationFee*EXE*1000",
			expectedError: false,
		},

		/* Failure cases - Basic validation */
		{
			name:                  "Failure - empty executions",
			numToExecute:          1,
			executions:            "",
			expectedError:         true,
			expectedErrorContains: "executions is empty",
		},
		{
			name:                  "Failure - invalid execution count (zero)",
			numToExecute:          0,
			executions:            "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE",
			expectedError:         true,
			expectedErrorContains: "numToExecute is less than or equal to 0",
		},
		{
			name:                  "Failure - execution count mismatch",
			numToExecute:          2,
			executions:            "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE",
			expectedError:         true,
			expectedErrorContains: "executions count (1) does not match numToExecute (2)",
		},
		{
			name:                  "Failure - malformed execution format",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/halt*SetHaltLevel",
			expectedError:         true,
			expectedErrorContains: "expected 3 parts (pkgPath, function, params)",
		},
		{
			name:                  "Failure - empty package path",
			numToExecute:          1,
			executions:            "*EXE*SetHaltLevel*EXE*NONE",
			expectedError:         true,
			expectedErrorContains: "package path is empty",
		},
		{
			name:                  "Failure - empty function name",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/halt*EXE**EXE*NONE",
			expectedError:         true,
			expectedErrorContains: "function name is empty",
		},
		{
			name:         "Failure - exceeds max executions",
			numToExecute: 11,
			executions: "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE",
			expectedError:         true,
			expectedErrorContains: "numToExecute is greater than 10",
		},

		/* Failure cases - Handler is not exists */
		{
			name:                  "Failure - non-existent package path",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/nonexistent*EXE*SomeFunction*EXE*param1",
			expectedError:         true,
			expectedErrorContains: "handler not found for gno.land/r/gnoswap/nonexistent:SomeFunction",
		},
		{
			name:                  "Failure - non-existent function in valid package",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/halt*EXE*NonExistentFunction*EXE*param1",
			expectedError:         true,
			expectedErrorContains: "handler not found for gno.land/r/gnoswap/halt:NonExistentFunction",
		},
		{
			name:                  "Failure - mixed valid and invalid executions",
			numToExecute:          2,
			executions:            "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*gno.land/r/gnoswap/fake*EXE*FakeFunction*EXE*param1",
			expectedError:         true,
			expectedErrorContains: "handler not found for gno.land/r/gnoswap/fake:FakeFunction",
		},

		/* Failure cases - Parameter count validation */
		{
			name:                  "Failure - halt SetHaltLevel wrong param count",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*param1,param2",
			expectedError:         true,
			expectedErrorContains: "expected 1 parameters for gno.land/r/gnoswap/halt:SetHaltLevel",
		},
		{
			name:                  "Failure - community_pool TransferToken wrong param count",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/gns,g1address",
			expectedError:         true,
			expectedErrorContains: "expected 3 parameters for gno.land/r/gnoswap/community_pool:TransferToken",
		},

		/* Failure cases - Parameter type validation */
		{
			name:                  "Failure - pool SetFeeProtocol invalid uint8 (negative)",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/pool*EXE*SetFeeProtocol*EXE*1,-2",
			expectedError:         true,
			expectedErrorContains: "out of range: -2",
		},
		{
			name:                  "Failure - pool SetFeeProtocol invalid uint8 (too large)",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/pool*EXE*SetFeeProtocol*EXE*1,256",
			expectedError:         true,
			expectedErrorContains: "out of range: 256",
		},
		{
			name:                  "Failure - staker SetWarmUp invalid number type",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/staker*EXE*SetWarmUp*EXE*invalid,1000",
			expectedError:         true,
			expectedErrorContains: "invalid int64 value: invalid",
		},
		{
			name:                  "Failure - halt SetOperationStatus invalid bool type",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/halt*EXE*SetOperationStatus*EXE*POOL,not_bool",
			expectedError:         true,
			expectedErrorContains: "invalid bool value: not_bool",
		},
		{
			name:                  "Failure - community_pool TransferToken invalid address",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/gns,invalidAddress,1000000",
			expectedError:         true,
			expectedErrorContains: "invalid address",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			err := validateExecutions(tc.numToExecute, tc.executions)

			if tc.expectedError {
				uassert.NotNil(t, err)
				uassert.ErrorContains(t, err, tc.expectedErrorContains)
			} else {
				uassert.Nil(t, err)
			}
		})
	}
}
