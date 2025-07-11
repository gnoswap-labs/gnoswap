package staker

import (
	"std"
	"strings"
	"testing"
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/testutils"
)

func TestGetDelegateHistoryOf(t *testing.T) {
	delegator1 := testutils.TestAddress("delegator1")
	delegator2 := testutils.TestAddress("delegator2")
	invalidAddress := std.Address("")
	delegatee1 := testutils.TestAddress("delegatee1")
	delegatee2 := testutils.TestAddress("delegatee2")

	ts1 := uint64(time.Now().Unix()) - 1000
	ts2 := uint64(time.Now().Unix()) - 500
	ts3 := uint64(time.Now().Unix()) - 100
	height1 := uint64(100)
	height2 := uint64(200)
	height3 := uint64(300)

	tests := []struct {
		name           string
		historyState   *HistoryState
		delegator      std.Address
		expectedResult []DelegationHistory
		expectPanic    bool
		panicMessage   string
		description    string
	}{
		{
			name:           "empty delegation history",
			historyState:   NewHistoryState(),
			delegator:      delegator1,
			expectedResult: []DelegationHistory{},
			expectPanic:    false,
			description:    "should return empty slice when no delegation history exists",
		},
		{
			name: "single delegation history entry",
			historyState: &HistoryState{
				delegationHistory: HistoryMap{
					delegator1.String(): []DelegationHistory{
						{
							to:        delegatee1,
							amount:    1000,
							timestamp: ts1,
							height:    height1,
							add:       true,
						},
					},
				},
			},
			delegator: delegator1,
			expectedResult: []DelegationHistory{
				{
					to:        delegatee1,
					amount:    1000,
					timestamp: ts1,
					height:    height1,
					add:       true,
				},
			},
			expectPanic: false,
			description: "should return single delegation history entry",
		},
		{
			name: "multiple delegation history entries",
			historyState: &HistoryState{
				delegationHistory: HistoryMap{
					delegator1.String(): []DelegationHistory{
						{
							to:        delegatee1,
							amount:    1000,
							timestamp: ts1,
							height:    height1,
							add:       true,
						},
						{
							to:        delegatee2,
							amount:    2000,
							timestamp: ts2,
							height:    height2,
							add:       true,
						},
						{
							to:        delegatee1,
							amount:    500,
							timestamp: ts3,
							height:    height3,
							add:       false,
						},
					},
				},
			},
			delegator: delegator1,
			expectedResult: []DelegationHistory{
				{
					to:        delegatee1,
					amount:    1000,
					timestamp: ts1,
					height:    height1,
					add:       true,
				},
				{
					to:        delegatee2,
					amount:    2000,
					timestamp: ts2,
					height:    height2,
					add:       true,
				},
				{
					to:        delegatee1,
					amount:    500,
					timestamp: ts3,
					height:    height3,
					add:       false,
				},
			},
			expectPanic: false,
			description: "should return multiple delegation history entries in order",
		},
		{
			name: "delegation history with zero amount",
			historyState: &HistoryState{
				delegationHistory: HistoryMap{
					delegator1.String(): []DelegationHistory{
						{
							to:        delegatee1,
							amount:    0,
							timestamp: ts1,
							height:    height1,
							add:       true,
						},
					},
				},
			},
			delegator: delegator1,
			expectedResult: []DelegationHistory{
				{
					to:        delegatee1,
					amount:    0,
					timestamp: ts1,
					height:    height1,
					add:       true,
				},
			},
			expectPanic: false,
			description: "should return delegation history with zero amount",
		},
		{
			name: "delegation history with large amount",
			historyState: &HistoryState{
				delegationHistory: HistoryMap{
					delegator1.String(): []DelegationHistory{
						{
							to:        delegatee1,
							amount:    999999999,
							timestamp: ts1,
							height:    height1,
							add:       true,
						},
					},
				},
			},
			delegator: delegator1,
			expectedResult: []DelegationHistory{
				{
					to:        delegatee1,
					amount:    999999999,
					timestamp: ts1,
					height:    height1,
					add:       true,
				},
			},
			expectPanic: false,
			description: "should return delegation history with large amount",
		},
		{
			name: "delegation history with both add and remove operations",
			historyState: &HistoryState{
				delegationHistory: HistoryMap{
					delegator1.String(): []DelegationHistory{
						{
							to:        delegatee1,
							amount:    1000,
							timestamp: ts1,
							height:    height1,
							add:       true,
						},
						{
							to:        delegatee1,
							amount:    500,
							timestamp: ts2,
							height:    height2,
							add:       false,
						},
						{
							to:        delegatee1,
							amount:    300,
							timestamp: ts3,
							height:    height3,
							add:       true,
						},
					},
				},
			},
			delegator: delegator1,
			expectedResult: []DelegationHistory{
				{
					to:        delegatee1,
					amount:    1000,
					timestamp: ts1,
					height:    height1,
					add:       true,
				},
				{
					to:        delegatee1,
					amount:    500,
					timestamp: ts2,
					height:    height2,
					add:       false,
				},
				{
					to:        delegatee1,
					amount:    300,
					timestamp: ts3,
					height:    height3,
					add:       true,
				},
			},
			expectPanic: false,
			description: "should return delegation history with both add and remove operations",
		},
		{
			name: "delegation history for different delegator",
			historyState: &HistoryState{
				delegationHistory: HistoryMap{
					delegator1.String(): []DelegationHistory{
						{
							to:        delegatee1,
							amount:    1000,
							timestamp: ts1,
							height:    height1,
							add:       true,
						},
					},
					delegator2.String(): []DelegationHistory{
						{
							to:        delegatee2,
							amount:    2000,
							timestamp: ts2,
							height:    height2,
							add:       true,
						},
					},
				},
			},
			delegator: delegator2,
			expectedResult: []DelegationHistory{
				{
					to:        delegatee2,
					amount:    2000,
					timestamp: ts2,
					height:    height2,
					add:       true,
				},
			},
			expectPanic: false,
			description: "should return delegation history for specific delegator only",
		},
		{
			name: "invalid delegator address",
			historyState: &HistoryState{
				delegationHistory: make(HistoryMap),
			},
			delegator:    invalidAddress,
			expectPanic:  true,
			panicMessage: "invalid delegator address",
			description:  "should panic with invalid delegator address",
		},
		{
			name: "delegation history with same delegatee multiple times",
			historyState: &HistoryState{
				delegationHistory: HistoryMap{
					delegator1.String(): []DelegationHistory{
						{
							to:        delegatee1,
							amount:    1000,
							timestamp: ts1,
							height:    height1,
							add:       true,
						},
						{
							to:        delegatee1,
							amount:    500,
							timestamp: ts2,
							height:    height2,
							add:       true,
						},
						{
							to:        delegatee1,
							amount:    200,
							timestamp: ts3,
							height:    height3,
							add:       false,
						},
					},
				},
			},
			delegator: delegator1,
			expectedResult: []DelegationHistory{
				{
					to:        delegatee1,
					amount:    1000,
					timestamp: ts1,
					height:    height1,
					add:       true,
				},
				{
					to:        delegatee1,
					amount:    500,
					timestamp: ts2,
					height:    height2,
					add:       true,
				},
				{
					to:        delegatee1,
					amount:    200,
					timestamp: ts3,
					height:    height3,
					add:       false,
				},
			},
			expectPanic: false,
			description: "should return delegation history with same delegatee multiple times",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				defer func() {
					r := recover()
					if r == nil {
						t.Errorf("expected panic but none occurred")
						return
					}
					panicStr := ufmt.Sprintf("%v", r)
					if !strings.Contains(panicStr, tt.panicMessage) {
						t.Errorf("expected panic to contain '%s', got '%s'", tt.panicMessage, panicStr)
					}
				}()
			}

			// mock the history state
			historyState.DelegationHistory()[tt.delegator.String()] = tt.historyState.DelegationHistory()[tt.delegator.String()]
			defer func() {
				historyState.DelegationHistory()[tt.delegator.String()] = nil
			}()

			result := GetDelegateHistoryOf(tt.delegator)

			if !tt.expectPanic {
				uassert.Equal(t, len(tt.expectedResult), len(result), "history length mismatch")

				for i, expected := range tt.expectedResult {
					if i >= len(result) {
						t.Errorf("expected history entry at index %d but none found", i)
						continue
					}

					actual := result[i]
					uassert.Equal(t, expected.to, actual.to)
					uassert.Equal(t, expected.amount, actual.amount)
					uassert.Equal(t, expected.timestamp, actual.timestamp)
					uassert.Equal(t, expected.height, actual.height)
					uassert.Equal(t, expected.add, actual.add)
				}
			}
		})
	}
}

func TestGetDelegationSnapShotHistoryOf(t *testing.T) {
	delegator1 := testutils.TestAddress("delegator1")
	delegator2 := testutils.TestAddress("delegator2")
	invalidAddress := std.Address("")

	ts1 := uint64(time.Now().Unix()) - 1000
	ts2 := uint64(time.Now().Unix()) - 500
	ts3 := uint64(time.Now().Unix()) - 100
	height1 := uint64(100)
	height2 := uint64(200)
	height3 := uint64(300)

	tests := []struct {
		name           string
		historyState   *HistoryState
		delegator      std.Address
		expectedResult []DelegationSnapShotHistory
		expectPanic    bool
		panicMessage   string
		description    string
	}{
		{
			name:           "empty snapshot history",
			historyState:   NewHistoryState(),
			delegator:      delegator1,
			expectedResult: []DelegationSnapShotHistory{},
			expectPanic:    false,
			description:    "should return empty slice when no snapshot history exists",
		},
		{
			name: "single snapshot history entry",
			historyState: &HistoryState{
				snapshotHistory: SnapShotMap{
					delegator1.String(): []DelegationSnapShotHistory{
						{
							to:           delegator1,
							amount:       1000,
							updatedBlock: height1,
							updatedAt:    ts1,
						},
					},
				},
			},
			delegator: delegator1,
			expectedResult: []DelegationSnapShotHistory{
				{
					to:           delegator1,
					amount:       1000,
					updatedBlock: height1,
					updatedAt:    ts1,
				},
			},
			expectPanic: false,
			description: "should return single snapshot history entry",
		},
		{
			name: "multiple snapshot history entries",
			historyState: &HistoryState{
				snapshotHistory: SnapShotMap{
					delegator1.String(): []DelegationSnapShotHistory{
						{
							to:           delegator1,
							amount:       500,
							updatedBlock: height1,
							updatedAt:    ts1,
						},
						{
							to:           delegator1,
							amount:       1000,
							updatedBlock: height2,
							updatedAt:    ts2,
						},
						{
							to:           delegator1,
							amount:       1500,
							updatedBlock: height3,
							updatedAt:    ts3,
						},
					},
				},
			},
			delegator: delegator1,
			expectedResult: []DelegationSnapShotHistory{
				{
					to:           delegator1,
					amount:       500,
					updatedBlock: height1,
					updatedAt:    ts1,
				},
				{
					to:           delegator1,
					amount:       1000,
					updatedBlock: height2,
					updatedAt:    ts2,
				},
				{
					to:           delegator1,
					amount:       1500,
					updatedBlock: height3,
					updatedAt:    ts3,
				},
			},
			expectPanic: false,
			description: "should return multiple snapshot history entries in order",
		},
		{
			name: "snapshot history with zero amount",
			historyState: &HistoryState{
				snapshotHistory: SnapShotMap{
					delegator1.String(): []DelegationSnapShotHistory{
						{
							to:           delegator1,
							amount:       0,
							updatedBlock: height1,
							updatedAt:    ts1,
						},
					},
				},
			},
			delegator: delegator1,
			expectedResult: []DelegationSnapShotHistory{
				{
					to:           delegator1,
					amount:       0,
					updatedBlock: height1,
					updatedAt:    ts1,
				},
			},
			expectPanic: false,
			description: "should return snapshot history with zero amount",
		},
		{
			name: "snapshot history with large amount",
			historyState: &HistoryState{
				snapshotHistory: SnapShotMap{
					delegator1.String(): []DelegationSnapShotHistory{
						{
							to:           delegator1,
							amount:       999999999,
							updatedBlock: height1,
							updatedAt:    ts1,
						},
					},
				},
			},
			delegator: delegator1,
			expectedResult: []DelegationSnapShotHistory{
				{
					to:           delegator1,
					amount:       999999999,
					updatedBlock: height1,
					updatedAt:    ts1,
				},
			},
			expectPanic: false,
			description: "should return snapshot history with large amount",
		},
		{
			name: "snapshot history with decreasing amounts",
			historyState: &HistoryState{
				snapshotHistory: SnapShotMap{
					delegator1.String(): []DelegationSnapShotHistory{
						{
							to:           delegator1,
							amount:       1000,
							updatedBlock: height1,
							updatedAt:    ts1,
						},
						{
							to:           delegator1,
							amount:       500,
							updatedBlock: height2,
							updatedAt:    ts2,
						},
						{
							to:           delegator1,
							amount:       0,
							updatedBlock: height3,
							updatedAt:    ts3,
						},
					},
				},
			},
			delegator: delegator1,
			expectedResult: []DelegationSnapShotHistory{
				{
					to:           delegator1,
					amount:       1000,
					updatedBlock: height1,
					updatedAt:    ts1,
				},
				{
					to:           delegator1,
					amount:       500,
					updatedBlock: height2,
					updatedAt:    ts2,
				},
				{
					to:           delegator1,
					amount:       0,
					updatedBlock: height3,
					updatedAt:    ts3,
				},
			},
			expectPanic: false,
			description: "should return snapshot history with decreasing amounts",
		},
		{
			name: "snapshot history for different delegator",
			historyState: &HistoryState{
				snapshotHistory: SnapShotMap{
					delegator1.String(): []DelegationSnapShotHistory{
						{
							to:           delegator1,
							amount:       1000,
							updatedBlock: height1,
							updatedAt:    ts1,
						},
					},
					delegator2.String(): []DelegationSnapShotHistory{
						{
							to:           delegator2,
							amount:       2000,
							updatedBlock: height2,
							updatedAt:    ts2,
						},
					},
				},
			},
			delegator: delegator2,
			expectedResult: []DelegationSnapShotHistory{
				{
					to:           delegator2,
					amount:       2000,
					updatedBlock: height2,
					updatedAt:    ts2,
				},
			},
			expectPanic: false,
			description: "should return snapshot history for specific delegator only",
		},
		{
			name:         "invalid delegator address",
			historyState: NewHistoryState(),
			delegator:    invalidAddress,
			expectPanic:  true,
			panicMessage: "invalid delegator address",
			description:  "should panic with invalid delegator address",
		},
		{
			name: "snapshot history with fluctuating amounts",
			historyState: &HistoryState{
				snapshotHistory: SnapShotMap{
					delegator1.String(): []DelegationSnapShotHistory{
						{
							to:           delegator1,
							amount:       1000,
							updatedBlock: height1,
							updatedAt:    ts1,
						},
						{
							to:           delegator1,
							amount:       500,
							updatedBlock: height2,
							updatedAt:    ts2,
						},
						{
							to:           delegator1,
							amount:       1200,
							updatedBlock: height3,
							updatedAt:    ts3,
						},
					},
				},
			},
			delegator: delegator1,
			expectedResult: []DelegationSnapShotHistory{
				{
					to:           delegator1,
					amount:       1000,
					updatedBlock: height1,
					updatedAt:    ts1,
				},
				{
					to:           delegator1,
					amount:       500,
					updatedBlock: height2,
					updatedAt:    ts2,
				},
				{
					to:           delegator1,
					amount:       1200,
					updatedBlock: height3,
					updatedAt:    ts3,
				},
			},
			expectPanic: false,
			description: "should return snapshot history with fluctuating amounts",
		},
		{
			name: "snapshot history with same timestamp",
			historyState: &HistoryState{
				snapshotHistory: SnapShotMap{
					delegator1.String(): []DelegationSnapShotHistory{
						{
							to:           delegator1,
							amount:       1000,
							updatedBlock: height1,
							updatedAt:    ts1,
						},
						{
							to:           delegator1,
							amount:       2000,
							updatedBlock: height2,
							updatedAt:    ts1, // Same timestamp
						},
					},
				},
			},
			delegator: delegator1,
			expectedResult: []DelegationSnapShotHistory{
				{
					to:           delegator1,
					amount:       1000,
					updatedBlock: height1,
					updatedAt:    ts1,
				},
				{
					to:           delegator1,
					amount:       2000,
					updatedBlock: height2,
					updatedAt:    ts1,
				},
			},
			expectPanic: false,
			description: "should return snapshot history with same timestamp",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				defer func() {
					r := recover()
					if r == nil {
						t.Errorf("expected panic but none occurred")
						return
					}
					panicStr := ufmt.Sprintf("%v", r)
					if !strings.Contains(panicStr, tt.panicMessage) {
						t.Errorf("expected panic to contain '%s', got '%s'", tt.panicMessage, panicStr)
					}
				}()
			}

			// mock the history state
			historyState.SnapshotHistory()[tt.delegator.String()] = tt.historyState.SnapshotHistory()[tt.delegator.String()]
			defer func() {
				historyState.SnapshotHistory()[tt.delegator.String()] = nil
			}()

			result := GetDelegationSnapShotHistoryOf(tt.delegator)

			if !tt.expectPanic {
				uassert.Equal(t, len(tt.expectedResult), len(result), "snapshot history length mismatch")

				for i, expected := range tt.expectedResult {
					if i >= len(result) {
						t.Errorf("expected snapshot entry at index %d but none found", i)
						continue
					}

					actual := result[i]
					uassert.Equal(t, expected.to, actual.to)
					uassert.Equal(t, expected.amount, actual.amount)
					uassert.Equal(t, expected.updatedBlock, actual.updatedBlock)
					uassert.Equal(t, expected.updatedAt, actual.updatedAt)
				}
			}
		})
	}
}
