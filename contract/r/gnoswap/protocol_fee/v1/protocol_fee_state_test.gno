package v1

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/rbac" // Initialize contract roles
)

// Test helper functions

// newProtocolFeeStateInternal creates a new protocolFeeState instance for testing
// This returns the concrete type instead of the interface
func newProtocolFeeStateInternal(t *testing.T) *protocolFeeState {
	t.Helper()
	return &protocolFeeState{
		store: newMockProtocolFeeStore(),
	}
}

/* Main tests */

func TestProtocolFeeStateAddAccuToGovStaker(t *testing.T) {
	tests := []struct {
		name        string
		tokenPath   string
		amounts     []int64
		expectedSum int64
	}{
		{
			name:        "add single amount to new token",
			tokenPath:   "test_token",
			amounts:     []int64{100},
			expectedSum: 100,
		},
		{
			name:        "add multiple amounts to same token",
			tokenPath:   "test_token",
			amounts:     []int64{100, 50},
			expectedSum: 150,
		},
		{
			name:        "add zero amount",
			tokenPath:   "test_token",
			amounts:     []int64{0},
			expectedSum: 0,
		},
		{
			name:        "add multiple amounts including zero",
			tokenPath:   "test_token",
			amounts:     []int64{100, 0, 75},
			expectedSum: 175,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			pfs := newProtocolFeeStateInternal(t)

			// Initially should be 0
			uassert.Equal(t, pfs.GetAccuTransferToGovStakerByTokenPath(test.tokenPath), int64(0))

			// Add amounts sequentially
			for _, amount := range test.amounts {
				pfs.addAccuToGovStaker(test.tokenPath, amount)
			}

			// Check final sum
			uassert.Equal(t, pfs.GetAccuTransferToGovStakerByTokenPath(test.tokenPath), test.expectedSum)
		})
	}
}

func TestProtocolFeeStateAddAccuToDevOps(t *testing.T) {
	tests := []struct {
		name        string
		tokenPath   string
		amounts     []int64
		expectedSum int64
	}{
		{
			name:        "add single amount to new token",
			tokenPath:   "test_token",
			amounts:     []int64{200},
			expectedSum: 200,
		},
		{
			name:        "add multiple amounts to same token",
			tokenPath:   "test_token",
			amounts:     []int64{200, 75},
			expectedSum: 275,
		},
		{
			name:        "add zero amount",
			tokenPath:   "test_token",
			amounts:     []int64{0},
			expectedSum: 0,
		},
		{
			name:        "add large amounts",
			tokenPath:   "test_token",
			amounts:     []int64{1000, 2000, 3000},
			expectedSum: 6000,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			pfs := newProtocolFeeStateInternal(t)

			// Initially should be 0
			uassert.Equal(t, pfs.GetAccuTransferToDevOpsByTokenPath(test.tokenPath), int64(0))

			// Add amounts sequentially
			for _, amount := range test.amounts {
				pfs.addAccuToDevOps(test.tokenPath, amount)
			}

			// Check final sum
			uassert.Equal(t, pfs.GetAccuTransferToDevOpsByTokenPath(test.tokenPath), test.expectedSum)
		})
	}
}

func TestProtocolFeeStateSetDevOpsPct(t *testing.T) {
	tests := []struct {
		name        string
		percentage  int64
		shouldError bool
		errorMsg    string
		expectedPct int64
	}{
		{
			name:        "set valid percentage - 0%",
			percentage:  0,
			shouldError: false,
			expectedPct: 0,
		},
		{
			name:        "set valid percentage - 25%",
			percentage:  2500,
			shouldError: false,
			expectedPct: 2500,
		},
		{
			name:        "set valid percentage - 100%",
			percentage:  10000,
			shouldError: false,
			expectedPct: 10000,
		},
		{
			name:        "set invalid percentage - over 100%",
			percentage:  10001,
			shouldError: true,
			errorMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(10001) should not be bigger than 10000",
		},
		{
			name:        "set invalid percentage - very large",
			percentage:  50000,
			shouldError: true,
			errorMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(50000) should not be bigger than 10000",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			pfs := newProtocolFeeStateInternal(t)

			// Initially should be 0
			uassert.Equal(t, pfs.DevOpsPct(), int64(0))
			_, err := pfs.setDevOpsPct(test.percentage)

			if test.shouldError {
				uassert.Equal(t, err.Error(), test.errorMsg)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestProtocolFeeStateClearTokenListWithAmount(t *testing.T) {
	tests := []struct {
		name        string
		initialData map[string]int64
		expectedLen int
	}{
		{
			name:        "clear empty list",
			initialData: map[string]int64{},
			expectedLen: 0,
		},
		{
			name: "clear list with single token",
			initialData: map[string]int64{
				"token1": 100,
			},
			expectedLen: 0,
		},
		{
			name: "clear list with multiple tokens",
			initialData: map[string]int64{
				"token1": 100,
				"token2": 200,
				"token3": 300,
			},
			expectedLen: 0,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			pfs := newProtocolFeeStateInternal(t)

			// Setup initial data
			for token, amount := range test.initialData {
				pfs.store.SetTokenListWithAmountItem(token, amount)
			}

			// Verify initial state
			uassert.Equal(t, len(pfs.store.GetTokenListWithAmounts()), len(test.initialData))

			// Clear the list
			pfs.clearTokenListWithAmount()

			// Verify final state
			uassert.Equal(t, len(pfs.store.GetTokenListWithAmounts()), test.expectedLen)
		})
	}
}

func TestProtocolFeeStateUpdateDistributedToGovStakerHistory(t *testing.T) {
	tests := []struct {
		name        string
		tokenPath   string
		amounts     []int64
		expectedSum int64
	}{
		{
			name:        "update history with single amount",
			tokenPath:   "test_token",
			amounts:     []int64{100},
			expectedSum: 100,
		},
		{
			name:        "update history with multiple amounts",
			tokenPath:   "test_token",
			amounts:     []int64{100, 50},
			expectedSum: 150,
		},
		{
			name:        "update history with zero amount",
			tokenPath:   "test_token",
			amounts:     []int64{0},
			expectedSum: 0,
		},
		{
			name:        "update history multiple times",
			tokenPath:   "test_token",
			amounts:     []int64{25, 75, 100, 200},
			expectedSum: 400,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			pfs := newProtocolFeeStateInternal(t)

			// Update history sequentially
			for _, amount := range test.amounts {
				pfs.updateDistributedToGovStakerHistory(test.tokenPath, amount)
			}

			// Check if history was updated correctly
			historyValue, exists := pfs.store.GetDistributedToGovStakerHistory().Get(test.tokenPath)
			uassert.True(t, exists)
			uassert.Equal(t, historyValue.(int64), test.expectedSum)
		})
	}
}

func TestProtocolFeeStateUpdateDistributedToDevOpsHistory(t *testing.T) {
	tests := []struct {
		name        string
		tokenPath   string
		amounts     []int64
		expectedSum int64
	}{
		{
			name:        "update history with single amount",
			tokenPath:   "test_token",
			amounts:     []int64{200},
			expectedSum: 200,
		},
		{
			name:        "update history with multiple amounts",
			tokenPath:   "test_token",
			amounts:     []int64{200, 75},
			expectedSum: 275,
		},
		{
			name:        "update history with zero amount",
			tokenPath:   "test_token",
			amounts:     []int64{0},
			expectedSum: 0,
		},
		{
			name:        "update history multiple times",
			tokenPath:   "test_token",
			amounts:     []int64{50, 150, 300, 100},
			expectedSum: 600,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			pfs := newProtocolFeeStateInternal(t)

			// Update history sequentially
			for _, amount := range test.amounts {
				pfs.updateDistributedToDevOpsHistory(test.tokenPath, amount)
			}

			// Check if history was updated correctly
			historyValue, exists := pfs.store.GetDistributedToDevOpsHistory().Get(test.tokenPath)
			uassert.True(t, exists)
			uassert.Equal(t, historyValue.(int64), test.expectedSum)
		})
	}
}

func TestProtocolFeeState_SetDevOpsPct_NegativeValues(t *testing.T) {
	tests := []struct {
		name        string
		pct         int64
		shouldError bool
		errorMsg    string
	}{
		{
			name:        "error - negative percentage -1",
			pct:         -1,
			shouldError: true,
			errorMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(-1) should not be negative",
		},
		{
			name:        "error - large negative percentage",
			pct:         -9999,
			shouldError: true,
			errorMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(-9999) should not be negative",
		},
		{
			name:        "error - very large negative",
			pct:         -999999999,
			shouldError: true,
			errorMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(-999999999) should not be negative",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pfs := newProtocolFeeStateInternal(t)

			// When
			_, err := pfs.setDevOpsPct(tt.pct)

			// Then
			if tt.shouldError {
				uassert.Error(t, err)
				uassert.Equal(t, err.Error(), tt.errorMsg)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestProtocolFeeState_SetGovStakerPct_EdgeCases(t *testing.T) {
	tests := []struct {
		name           string
		pct            int64
		shouldError    bool
		errorMsg       string
		expectedDevOps int64
		expectedGovPct int64
	}{
		{
			name:        "error - negative percentage",
			pct:         -1,
			shouldError: true,
			errorMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(-1) should not be negative",
		},
		{
			name:        "error - very large negative",
			pct:         -999999,
			shouldError: true,
			errorMsg:    "[GNOSWAP-PROTOCOL_FEE-001] invalid percentage || pct(-999999) should not be negative",
		},
		{
			name:           "success - minimum boundary 0%",
			pct:            0,
			shouldError:    false,
			expectedDevOps: 10000,
			expectedGovPct: 0,
		},
		{
			name:           "success - maximum boundary 100%",
			pct:            10000,
			shouldError:    false,
			expectedDevOps: 0,
			expectedGovPct: 10000,
		},
		{
			name:           "success - middle value 50%",
			pct:            5000,
			shouldError:    false,
			expectedDevOps: 5000,
			expectedGovPct: 5000,
		},
		{
			name:           "success - 75%",
			pct:            7500,
			shouldError:    false,
			expectedDevOps: 2500,
			expectedGovPct: 7500,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pfs := newProtocolFeeStateInternal(t)

			// When
			resultPct, err := pfs.setGovStakerPct(tt.pct)

			// Then
			if tt.shouldError {
				uassert.Error(t, err)
				uassert.Equal(t, err.Error(), tt.errorMsg)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, resultPct, tt.expectedGovPct)
				uassert.Equal(t, pfs.DevOpsPct(), tt.expectedDevOps)
				uassert.Equal(t, pfs.GovStakerPct(), tt.expectedGovPct)
			}
		})
	}
}

func TestProtocolFeeState_AddAccuToGovStaker_Overflow(t *testing.T) {
	tests := []struct {
		name         string
		tokenPath    string
		initialValue int64
		addAmount    int64
		shouldPanic  bool
		panicMsg     string
	}{
		{
			name:         "error - overflow at boundary",
			tokenPath:    "test_token",
			initialValue: 9223372036854775806, // MAX_INT64 - 1
			addAmount:    2,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "error - overflow with large values",
			tokenPath:    "test_token",
			initialValue: 9223372036854775800,
			addAmount:    10,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "success - at exact boundary",
			tokenPath:    "test_token",
			initialValue: 9223372036854775806, // MAX_INT64 - 1
			addAmount:    1,
			shouldPanic:  false,
		},
		{
			name:         "success - normal addition",
			tokenPath:    "test_token",
			initialValue: 1000,
			addAmount:    500,
			shouldPanic:  false,
		},
		{
			name:         "success - zero initial value",
			tokenPath:    "test_token",
			initialValue: 0,
			addAmount:    100,
			shouldPanic:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pfs := newProtocolFeeStateInternal(t)
			if tt.initialValue > 0 {
				pfs.store.SetAccuToGovStakerItem(tt.tokenPath, tt.initialValue)
			}

			// When & Then
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.panicMsg, func() {
					pfs.addAccuToGovStaker(tt.tokenPath, tt.addAmount)
				})
			} else {
				pfs.addAccuToGovStaker(tt.tokenPath, tt.addAmount)
				expectedTotal := tt.initialValue + tt.addAmount
				uassert.Equal(t, pfs.GetAccuTransferToGovStakerByTokenPath(tt.tokenPath), expectedTotal)
			}
		})
	}
}

func TestProtocolFeeState_AddAccuToDevOps_Overflow(t *testing.T) {
	tests := []struct {
		name         string
		tokenPath    string
		initialValue int64
		addAmount    int64
		shouldPanic  bool
		panicMsg     string
	}{
		{
			name:         "error - overflow at boundary",
			tokenPath:    "test_token",
			initialValue: 9223372036854775806, // MAX_INT64 - 1
			addAmount:    2,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "error - overflow with large values",
			tokenPath:    "test_token",
			initialValue: 9223372036854775800,
			addAmount:    10,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "success - at exact boundary",
			tokenPath:    "test_token",
			initialValue: 9223372036854775806, // MAX_INT64 - 1
			addAmount:    1,
			shouldPanic:  false,
		},
		{
			name:         "success - normal addition",
			tokenPath:    "test_token",
			initialValue: 2000,
			addAmount:    800,
			shouldPanic:  false,
		},
		{
			name:         "success - zero initial value",
			tokenPath:    "test_token",
			initialValue: 0,
			addAmount:    500,
			shouldPanic:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pfs := newProtocolFeeStateInternal(t)
			if tt.initialValue > 0 {
				pfs.addAccuToDevOps(tt.tokenPath, tt.initialValue)
			}

			// When & Then
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.panicMsg, func() {
					pfs.addAccuToDevOps(tt.tokenPath, tt.addAmount)
				})
			} else {
				pfs.addAccuToDevOps(tt.tokenPath, tt.addAmount)
				expectedTotal := tt.initialValue + tt.addAmount
				uassert.Equal(t, pfs.GetAccuTransferToDevOpsByTokenPath(tt.tokenPath), expectedTotal)
			}
		})
	}
}

func TestProtocolFeeState_RetrieveAmount_NonExistentKey(t *testing.T) {
	tests := []struct {
		name        string
		tokenPath   string
		setupData   map[string]int64
		expectedAmt int64
	}{
		{
			name:        "non-existent key returns zero",
			tokenPath:   "non_existent_token",
			setupData:   map[string]int64{},
			expectedAmt: 0,
		},
		{
			name:      "existing key returns correct value",
			tokenPath: "test_token",
			setupData: map[string]int64{
				"test_token": 1000,
			},
			expectedAmt: 1000,
		},
		{
			name:      "different key returns zero",
			tokenPath: "different_token",
			setupData: map[string]int64{
				"test_token": 1000,
			},
			expectedAmt: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pfs := newProtocolFeeStateInternal(t)
			for token, amount := range tt.setupData {
				pfs.store.SetAccuToGovStakerItem(token, amount)
			}

			// When
			result := pfs.GetAccuTransferToGovStakerByTokenPath(tt.tokenPath)

			// Then
			uassert.Equal(t, result, tt.expectedAmt)
		})
	}
}

func TestProtocolFeeState_ClearTokenListWithAmount_MultipleTokens(t *testing.T) {
	tests := []struct {
		name        string
		initialData map[string]int64
	}{
		{
			name: "clear list with many tokens",
			initialData: map[string]int64{
				"token1": 100,
				"token2": 200,
				"token3": 300,
				"token4": 400,
				"token5": 500,
			},
		},
		{
			name: "clear list with large amounts",
			initialData: map[string]int64{
				"token1": 9223372036854775806,
				"token2": 9223372036854775805,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pfs := newProtocolFeeStateInternal(t)
			for token, amount := range tt.initialData {
				pfs.TokenListWithAmounts()[token] = amount
			}
			uassert.Equal(t, len(pfs.TokenListWithAmounts()), len(tt.initialData))

			// When
			pfs.clearTokenListWithAmount()

			// Then
			uassert.Equal(t, len(pfs.TokenListWithAmounts()), 0)

			// Verify all tokens were removed
			for token := range tt.initialData {
				_, exists := pfs.TokenListWithAmounts()[token]
				uassert.False(t, exists)
			}
		})
	}
}

func TestProtocolFeeState_UpdateDistributedHistory_Consecutive(t *testing.T) {
	tests := []struct {
		name              string
		tokenPath         string
		amounts           []int64
		expectedGovStaker int64
		expectedDevOps    int64
	}{
		{
			name:              "consecutive updates to both histories",
			tokenPath:         "test_token",
			amounts:           []int64{100, 200, 300},
			expectedGovStaker: 600,
			expectedDevOps:    600,
		},
		{
			name:              "single update",
			tokenPath:         "test_token",
			amounts:           []int64{1000},
			expectedGovStaker: 1000,
			expectedDevOps:    1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pfs := newProtocolFeeStateInternal(t)

			// When - update both histories
			for _, amount := range tt.amounts {
				pfs.updateDistributedToGovStakerHistory(tt.tokenPath, int64(amount))
				pfs.updateDistributedToDevOpsHistory(tt.tokenPath, int64(amount))
			}

			// Then - verify both histories
			govValue, govExists := pfs.store.GetDistributedToGovStakerHistoryItem(tt.tokenPath)
			uassert.True(t, govExists)
			uassert.Equal(t, govValue, tt.expectedGovStaker)

			devValue, devExists := pfs.store.GetDistributedToDevOpsHistoryItem(tt.tokenPath)
			uassert.True(t, devExists)
			uassert.Equal(t, devValue, tt.expectedDevOps)
		})
	}
}

func TestProtocolFeeState_DevOpsPct(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func() *protocolFeeState
		expected int64
	}{
		{
			name: "success - get default devOps percentage (0%)",
			setupFn: func() *protocolFeeState {
				return newProtocolFeeStateInternal(t)
			},
			expected: 0,
		},
		{
			name: "success - get custom devOps percentage (4000)",
			setupFn: func() *protocolFeeState {
				pfs := newProtocolFeeStateInternal(t)
				pfs.store.SetDevOpsPct(4000)
				return pfs
			},
			expected: 4000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pfs := tt.setupFn()
			result := pfs.DevOpsPct()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestProtocolFeeState_GovStakerPct(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func() *protocolFeeState
		expected int64
	}{
		{
			name: "success - get default govStaker percentage (100%)",
			setupFn: func() *protocolFeeState {
				return newProtocolFeeStateInternal(t)
			},
			expected: 10000,
		},
		{
			name: "success - get govStaker percentage when devOps is 4000",
			setupFn: func() *protocolFeeState {
				pfs := newProtocolFeeStateInternal(t)
				pfs.store.SetDevOpsPct(4000)
				return pfs
			},
			expected: 6000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pfs := tt.setupFn()
			result := pfs.GovStakerPct()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestProtocolFeeState_AccuToGovStaker(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func() *protocolFeeState
		verifyFn func(t *testing.T, tree *avl.Tree)
	}{
		{
			name: "success - get empty tree",
			setupFn: func() *protocolFeeState {
				return newProtocolFeeStateInternal(t)
			},
			verifyFn: func(t *testing.T, tree *avl.Tree) {
				uassert.NotNil(t, tree)
				uassert.Equal(t, tree.Size(), 0)
			},
		},
		{
			name: "success - get tree with data",
			setupFn: func() *protocolFeeState {
				pfs := newProtocolFeeStateInternal(t)
				pfs.store.SetAccuToGovStakerItem("token1", 1000)
				pfs.store.SetAccuToGovStakerItem("token2", 2000)
				return pfs
			},
			verifyFn: func(t *testing.T, tree *avl.Tree) {
				uassert.NotNil(t, tree)
				uassert.Equal(t, tree.Size(), 2)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pfs := tt.setupFn()
			tree := pfs.AccuToGovStaker()
			tt.verifyFn(t, tree)
		})
	}
}

func TestProtocolFeeState_AccuToDevOps(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func() *protocolFeeState
		verifyFn func(t *testing.T, tree *avl.Tree)
	}{
		{
			name: "success - get empty tree",
			setupFn: func() *protocolFeeState {
				return newProtocolFeeStateInternal(t)
			},
			verifyFn: func(t *testing.T, tree *avl.Tree) {
				uassert.NotNil(t, tree)
				uassert.Equal(t, tree.Size(), 0)
			},
		},
		{
			name: "success - get tree with data",
			setupFn: func() *protocolFeeState {
				pfs := newProtocolFeeStateInternal(t)
				pfs.store.SetAccuToDevOpsItem("token1", 500)
				pfs.store.SetAccuToDevOpsItem("token2", 1500)
				return pfs
			},
			verifyFn: func(t *testing.T, tree *avl.Tree) {
				uassert.NotNil(t, tree)
				uassert.Equal(t, tree.Size(), 2)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pfs := tt.setupFn()
			tree := pfs.AccuToDevOps()
			tt.verifyFn(t, tree)
		})
	}
}

func TestProtocolFeeState_GetAccuTransferToGovStakerByTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		setupFn   func() *protocolFeeState
		tokenPath string
		expected  int64
	}{
		{
			name: "success - get existing token",
			setupFn: func() *protocolFeeState {
				pfs := newProtocolFeeStateInternal(t)
				pfs.store.SetAccuToGovStakerItem("token1", 3000)
				return pfs
			},
			tokenPath: "token1",
			expected:  3000,
		},
		{
			name: "success - get non-existing token returns 0",
			setupFn: func() *protocolFeeState {
				return newProtocolFeeStateInternal(t)
			},
			tokenPath: "nonexistent",
			expected:  0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pfs := tt.setupFn()
			result := pfs.GetAccuTransferToGovStakerByTokenPath(tt.tokenPath)
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestProtocolFeeState_GetAccuTransferToDevOpsByTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		setupFn   func() *protocolFeeState
		tokenPath string
		expected  int64
	}{
		{
			name: "success - get existing token",
			setupFn: func() *protocolFeeState {
				pfs := newProtocolFeeStateInternal(t)
				pfs.store.SetAccuToDevOpsItem("token1", 1200)
				return pfs
			},
			tokenPath: "token1",
			expected:  1200,
		},
		{
			name: "success - get non-existing token returns 0",
			setupFn: func() *protocolFeeState {
				return newProtocolFeeStateInternal(t)
			},
			tokenPath: "nonexistent",
			expected:  0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pfs := tt.setupFn()
			result := pfs.GetAccuTransferToDevOpsByTokenPath(tt.tokenPath)
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestNewProtocolFeeStateBy(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func() protocol_fee.IProtocolFeeStore
		verifyFn func(t *testing.T, pfs *protocolFeeState)
	}{
		{
			name: "success - create state with new store",
			setupFn: func() protocol_fee.IProtocolFeeStore {
				return newMockProtocolFeeStore()
			},
			verifyFn: func(t *testing.T, pfs *protocolFeeState) {
				uassert.NotNil(t, pfs)
				uassert.NotNil(t, pfs.store)
				uassert.Equal(t, pfs.DevOpsPct(), int64(0))
				uassert.Equal(t, pfs.GovStakerPct(), int64(10000))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := tt.setupFn()
			pfs := NewProtocolFeeStateBy(store)
			tt.verifyFn(t, pfs)
		})
	}
}
