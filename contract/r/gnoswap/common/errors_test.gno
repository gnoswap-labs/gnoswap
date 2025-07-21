package common

import (
	"errors"
	"testing"

	"gno.land/p/demo/uassert"
)

func TestErrors_newErrorWithDetail(t *testing.T) {
	tests := []struct {
		name           string
		inputError     error
		inputDetail    string
		expectedResult string
	}{
		{
			name:           "Valid error with detail",
			inputError:     errNoPermission,
			inputDetail:    "user has insufficient privileges",
			expectedResult: "[GNOSWAP-COMMON-001] caller has no permission || user has insufficient privileges",
		},
		{
			name:           "Error with empty detail",
			inputError:     errHalted,
			inputDetail:    "",
			expectedResult: "[GNOSWAP-COMMON-002] halted || ",
		},
		{
			name:           "Custom error with detail",
			inputError:     errors.New("custom error"),
			inputDetail:    "additional context",
			expectedResult: "custom error || additional context",
		},
		{
			name:           "Error with special characters in detail",
			inputError:     errInvalidAddr,
			inputDetail:    "address format: 0x123...",
			expectedResult: "[GNOSWAP-COMMON-005] invalid address || address format: 0x123...",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			inputError := tc.inputError
			inputDetail := tc.inputDetail

			// when
			result := newErrorWithDetail(inputError, inputDetail)

			// then
			uassert.Equal(t, tc.expectedResult, result)
		})
	}
}

func TestErrors_ErrorConstants(t *testing.T) {
	tests := []struct {
		name         string
		error        error
		expectedCode string
		expectedMsg  string
	}{
		{
			name:         "errNoPermission",
			error:        errNoPermission,
			expectedCode: "GNOSWAP-COMMON-001",
			expectedMsg:  "[GNOSWAP-COMMON-001] caller has no permission",
		},
		{
			name:         "errHalted",
			error:        errHalted,
			expectedCode: "GNOSWAP-COMMON-002",
			expectedMsg:  "[GNOSWAP-COMMON-002] halted",
		},
		{
			name:         "errOutOfRange",
			error:        errOutOfRange,
			expectedCode: "GNOSWAP-COMMON-003",
			expectedMsg:  "[GNOSWAP-COMMON-003] value out of range",
		},
		{
			name:         "errNotRegistered",
			error:        errNotRegistered,
			expectedCode: "GNOSWAP-COMMON-004",
			expectedMsg:  "[GNOSWAP-COMMON-004] token is not registered",
		},
		{
			name:         "errInvalidAddr",
			error:        errInvalidAddr,
			expectedCode: "GNOSWAP-COMMON-005",
			expectedMsg:  "[GNOSWAP-COMMON-005] invalid address",
		},
		{
			name:         "errOverflow",
			error:        errOverflow,
			expectedCode: "GNOSWAP-COMMON-006",
			expectedMsg:  "[GNOSWAP-COMMON-006] overflow",
		},
		{
			name:         "errInvalidPositionId",
			error:        errInvalidPositionId,
			expectedCode: "GNOSWAP-COMMON-007",
			expectedMsg:  "[GNOSWAP-COMMON-007] invalid positionId",
		},
		{
			name:         "errInvalidInput",
			error:        errInvalidInput,
			expectedCode: "GNOSWAP-COMMON-008",
			expectedMsg:  "[GNOSWAP-COMMON-008] invalid input data",
		},
		{
			name:         "errOverFlow",
			error:        errOverFlow,
			expectedCode: "GNOSWAP-COMMON-009",
			expectedMsg:  "[GNOSWAP-COMMON-009] overflow",
		},
		{
			name:         "errIdenticalTicks",
			error:        errIdenticalTicks,
			expectedCode: "GNOSWAP-COMMON-010",
			expectedMsg:  "[GNOSWAP-COMMON-010] identical ticks",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			errorConstant := tc.error

			// when
			errorMsg := errorConstant.Error()

			// then
			uassert.Equal(t, tc.expectedMsg, errorMsg)
			uassert.True(t, len(errorMsg) > 0)
		})
	}
}

// TestErrors_ConsistencyAndNaming tests error naming consistency and uniqueness
func TestErrors_ConsistencyAndNaming(t *testing.T) {
	allErrors := []error{
		errNoPermission, errHalted, errOutOfRange, errNotRegistered,
		errInvalidAddr, errOverflow, errInvalidPositionId, errInvalidInput,
		errOverFlow, errIdenticalTicks,
	}
	
	t.Run("All errors have unique codes", func(t *testing.T) {
		seen := make(map[string]bool)
		for _, err := range allErrors {
			msg := err.Error()
			// Extract error code (assuming format [GNOSWAP-COMMON-XXX])
			if len(msg) > 20 {
				code := msg[0:20] // approximate code extraction
				if seen[code] {
					t.Errorf("Duplicate error code detected: %s", code)
				}
				seen[code] = true
			}
		}
	})
	
	t.Run("All errors follow naming convention", func(t *testing.T) {
		for _, err := range allErrors {
			msg := err.Error()
			uassert.True(t, len(msg) > 0)
			// Check that error starts with [GNOSWAP-COMMON-
			if len(msg) > 16 {
				prefix := msg[0:16]
				uassert.Equal(t, "[GNOSWAP-COMMON-", prefix)
			}
		}
	})
}

// TestErrors_WithDetailEdgeCases tests edge cases for newErrorWithDetail
func TestErrors_WithDetailEdgeCases(t *testing.T) {
	tests := []struct {
		name           string
		inputError     error
		inputDetail    string
		expectedResult string
	}{
		{
			name:           "Very long detail string",
			inputError:     errInvalidInput,
			inputDetail:    "This is a very long detail string that contains a lot of information about what went wrong and could potentially be used to debug complex issues in the system",
			expectedResult: "[GNOSWAP-COMMON-008] invalid input data || This is a very long detail string that contains a lot of information about what went wrong and could potentially be used to debug complex issues in the system",
		},
		{
			name:           "Detail with special formatting characters",
			inputError:     errInvalidAddr,
			inputDetail:    "address\nwith\nnewlines\tand\ttabs",
			expectedResult: "[GNOSWAP-COMMON-005] invalid address || address\nwith\nnewlines\tand\ttabs",
		},
		{
			name:           "Detail with unicode characters",
			inputError:     errOverflow,
			inputDetail:    "数値が大きすぎます (value too large)",
			expectedResult: "[GNOSWAP-COMMON-006] overflow || 数値が大きすぎます (value too large)",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			inputError := tc.inputError
			inputDetail := tc.inputDetail

			// when
			result := newErrorWithDetail(inputError, inputDetail)

			// then
			uassert.Equal(t, tc.expectedResult, result)
		})
	}
}
