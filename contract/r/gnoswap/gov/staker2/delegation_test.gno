package staker2

import (
	"std"
	"strings"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
)

func TestApplyDelegationChange(t *testing.T) {
	tests := []struct {
		name          string
		initialState  *State
		record        DelegationRecord
		add           bool
		expectedState *State
		description   string
	}{
		{
			name: "add delegation - new delegator and delegatee",
			initialState: &State{
				totalDelegated:  0,
				delegatorAmount: make(AmountMap),
				delegatedFromTo: make(FromToMap),
				delegatedTo:     make(AmountMap),
			},
			record: DelegationRecord{
				Delegator: "alice",
				Delegatee: "bob",
				Amount:    1000,
			},
			add: true,
			expectedState: &State{
				totalDelegated: 0, // Note: totalDelegated is not updated in the function
				delegatorAmount: AmountMap{
					"alice": 1000,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"bob": 1000,
					},
				},
				delegatedTo: AmountMap{
					"bob": 1000,
				},
			},
			description: "should add delegation for new delegator and delegatee",
		},
		{
			name: "add delegation - existing delegator, new delegatee",
			initialState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 500,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"charlie": 500,
					},
				},
				delegatedTo: AmountMap{
					"charlie": 500,
				},
			},
			record: DelegationRecord{
				Delegator: "alice",
				Delegatee: "bob",
				Amount:    1000,
			},
			add: true,
			expectedState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 1500,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"charlie": 500,
						"bob":     1000,
					},
				},
				delegatedTo: AmountMap{
					"charlie": 500,
					"bob":     1000,
				},
			},
			description: "should add delegation to existing delegator with new delegatee",
		},
		{
			name: "add delegation - existing delegator and delegatee",
			initialState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 500,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"bob": 500,
					},
				},
				delegatedTo: AmountMap{
					"bob": 500,
				},
			},
			record: DelegationRecord{
				Delegator: "alice",
				Delegatee: "bob",
				Amount:    1000,
			},
			add: true,
			expectedState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 1500,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"bob": 1500,
					},
				},
				delegatedTo: AmountMap{
					"bob": 1500,
				},
			},
			description: "should add delegation to existing delegator and delegatee",
		},
		{
			name: "remove delegation - sufficient amount",
			initialState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 1000,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"bob": 1000,
					},
				},
				delegatedTo: AmountMap{
					"bob": 1000,
				},
			},
			record: DelegationRecord{
				Delegator: "alice",
				Delegatee: "bob",
				Amount:    600,
			},
			add: false,
			expectedState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 400,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"bob": 400,
					},
				},
				delegatedTo: AmountMap{
					"bob": 400,
				},
			},
			description: "should remove delegation with sufficient amount",
		},
		{
			name: "remove delegation - exact amount",
			initialState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 1000,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"bob": 1000,
					},
				},
				delegatedTo: AmountMap{
					"bob": 1000,
				},
			},
			record: DelegationRecord{
				Delegator: "alice",
				Delegatee: "bob",
				Amount:    1000,
			},
			add: false,
			expectedState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 0,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{},
				},
				delegatedTo: AmountMap{
					"bob": 0,
				},
			},
			description: "should remove delegation with exact amount",
		},
		{
			name: "remove delegation - insufficient amount, delegator amount becomes 0",
			initialState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 500,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"bob": 500,
					},
				},
				delegatedTo: AmountMap{
					"bob": 500,
				},
			},
			record: DelegationRecord{
				Delegator: "alice",
				Delegatee: "bob",
				Amount:    1000,
			},
			add: false,
			expectedState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 0,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{},
				},
				delegatedTo: AmountMap{
					"bob": 0,
				},
			},
			description: "should set delegator amount to 0 when removing more than available",
		},
		{
			name: "remove delegation - insufficient amount, delegatee amount becomes 0",
			initialState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 500,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"bob": 500,
					},
				},
				delegatedTo: AmountMap{
					"bob": 500,
				},
			},
			record: DelegationRecord{
				Delegator: "alice",
				Delegatee: "bob",
				Amount:    1000,
			},
			add: false,
			expectedState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 0,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{},
				},
				delegatedTo: AmountMap{
					"bob": 0,
				},
			},
			description: "should set delegatee amount to 0 when removing more than available",
		},
		{
			name: "remove delegation - non-existent delegator",
			initialState: &State{
				totalDelegated:  0,
				delegatorAmount: make(AmountMap),
				delegatedFromTo: make(FromToMap),
				delegatedTo:     make(AmountMap),
			},
			record: DelegationRecord{
				Delegator: "alice",
				Delegatee: "bob",
				Amount:    1000,
			},
			add: false,
			expectedState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 0,
				},
				delegatedFromTo: FromToMap{},
				delegatedTo:     AmountMap{},
			},
			description: "should handle non-existent delegator gracefully",
		},
		{
			name: "remove delegation - multiple delegations to same delegatee",
			initialState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 1500,
					"bob":   1000,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"charlie": 1500,
					},
					"bob": AmountMap{
						"charlie": 1000,
					},
				},
				delegatedTo: AmountMap{
					"charlie": 2500,
				},
			},
			record: DelegationRecord{
				Delegator: "alice",
				Delegatee: "charlie",
				Amount:    1000,
			},
			add: false,
			expectedState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 500,
					"bob":   1000,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"charlie": 500,
					},
					"bob": AmountMap{
						"charlie": 1000,
					},
				},
				delegatedTo: AmountMap{
					"charlie": 1500,
				},
			},
			description: "should handle multiple delegations to same delegatee correctly",
		},
		{
			name: "remove delegation - zero amount",
			initialState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 1000,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"bob": 1000,
					},
				},
				delegatedTo: AmountMap{
					"bob": 1000,
				},
			},
			record: DelegationRecord{
				Delegator: "alice",
				Delegatee: "bob",
				Amount:    0,
			},
			add: false,
			expectedState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 1000,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"bob": 1000,
					},
				},
				delegatedTo: AmountMap{
					"bob": 1000,
				},
			},
			description: "should handle zero amount removal gracefully",
		},
		{
			name: "add delegation - zero amount",
			initialState: &State{
				totalDelegated:  0,
				delegatorAmount: make(AmountMap),
				delegatedFromTo: make(FromToMap),
				delegatedTo:     make(AmountMap),
			},
			record: DelegationRecord{
				Delegator: "alice",
				Delegatee: "bob",
				Amount:    0,
			},
			add: true,
			expectedState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					"alice": 0,
				},
				delegatedFromTo: FromToMap{
					"alice": AmountMap{
						"bob": 0,
					},
				},
				delegatedTo: AmountMap{
					"bob": 0,
				},
			},
			description: "should handle zero amount addition gracefully",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create a copy of the initial state to avoid modifying the test data
			initialState := &State{
				totalDelegated:  tt.initialState.totalDelegated,
				delegatorAmount: make(AmountMap),
				delegatedFromTo: make(FromToMap),
				delegatedTo:     make(AmountMap),
			}

			// Copy maps to avoid reference issues
			for k, v := range tt.initialState.delegatorAmount {
				initialState.delegatorAmount[k] = v
			}
			for k, v := range tt.initialState.delegatedFromTo {
				initialState.delegatedFromTo[k] = make(AmountMap)
				for k2, v2 := range v {
					initialState.delegatedFromTo[k][k2] = v2
				}
			}
			for k, v := range tt.initialState.delegatedTo {
				initialState.delegatedTo[k] = v
			}

			// Apply the delegation change
			result := applyDelegationChange(initialState, tt.record, tt.add)

			// Verify delegatorAmount
			for delegator, expectedAmount := range tt.expectedState.delegatorAmount {
				actualAmount, exists := result.delegatorAmount[delegator]
				uassert.True(t, exists, "delegator %s should exist in result", delegator)
				uassert.Equal(t, expectedAmount, actualAmount, "delegator amount mismatch for %s", delegator)
			}

			// Verify delegatedFromTo
			for delegator, expectedDelegations := range tt.expectedState.delegatedFromTo {
				actualDelegations, exists := result.delegatedFromTo[delegator]
				uassert.True(t, exists, "delegator %s should exist in delegatedFromTo", delegator)
				for delegatee, expectedAmount := range expectedDelegations {
					actualAmount, exists := actualDelegations[delegatee]
					uassert.True(t, exists, "delegatee %s should exist for delegator %s", delegatee, delegator)
					uassert.Equal(t, expectedAmount, actualAmount, "delegation amount mismatch for %s -> %s", delegator, delegatee)
				}
			}

			// Verify delegatedTo
			for delegatee, expectedAmount := range tt.expectedState.delegatedTo {
				actualAmount, exists := result.delegatedTo[delegatee]
				uassert.True(t, exists, "delegatee %s should exist in delegatedTo", delegatee)
				uassert.Equal(t, expectedAmount, actualAmount, "delegatee total amount mismatch for %s", delegatee)
			}

			// Verify that the function returns the same state pointer
			if initialState != result {
				t.Errorf("function should return the same state pointer")
			}
		})
	}
}

// TestAppendDelegationHistory tests the appendDelegationHistory function
func TestAppendDelegationHistory(t *testing.T) {
	t.Run("should append delegation history for valid addresses", func(t *testing.T) {
		st := NewState()
		from := testutils.TestAddress("from")
		to := testutils.TestAddress("to")
		amount := uint64(1000)

		err := appendDelegationHistory(st, from, to, amount, true)

		uassert.NoError(t, err)
		uassert.True(t, len(st.delegationHistory) > 0)

		fromStr := from.String()
		history := st.delegationHistory[fromStr]
		uassert.Equal(t, 1, len(history))

		// Verify history entry
		entry := history[0]
		uassert.Equal(t, to, entry.to)
		uassert.Equal(t, amount, entry.amount)
		uassert.True(t, entry.timestamp > 0)
		uassert.True(t, entry.height > 0)
		uassert.True(t, entry.add)
	})

	t.Run("should append multiple delegation histories", func(t *testing.T) {
		st := NewState()
		from := testutils.TestAddress("from")
		to1 := testutils.TestAddress("to1")
		to2 := testutils.TestAddress("to2")

		// Add first delegation
		err1 := appendDelegationHistory(st, from, to1, 1000, true)
		uassert.NoError(t, err1)

		// Add second delegation
		err2 := appendDelegationHistory(st, from, to2, 2000, false)
		uassert.NoError(t, err2)

		fromStr := from.String()
		history := st.delegationHistory[fromStr]
		uassert.Equal(t, 2, len(history))

		// Verify first entry
		uassert.Equal(t, to1, history[0].to)
		uassert.Equal(t, uint64(1000), history[0].amount)
		uassert.True(t, history[0].add)

		// Verify second entry
		uassert.Equal(t, to2, history[1].to)
		uassert.Equal(t, uint64(2000), history[1].amount)
		uassert.False(t, history[1].add)
	})
}

// TestUpdateDelegationSnapShotHistory tests the updateDelegationSnapShotHistory function
func TestUpdateDelegationSnapShotHistory(t *testing.T) {
	t.Run("should create new snapshot for first delegation", func(t *testing.T) {
		st := NewState()
		to := testutils.TestAddress("to")
		amount := uint64(1000)

		err := updateDelegationSnapShotHistory(st, to, amount, true)

		uassert.NoError(t, err)
		toStr := to.String()
		snapshots := st.snapShotHistory[toStr]
		uassert.Equal(t, 1, len(snapshots))

		// Verify snapshot entry
		snapshot := snapshots[0]
		uassert.Equal(t, to, snapshot.to)
		uassert.Equal(t, amount, snapshot.amount)
		uassert.True(t, snapshot.updatedBlock > 0)
		uassert.True(t, snapshot.updatedAt > 0)
	})

	t.Run("should update existing snapshot when adding delegation", func(t *testing.T) {
		st := NewState()
		to := testutils.TestAddress("to")

		// Add first delegation
		err1 := updateDelegationSnapShotHistory(st, to, 1000, true)
		uassert.NoError(t, err1)

		// Add second delegation
		err2 := updateDelegationSnapShotHistory(st, to, 2000, true)
		uassert.NoError(t, err2)

		toStr := to.String()
		snapshots := st.snapShotHistory[toStr]
		uassert.Equal(t, 2, len(snapshots))

		// Verify first snapshot
		uassert.Equal(t, uint64(1000), snapshots[0].amount)

		// Verify second snapshot (accumulated)
		uassert.Equal(t, uint64(3000), snapshots[1].amount)
	})

	t.Run("should update existing snapshot when removing delegation", func(t *testing.T) {
		st := NewState()
		to := testutils.TestAddress("to")

		// Add initial delegation
		err1 := updateDelegationSnapShotHistory(st, to, 5000, true)
		uassert.NoError(t, err1)

		// Remove some delegation
		err2 := updateDelegationSnapShotHistory(st, to, 2000, false)
		uassert.NoError(t, err2)

		toStr := to.String()
		snapshots := st.snapShotHistory[toStr]
		uassert.Equal(t, 2, len(snapshots))

		// Verify first snapshot
		uassert.Equal(t, uint64(5000), snapshots[0].amount)

		// Verify second snapshot (reduced)
		uassert.Equal(t, uint64(3000), snapshots[1].amount)
	})

	t.Run("should handle removal that exceeds current amount", func(t *testing.T) {
		st := NewState()
		to := testutils.TestAddress("to")

		// Add initial delegation
		err1 := updateDelegationSnapShotHistory(st, to, 1000, true)
		uassert.NoError(t, err1)

		// Remove more than available
		err2 := updateDelegationSnapShotHistory(st, to, 2000, false)
		uassert.NoError(t, err2)

		toStr := to.String()
		snapshots := st.snapShotHistory[toStr]
		uassert.Equal(t, 2, len(snapshots))

		// Verify first snapshot
		uassert.Equal(t, uint64(1000), snapshots[0].amount)

		// Verify second snapshot (should be 0 due to int64 underflow prevention)
		uassert.Equal(t, uint64(0), snapshots[1].amount)
	})

	t.Run("should return error for invalid to address", func(t *testing.T) {
		st := NewState()
		to := std.Address("") // Invalid address
		amount := uint64(1000)

		err := updateDelegationSnapShotHistory(st, to, amount, true)

		uassert.Error(t, err)
		if !strings.Contains(err.Error(), "invalid address") {
			t.Errorf("expected error to contain 'invalid address', got %s", err.Error())
		}
	})

	t.Run("should handle zero amount delegation", func(t *testing.T) {
		st := NewState()
		to := testutils.TestAddress("to")
		amount := uint64(0)

		err := updateDelegationSnapShotHistory(st, to, amount, true)

		uassert.NoError(t, err)
		toStr := to.String()
		snapshots := st.snapShotHistory[toStr]
		uassert.Equal(t, 1, len(snapshots))
		uassert.Equal(t, uint64(0), snapshots[0].amount)
	})

	t.Run("should maintain chronological order of snapshots", func(t *testing.T) {
		st := NewState()
		to := testutils.TestAddress("to")

		// Add multiple delegations
		updateDelegationSnapShotHistory(st, to, 1000, true)
		updateDelegationSnapShotHistory(st, to, 2000, true)
		updateDelegationSnapShotHistory(st, to, 500, false)

		toStr := to.String()
		snapshots := st.snapShotHistory[toStr]
		uassert.Equal(t, 3, len(snapshots))

		// Verify chronological order and amounts
		uassert.Equal(t, uint64(1000), snapshots[0].amount)
		uassert.Equal(t, uint64(3000), snapshots[1].amount)
		uassert.Equal(t, uint64(2500), snapshots[2].amount)

		// Verify timestamps are in ascending order
		for i := 1; i < len(snapshots); i++ {
			uassert.True(t, snapshots[i].updatedAt >= snapshots[i-1].updatedAt)
		}
	})
}

func TestDelegate(t *testing.T) {
	caller := testutils.TestAddress("caller")
	delegatee := testutils.TestAddress("delegatee")

	tests := []struct {
		name          string
		initialState  *State
		to            std.Address
		amount        uint64
		expectedError string
		expectedState *State
		description   string
	}{
		{
			name: "successful delegation - new delegator and delegatee",
			initialState: &State{
				totalDelegated:    0,
				delegatorAmount:   make(AmountMap),
				delegatedFromTo:   make(FromToMap),
				delegatedTo:       make(AmountMap),
				delegationHistory: make(HistoryMap),
				snapShotHistory:   make(SnapShotMap),
			},
			to:     delegatee,
			amount: 1000,
			expectedState: &State{
				totalDelegated: 1000,
				delegatorAmount: AmountMap{
					caller.String(): 1000,
				},
				delegatedFromTo: FromToMap{
					caller.String(): AmountMap{
						delegatee.String(): 1000,
					},
				},
				delegatedTo: AmountMap{
					delegatee.String(): 1000,
				},
			},
			description: "should successfully delegate amount for new delegator and delegatee",
		},
		{
			name: "error - zero amount",
			initialState: &State{
				totalDelegated:    0,
				delegatorAmount:   make(AmountMap),
				delegatedFromTo:   make(FromToMap),
				delegatedTo:       make(AmountMap),
				delegationHistory: make(HistoryMap),
				snapShotHistory:   make(SnapShotMap),
			},
			to:            delegatee,
			amount:        0,
			expectedError: "amount must be positive",
			expectedState: &State{
				totalDelegated:    0,
				delegatorAmount:   make(AmountMap),
				delegatedFromTo:   make(FromToMap),
				delegatedTo:       make(AmountMap),
				delegationHistory: make(HistoryMap),
				snapShotHistory:   make(SnapShotMap),
			},
			description: "should return error when amount is zero",
		},
		{
			name: "large amount delegation",
			initialState: &State{
				totalDelegated:    0,
				delegatorAmount:   make(AmountMap),
				delegatedFromTo:   make(FromToMap),
				delegatedTo:       make(AmountMap),
				delegationHistory: make(HistoryMap),
				snapShotHistory:   make(SnapShotMap),
			},
			to:     delegatee,
			amount: 999999999,
			expectedState: &State{
				totalDelegated: 999999999,
				delegatorAmount: AmountMap{
					caller.String(): 999999999,
				},
				delegatedFromTo: FromToMap{
					caller.String(): AmountMap{
						delegatee.String(): 999999999,
					},
				},
				delegatedTo: AmountMap{
					delegatee.String(): 999999999,
				},
			},
			description: "should handle large delegation amounts",
		},
		{
			name: "delegation with minimum amount",
			initialState: &State{
				totalDelegated:    0,
				delegatorAmount:   make(AmountMap),
				delegatedFromTo:   make(FromToMap),
				delegatedTo:       make(AmountMap),
				delegationHistory: make(HistoryMap),
				snapShotHistory:   make(SnapShotMap),
			},
			to:     delegatee,
			amount: 1,
			expectedState: &State{
				totalDelegated: 1,
				delegatorAmount: AmountMap{
					caller.String(): 1,
				},
				delegatedFromTo: FromToMap{
					caller.String(): AmountMap{
						delegatee.String(): 1,
					},
				},
				delegatedTo: AmountMap{
					delegatee.String(): 1,
				},
			},
			description: "should handle minimum delegation amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetOriginCaller(caller)

			// Create a copy of the initial state to avoid modifying the test data
			initialState := &State{
				totalDelegated:    tt.initialState.totalDelegated,
				delegatorAmount:   make(AmountMap),
				delegatedFromTo:   make(FromToMap),
				delegatedTo:       make(AmountMap),
				delegationHistory: make(HistoryMap),
				snapShotHistory:   make(SnapShotMap),
			}

			// Copy maps to avoid reference issues
			for k, v := range tt.initialState.delegatorAmount {
				initialState.delegatorAmount[k] = v
			}
			for k, v := range tt.initialState.delegatedFromTo {
				initialState.delegatedFromTo[k] = make(AmountMap)
				for k2, v2 := range v {
					initialState.delegatedFromTo[k][k2] = v2
				}
			}
			for k, v := range tt.initialState.delegatedTo {
				initialState.delegatedTo[k] = v
			}
			for k, v := range tt.initialState.delegationHistory {
				initialState.delegationHistory[k] = make([]DelegationHistory, len(v))
				copy(initialState.delegationHistory[k], v)
			}
			for k, v := range tt.initialState.snapShotHistory {
				initialState.snapShotHistory[k] = make([]DelegationSnapShotHistory, len(v))
				copy(initialState.snapShotHistory[k], v)
			}

			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/gov/staker"))

				// Call the delegate function
				err := delegate(initialState, tt.to, tt.amount)

				// Check error expectations
				if tt.expectedError != "" {
					uassert.Error(t, err)
					if !strings.Contains(err.Error(), tt.expectedError) {
						t.Errorf("expected error to contain '%s', got '%s'", tt.expectedError, err.Error())
					}
					return
				}

				uassert.NoError(t, err)

				// Verify totalDelegated
				uassert.Equal(t, tt.expectedState.totalDelegated, initialState.totalDelegated, "totalDelegated mismatch")

				// Verify delegatorAmount
				for delegator, expectedAmount := range tt.expectedState.delegatorAmount {
					actualAmount, exists := initialState.delegatorAmount[delegator]
					uassert.True(t, exists, "delegator %s should exist in result", delegator)
					uassert.Equal(t, expectedAmount, actualAmount, "delegator amount mismatch for %s", delegator)
				}

				// Verify delegatedFromTo
				for delegator, expectedDelegations := range tt.expectedState.delegatedFromTo {
					actualDelegations, exists := initialState.delegatedFromTo[delegator]
					uassert.True(t, exists, "delegator %s should exist in delegatedFromTo", delegator)
					for delegatee, expectedAmount := range expectedDelegations {
						actualAmount, exists := actualDelegations[delegatee]
						uassert.True(t, exists, "delegatee %s should exist for delegator %s", delegatee, delegator)
						uassert.Equal(t, expectedAmount, actualAmount, "delegation amount mismatch for %s -> %s", delegator, delegatee)
					}
				}

				// Verify delegatedTo
				for delegatee, expectedAmount := range tt.expectedState.delegatedTo {
					actualAmount, exists := initialState.delegatedTo[delegatee]
					uassert.True(t, exists, "delegatee %s should exist in delegatedTo", delegatee)
					uassert.Equal(t, expectedAmount, actualAmount, "delegatee total amount mismatch for %s", delegatee)
				}

				// Verify that delegation history was added
				callerStr := caller.String()
				history, exists := initialState.delegationHistory[callerStr]
				uassert.True(t, exists, "delegation history should exist for caller")
				uassert.Equal(t, 1, len(history), "should have one delegation history entry")

				// Verify history entry
				entry := history[0]
				uassert.Equal(t, tt.to, entry.to)
				uassert.Equal(t, tt.amount, entry.amount)
				uassert.True(t, entry.timestamp > 0, "timestamp should be set")
				uassert.True(t, entry.height > 0, "height should be set")
				uassert.True(t, entry.add, "add flag should be true")

				// Verify that snapshot history was updated
				toStr := tt.to.String()
				snapshots, exists := initialState.snapShotHistory[toStr]
				uassert.True(t, exists, "snapshot history should exist for delegatee")
				uassert.Equal(t, 1, len(snapshots), "should have one snapshot entry")

				// Verify snapshot entry
				snapshot := snapshots[0]
				uassert.Equal(t, tt.to, snapshot.to)
				uassert.Equal(t, tt.amount, snapshot.amount)
				uassert.True(t, snapshot.updatedBlock > 0, "updatedBlock should be set")
				uassert.True(t, snapshot.updatedAt > 0, "updatedAt should be set")
			}()
		})
	}
}

func TestUndelegate(t *testing.T) {
	caller := testutils.TestAddress("caller")
	delegatee := testutils.TestAddress("delegatee")

	tests := []struct {
		name          string
		initialState  *State
		undelegateTo  std.Address
		amount        uint64
		expectedError string
		expectedState *State
		description   string
	}{
		{
			name: "successful undelegation",
			initialState: &State{
				totalDelegated: 1000,
				delegatorAmount: AmountMap{
					caller.String(): 1000,
				},
				delegatedFromTo: FromToMap{
					caller.String(): AmountMap{
						delegatee.String(): 1000,
					},
				},
				delegatedTo: AmountMap{
					delegatee.String(): 1000,
				},
				delegationHistory: make(HistoryMap),
				snapShotHistory:   make(SnapShotMap),
			},
			undelegateTo: delegatee,
			amount:       1000,
			expectedState: &State{
				totalDelegated: 0,
				delegatorAmount: AmountMap{
					caller.String(): 0,
				},
				delegatedFromTo: FromToMap{
					caller.String(): AmountMap{
						delegatee.String(): 0,
					},
				},
				delegatedTo: AmountMap{
					delegatee.String(): 0,
				},
			},
			description: "should successfully undelegate full amount",
		},
		{
			name:          "error - undelegate zero amount",
			initialState:  NewState(),
			undelegateTo:  delegatee,
			amount:        0,
			expectedError: "amount must be positive",
			expectedState: NewState(),
			description:   "should return error when undelegating zero amount",
		},
		{
			name:          "error - undelegate without delegation",
			initialState:  NewState(),
			undelegateTo:  delegatee,
			amount:        100,
			expectedError: "no delegated amount",
			description:   "should return error if caller never delegated",
			expectedState: NewState(),
		},
		{
			name: "error - insufficient undelegate amount",
			initialState: &State{
				totalDelegated: 100,
				delegatorAmount: AmountMap{
					caller.String(): 100,
				},
				delegatedFromTo: FromToMap{
					caller.String(): AmountMap{
						delegatee.String(): 100,
					},
				},
				delegatedTo: AmountMap{
					delegatee.String(): 100,
				},
				delegationHistory: make(HistoryMap),
				snapShotHistory:   make(SnapShotMap),
			},
			undelegateTo:  delegatee,
			amount:        200,
			expectedError: "insufficient delegated amount",
			description:   "should return error if undelegate amount exceeds delegation",
			expectedState: &State{
				totalDelegated: 100,
				delegatorAmount: AmountMap{
					caller.String(): 100,
				},
				delegatedFromTo: FromToMap{
					caller.String(): AmountMap{
						delegatee.String(): 100,
					},
				},
				delegatedTo: AmountMap{
					delegatee.String(): 100,
				},
				delegationHistory: make(HistoryMap),
				snapShotHistory:   make(SnapShotMap),
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetOriginCaller(caller)

			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/gov/staker"))

				err := undelegate(tt.initialState, tt.undelegateTo, tt.amount)

				if tt.expectedError != "" {
					uassert.Error(t, err)
					if !strings.Contains(err.Error(), tt.expectedError) {
						t.Errorf("expected error to contain '%s', got '%s'", tt.expectedError, err.Error())
					}
					return
				}

				uassert.NoError(t, err)
				uassert.Equal(t, tt.expectedState.totalDelegated, tt.initialState.totalDelegated, "totalDelegated mismatch")

				for delegator, expected := range tt.expectedState.delegatorAmount {
					actual := tt.initialState.delegatorAmount[delegator]
					uassert.Equal(t, expected, actual, "delegator amount mismatch for %s", delegator)
				}

				for delegator, expectedMap := range tt.expectedState.delegatedFromTo {
					actualMap := tt.initialState.delegatedFromTo[delegator]
					for delegatee, expected := range expectedMap {
						actual := actualMap[delegatee]
						uassert.Equal(t, expected, actual, "delegatedFromTo mismatch for %s -> %s", delegator, delegatee)
					}
				}

				for delegatee, expected := range tt.expectedState.delegatedTo {
					actual := tt.initialState.delegatedTo[delegatee]
					uassert.Equal(t, expected, actual, "delegatedTo mismatch for %s", delegatee)
				}
			}()
		})
	}
}
