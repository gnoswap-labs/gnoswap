package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

// Common test structure for operation tests
type operationTestCase struct {
	name                 string
	expectedHasPanic     bool
	expectedPanicMessage string
}

func TestPhalt_OpTypeString(t *testing.T) {
	tests := []struct {
		name                 string
		input                OpType
		expectedResult       string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success OpTypePool string representation",
			input:            OpTypePool,
			expectedResult:   "pool",
			expectedHasPanic: false,
		},
		{
			name:             "Success OpTypePosition string representation",
			input:            OpTypePosition,
			expectedResult:   "position",
			expectedHasPanic: false,
		},
		{
			name:             "Success OpTypeProtocolFee string representation",
			input:            OpTypeProtocolFee,
			expectedResult:   "protocol_fee",
			expectedHasPanic: false,
		},
		{
			name:             "Success OpTypeRouter string representation",
			input:            OpTypeRouter,
			expectedResult:   "router",
			expectedHasPanic: false,
		},
		{
			name:             "Success OpTypeStaker string representation",
			input:            OpTypeStaker,
			expectedResult:   "staker",
			expectedHasPanic: false,
		},
		{
			name:             "Success OpTypeLaunchpad string representation",
			input:            OpTypeLaunchpad,
			expectedResult:   "launchpad",
			expectedHasPanic: false,
		},
		{
			name:             "Success OpTypeGovernance string representation",
			input:            OpTypeGovernance,
			expectedResult:   "governance",
			expectedHasPanic: false,
		},
		{
			name:             "Success OpTypeGovStaker string representation",
			input:            OpTypeGovStaker,
			expectedResult:   "gov_staker",
			expectedHasPanic: false,
		},
		{
			name:             "Success OpTypeXGns string representation",
			input:            OpTypeXGns,
			expectedResult:   "xgns",
			expectedHasPanic: false,
		},
		{
			name:             "Success OpTypeCommunityPool string representation",
			input:            OpTypeCommunityPool,
			expectedResult:   "community_pool",
			expectedHasPanic: false,
		},
		{
			name:             "Success OpTypeEmission string representation",
			input:            OpTypeEmission,
			expectedResult:   "emission",
			expectedHasPanic: false,
		},
		{
			name:             "Success OpTypeWithdraw string representation",
			input:            OpTypeWithdraw,
			expectedResult:   "withdraw",
			expectedHasPanic: false,
		},
		{
			name:             "Success custom OpType string representation",
			input:            OpType("custom_operation"),
			expectedResult:   "custom_operation",
			expectedHasPanic: false,
		},
		{
			name:             "Success empty OpType string representation",
			input:            OpType(""),
			expectedResult:   "",
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// when
			result := tc.input.String()

			// then
			uassert.Equal(t, tc.expectedResult, result)
		})
	}
}

func TestPhalt_NewOperation(t *testing.T) {
	tests := []struct {
		name                 string
		inputOpType          OpType
		inputName            string
		inputDesc            string
		expectedType         OpType
		expectedName         string
		expectedDesc         string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success creates valid basicOperation",
			inputOpType:      OpTypePool,
			inputName:        "Pool Management",
			inputDesc:        "Manages pool operations",
			expectedType:     OpTypePool,
			expectedName:     "Pool Management",
			expectedDesc:     "Manages pool operations",
			expectedHasPanic: false,
		},
		{
			name:             "Success with empty values",
			inputOpType:      OpType(""),
			inputName:        "",
			inputDesc:        "",
			expectedType:     OpType(""),
			expectedName:     "",
			expectedDesc:     "",
			expectedHasPanic: false,
		},
		{
			name:             "Success with custom OpType",
			inputOpType:      OpType("custom_type"),
			inputName:        "Custom Operation",
			inputDesc:        "Custom description",
			expectedType:     OpType("custom_type"),
			expectedName:     "Custom Operation",
			expectedDesc:     "Custom description",
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// when
			op := NewOperation(tc.inputOpType, tc.inputName, tc.inputDesc)

			// then
			uassert.Equal(t, string(tc.expectedType), string(op.Type()))
			uassert.Equal(t, tc.expectedName, op.Name())
			uassert.Equal(t, tc.expectedDesc, op.Desc())
		})
	}
}

func TestPhalt_OperationConstants(t *testing.T) {
	tests := []operationTestCase{
		{
			name:             "Success OpType constants match raw constants",
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// when
			// then
			uassert.Equal(t, rawPool, string(OpTypePool))
			uassert.Equal(t, rawPosition, string(OpTypePosition))
			uassert.Equal(t, rawProtocolFee, string(OpTypeProtocolFee))
			uassert.Equal(t, rawRouter, string(OpTypeRouter))
			uassert.Equal(t, rawStaker, string(OpTypeStaker))
			uassert.Equal(t, rawLaunchpad, string(OpTypeLaunchpad))
			uassert.Equal(t, rawGovernance, string(OpTypeGovernance))
			uassert.Equal(t, rawGovStaker, string(OpTypeGovStaker))
			uassert.Equal(t, rawXGns, string(OpTypeXGns))
			uassert.Equal(t, rawCommunityPool, string(OpTypeCommunityPool))
			uassert.Equal(t, rawEmission, string(OpTypeEmission))
			uassert.Equal(t, rawWithdraw, string(OpTypeWithdraw))
		})
	}
}

func TestPhalt_OperationInterface(t *testing.T) {
	tests := []operationTestCase{
		{
			name:             "Success Operation implements interfaces",
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// when
			var op Operation = NewOperation(OpTypePool, "Pool", "Pool operations")
			var baseOp baseOp = NewOperation(OpTypePool, "Pool", "Pool operations")

			// then
			uassert.Equal(t, string(OpTypePool), string(op.Type()))
			uassert.Equal(t, "Pool", op.Name())
			uassert.Equal(t, "Pool operations", op.Desc())
			uassert.Equal(t, "Pool", baseOp.Name())
			uassert.Equal(t, "Pool operations", baseOp.Desc())
		})
	}
}

func TestPhalt_OperationSpecialCharacters(t *testing.T) {
	tests := []struct {
		name                 string
		inputOpType          OpType
		inputName            string
		inputDesc            string
		expectedType         OpType
		expectedName         string
		expectedDesc         string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success with special characters in name",
			inputOpType:      OpType("special@op"),
			inputName:        "Special @#$ Operation",
			inputDesc:        "Description with special chars: <>&'\"",
			expectedType:     OpType("special@op"),
			expectedName:     "Special @#$ Operation",
			expectedDesc:     "Description with special chars: <>&'\"",
			expectedHasPanic: false,
		},
		{
			name:             "Success with unicode characters",
			inputOpType:      OpType("unicode_操作"),
			inputName:        "Unicode 操作名称",
			inputDesc:        "Description with unicode: 这是一个描述",
			expectedType:     OpType("unicode_操作"),
			expectedName:     "Unicode 操作名称",
			expectedDesc:     "Description with unicode: 这是一个描述",
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// when
			op := NewOperation(tc.inputOpType, tc.inputName, tc.inputDesc)

			// then
			uassert.Equal(t, string(tc.expectedType), string(op.Type()))
			uassert.Equal(t, tc.expectedName, op.Name())
			uassert.Equal(t, tc.expectedDesc, op.Desc())
		})
	}
}

func TestPhalt_OperationComparison(t *testing.T) {
	tests := []operationTestCase{
		{
			name:             "Success multiple operations independence",
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// when
			op1 := NewOperation(OpTypePool, "Pool Op 1", "First pool operation")
			op2 := NewOperation(OpTypePool, "Pool Op 2", "Second pool operation")
			op3 := NewOperation(OpTypeRouter, "Router Op", "Router operation")

			// then
			// Same type, different names/descriptions
			uassert.Equal(t, string(OpTypePool), string(op1.Type()))
			uassert.Equal(t, string(OpTypePool), string(op2.Type()))
			uassert.Equal(t, "Pool Op 1", op1.Name())
			uassert.Equal(t, "Pool Op 2", op2.Name())
			
			// Different types
			uassert.Equal(t, string(OpTypeRouter), string(op3.Type()))
			uassert.True(t, op1.Type() != op3.Type())
		})
	}
}