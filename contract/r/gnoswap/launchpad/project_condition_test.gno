package launchpad

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestProjectCondition_Getters(t *testing.T) {
	tests := []struct {
		name             string
		tokenPath        string
		minimumAmount    int64
		getterFunc       string
		expectedValue    interface{}
		expectedHasError bool
		expectedError    string
	}{
		{
			name:          "get token path",
			tokenPath:     "gno.land/r/demo/gns",
			minimumAmount: 1000,
			getterFunc:    "TokenPath",
			expectedValue: "gno.land/r/demo/gns",
		},
		{
			name:          "get minimum amount",
			tokenPath:     "gno.land/r/demo/gns",
			minimumAmount: 1000,
			getterFunc:    "MinimumAmount",
			expectedValue: int64(1000),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			condition := &ProjectCondition{
				tokenPath:     tt.tokenPath,
				minimumAmount: tt.minimumAmount,
			}

			// Execute and verify
			var result interface{}
			switch tt.getterFunc {
			case "TokenPath":
				result = condition.TokenPath()
			case "MinimumAmount":
				result = condition.MinimumAmount()
			}
			uassert.Equal(t, result, tt.expectedValue)
		})
	}
}

func TestProjectCondition_IsAvailable(t *testing.T) {
	tests := []struct {
		name              string
		tokenPath         string
		minimumAmount     int64
		expectedAvailable bool
	}{
		{
			name:              "available with valid token path and positive amount",
			tokenPath:         "gno.land/r/demo/gns",
			minimumAmount:     1000,
			expectedAvailable: true,
		},
		{
			name:              "not available with empty token path",
			tokenPath:         "",
			minimumAmount:     1000,
			expectedAvailable: false,
		},
		{
			name:              "not available with zero amount",
			tokenPath:         "gno.land/r/demo/gns",
			minimumAmount:     0,
			expectedAvailable: false,
		},
		{
			name:              "not available with negative amount",
			tokenPath:         "gno.land/r/demo/gns",
			minimumAmount:     -100,
			expectedAvailable: false,
		},
		{
			name:              "not available with empty token path and zero amount",
			tokenPath:         "",
			minimumAmount:     0,
			expectedAvailable: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			condition := &ProjectCondition{
				tokenPath:     tt.tokenPath,
				minimumAmount: tt.minimumAmount,
			}

			// Execute and verify
			uassert.Equal(t, condition.IsAvailable(), tt.expectedAvailable)
		})
	}
}

func TestProjectCondition_CheckCondition(t *testing.T) {
	tests := []struct {
		name             string
		tokenPath        string
		minimumAmount    int64
		inputToken       string
		inputAmount      int64
		expectedHasError bool
		expectedError    string
	}{
		{
			name:             "check condition succeed when input amount greater than minimum",
			tokenPath:        "gno.land/r/demo/gns",
			minimumAmount:    1000,
			inputToken:       "gno.land/r/demo/gns",
			inputAmount:      1500,
			expectedHasError: false,
		},
		{
			name:             "check condition succeed when input amount equals minimum",
			tokenPath:        "gno.land/r/demo/gns",
			minimumAmount:    1000,
			inputToken:       "gno.land/r/demo/gns",
			inputAmount:      1000,
			expectedHasError: false,
		},
		{
			name:             "check condition fail when input amount less than minimum",
			tokenPath:        "gno.land/r/demo/gns",
			minimumAmount:    1000,
			inputToken:       "gno.land/r/demo/gns",
			inputAmount:      500,
			expectedHasError: true,
			expectedError:    "input amount(500) is less than minimum amount(1000)",
		},
		{
			name:             "check condition fail when token path not matched",
			tokenPath:        "gno.land/r/demo/gns",
			minimumAmount:    1000,
			inputToken:       "gno.land/r/demo/btc",
			inputAmount:      1500,
			expectedHasError: true,
			expectedError:    "token path(gno.land/r/demo/btc) is not matched",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			condition := &ProjectCondition{
				tokenPath:     tt.tokenPath,
				minimumAmount: tt.minimumAmount,
			}

			// Execute
			err := condition.CheckBalanceCondition(tt.inputToken, tt.inputAmount)

			// Verify
			if tt.expectedHasError {
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestProjectCondition_NewProjectCondition(t *testing.T) {
	tests := []struct {
		name              string
		tokenPath         string
		minimumAmount     int64
		expectedTokenPath string
		expectedMinAmount int64
		expectedHasError  bool
		expectedError     string
	}{
		{
			name:              "new project condition create valid condition with correct values",
			tokenPath:         "gno.land/r/demo/gns",
			minimumAmount:     1000,
			expectedTokenPath: "gno.land/r/demo/gns",
			expectedMinAmount: 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute
			condition := NewProjectCondition(tt.tokenPath, tt.minimumAmount)

			// Verify
			uassert.Equal(t, condition.TokenPath(), tt.expectedTokenPath)
			uassert.Equal(t, condition.MinimumAmount(), tt.expectedMinAmount)
		})
	}
}

func TestProjectCondition_NewProjectConditionsWithError(t *testing.T) {
	tests := []struct {
		name             string
		conditionTokens  string
		conditionAmounts string
		expectedCount    int
		expectedHasError bool
		expectedError    string
	}{
		{
			name:             "success with single condition",
			conditionTokens:  "gno.land/r/demo/gns",
			conditionAmounts: "1000",
			expectedCount:    1,
			expectedHasError: false,
		},
		{
			name:             "success with multiple conditions",
			conditionTokens:  "gno.land/r/demo/gns*PAD*gno.land/r/demo/usdc",
			conditionAmounts: "1000*PAD*2000",
			expectedCount:    2,
			expectedHasError: false,
		},
		{
			name:             "success with empty strings returns empty array",
			conditionTokens:  "",
			conditionAmounts: "",
			expectedCount:    0,
			expectedHasError: false,
		},
		{
			name:             "error when token and amount counts mismatch",
			conditionTokens:  "gno.land/r/demo/gns*PAD*gno.land/r/demo/usdc",
			conditionAmounts: "1000",
			expectedCount:    0,
			expectedHasError: true,
			expectedError:    "is not matched with condition token",
		},
		{
			name:             "error when amount is not valid integer",
			conditionTokens:  "gno.land/r/demo/gns",
			conditionAmounts: "invalid",
			expectedCount:    0,
			expectedHasError: true,
			expectedError:    "is not a valid integer",
		},
		{
			name:             "error when amount is negative",
			conditionTokens:  "gno.land/r/demo/gns",
			conditionAmounts: "-1000",
			expectedCount:    0,
			expectedHasError: true,
			expectedError:    "is not available",
		},
		{
			name:             "error when amount is zero",
			conditionTokens:  "gno.land/r/demo/gns",
			conditionAmounts: "0",
			expectedCount:    0,
			expectedHasError: true,
			expectedError:    "is not available",
		},
		{
			name:             "error when token path is empty",
			conditionTokens:  "",
			conditionAmounts: "1000",
			expectedCount:    0,
			expectedHasError: true,
			expectedError:    "is not available",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute
			conditions, err := NewProjectConditionsWithError(tt.conditionTokens, tt.conditionAmounts)

			// Verify
			if tt.expectedHasError {
				uassert.ErrorContains(t, err, tt.expectedError)
				uassert.True(t, conditions == nil)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, len(conditions), tt.expectedCount)
			}
		})
	}
}
