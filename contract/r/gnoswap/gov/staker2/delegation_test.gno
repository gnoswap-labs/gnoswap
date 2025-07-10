package staker2

import (
	"fmt"
	"std"
	"strings"
	"testing"
	"time"

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
			result := initialState.applyDelegationChange(tt.record, tt.add)

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

		err := st.appendDelegationHistory(from, to, amount, true)

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
		err1 := st.appendDelegationHistory(from, to1, 1000, true)
		uassert.NoError(t, err1)

		// Add second delegation
		err2 := st.appendDelegationHistory(from, to2, 2000, false)
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

		err := st.updateDelegationSnapShotHistory(to, amount, true)

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
		err1 := st.updateDelegationSnapShotHistory(to, 1000, true)
		uassert.NoError(t, err1)

		// Add second delegation
		err2 := st.updateDelegationSnapShotHistory(to, 2000, true)
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
		err1 := st.updateDelegationSnapShotHistory(to, 5000, true)
		uassert.NoError(t, err1)

		// Remove some delegation
		err2 := st.updateDelegationSnapShotHistory(to, 2000, false)
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
		err1 := st.updateDelegationSnapShotHistory(to, 1000, true)
		uassert.NoError(t, err1)

		// Remove more than available
		err2 := st.updateDelegationSnapShotHistory(to, 2000, false)
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

		err := st.updateDelegationSnapShotHistory(to, amount, true)

		uassert.Error(t, err)
		if !strings.Contains(err.Error(), "invalid address") {
			t.Errorf("expected error to contain 'invalid address', got %s", err.Error())
		}
	})

	t.Run("should handle zero amount delegation", func(t *testing.T) {
		st := NewState()
		to := testutils.TestAddress("to")
		amount := uint64(0)

		err := st.updateDelegationSnapShotHistory(to, amount, true)

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
		st.updateDelegationSnapShotHistory(to, 1000, true)
		st.updateDelegationSnapShotHistory(to, 2000, true)
		st.updateDelegationSnapShotHistory(to, 500, false)

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

func TestGetDelegatedCumulative(t *testing.T) {
	delegator := testutils.TestAddress("delegator")
	invalidAddress := std.Address("")

	now := uint64(time.Now().Unix())
	pastTime := now - 1000
	futureTime := now + 1000

	tests := []struct {
		name           string
		state          *State
		delegator      std.Address
		endTimestamp   uint64
		expectedAmount uint64
		expectPanic    bool
		panicMessage   string
		description    string
	}{
		{
			name: "empty snapshot history",
			state: &State{
				snapShotHistory: make(SnapShotMap),
			},
			delegator:      delegator,
			endTimestamp:   pastTime,
			expectedAmount: 0,
			expectPanic:    false,
			description:    "should return 0 when no snapshot history exists",
		},
		{
			name: "single snapshot entry - exact timestamp match",
			state: &State{
				snapShotHistory: SnapShotMap{
					delegator.String(): []DelegationSnapShotHistory{
						{
							to:           delegator,
							amount:       1000,
							updatedBlock: 100,
							updatedAt:    pastTime,
						},
					},
				},
			},
			delegator:      delegator,
			endTimestamp:   pastTime,
			expectedAmount: 1000,
			expectPanic:    false,
			description:    "should return amount when timestamp exactly matches",
		},
		{
			name: "single snapshot entry - timestamp after snapshot",
			state: &State{
				snapShotHistory: SnapShotMap{
					delegator.String(): []DelegationSnapShotHistory{
						{
							to:           delegator,
							amount:       1000,
							updatedBlock: 100,
							updatedAt:    pastTime,
						},
					},
				},
			},
			delegator:      delegator,
			endTimestamp:   pastTime + 100,
			expectedAmount: 1000,
			expectPanic:    false,
			description:    "should return amount when timestamp is after snapshot",
		},
		{
			name: "single snapshot entry - timestamp before snapshot",
			state: &State{
				snapShotHistory: SnapShotMap{
					delegator.String(): []DelegationSnapShotHistory{
						{
							to:           delegator,
							amount:       1000,
							updatedBlock: 100,
							updatedAt:    pastTime + 100,
						},
					},
				},
			},
			delegator:      delegator,
			endTimestamp:   pastTime,
			expectedAmount: 0,
			expectPanic:    false,
			description:    "should return 0 when timestamp is before first snapshot",
		},
		{
			name: "multiple snapshot entries - find correct one",
			state: &State{
				snapShotHistory: SnapShotMap{
					delegator.String(): []DelegationSnapShotHistory{
						{
							to:           delegator,
							amount:       500,
							updatedBlock: 100,
							updatedAt:    pastTime,
						},
						{
							to:           delegator,
							amount:       1000,
							updatedBlock: 200,
							updatedAt:    pastTime + 100,
						},
						{
							to:           delegator,
							amount:       1500,
							updatedBlock: 300,
							updatedAt:    pastTime + 200,
						},
					},
				},
			},
			delegator:      delegator,
			endTimestamp:   pastTime + 150,
			expectedAmount: 1000,
			expectPanic:    false,
			description:    "should return correct amount for timestamp between snapshots",
		},
		{
			name: "multiple snapshot entries - exact timestamp match",
			state: &State{
				snapShotHistory: SnapShotMap{
					delegator.String(): []DelegationSnapShotHistory{
						{
							to:           delegator,
							amount:       500,
							updatedBlock: 100,
							updatedAt:    pastTime,
						},
						{
							to:           delegator,
							amount:       1000,
							updatedBlock: 200,
							updatedAt:    pastTime + 100,
						},
						{
							to:           delegator,
							amount:       1500,
							updatedBlock: 300,
							updatedAt:    pastTime + 200,
						},
					},
				},
			},
			delegator:      delegator,
			endTimestamp:   pastTime + 100,
			expectedAmount: 1000,
			expectPanic:    false,
			description:    "should return exact amount when timestamp matches snapshot",
		},
		{
			name: "multiple snapshot entries - latest snapshot",
			state: &State{
				snapShotHistory: SnapShotMap{
					delegator.String(): []DelegationSnapShotHistory{
						{
							to:           delegator,
							amount:       500,
							updatedBlock: 100,
							updatedAt:    pastTime,
						},
						{
							to:           delegator,
							amount:       1000,
							updatedBlock: 200,
							updatedAt:    pastTime + 100,
						},
						{
							to:           delegator,
							amount:       1500,
							updatedBlock: 300,
							updatedAt:    pastTime + 200,
						},
					},
				},
			},
			delegator:      delegator,
			endTimestamp:   pastTime + 300,
			expectedAmount: 1500,
			expectPanic:    false,
			description:    "should return latest amount when timestamp is after all snapshots",
		},
		{
			name: "invalid delegator address",
			state: &State{
				snapShotHistory: make(SnapShotMap),
			},
			delegator:    invalidAddress,
			endTimestamp: pastTime,
			expectPanic:  true,
			panicMessage: "invalid delegator address",
			description:  "should panic with invalid delegator address",
		},
		{
			name: "future timestamp",
			state: &State{
				snapShotHistory: make(SnapShotMap),
			},
			delegator:    delegator,
			endTimestamp: futureTime,
			expectPanic:  true,
			panicMessage: "endTimestamp",
			description:  "should panic when endTimestamp is in the future",
		},
		{
			name: "zero amount snapshot",
			state: &State{
				snapShotHistory: SnapShotMap{
					delegator.String(): []DelegationSnapShotHistory{
						{
							to:           delegator,
							amount:       0,
							updatedBlock: 100,
							updatedAt:    pastTime,
						},
					},
				},
			},
			delegator:      delegator,
			endTimestamp:   pastTime,
			expectedAmount: 0,
			expectPanic:    false,
			description:    "should return 0 when snapshot amount is 0",
		},
		{
			name: "large amount snapshot",
			state: &State{
				snapShotHistory: SnapShotMap{
					delegator.String(): []DelegationSnapShotHistory{
						{
							to:           delegator,
							amount:       999999999,
							updatedBlock: 100,
							updatedAt:    pastTime,
						},
					},
				},
			},
			delegator:      delegator,
			endTimestamp:   pastTime,
			expectedAmount: 999999999,
			expectPanic:    false,
			description:    "should handle large amounts correctly",
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
					panicStr := fmt.Sprintf("%v", r)
					if !strings.Contains(panicStr, tt.panicMessage) {
						t.Errorf("expected panic to contain '%s', got '%s'", tt.panicMessage, panicStr)
					}
				}()
			}

			result := tt.state.GetDelegatedCumulative(tt.delegator, tt.endTimestamp)

			if !tt.expectPanic {
				uassert.Equal(t, tt.expectedAmount, result, "amount mismatch")
			}
		})
	}
}

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
		state          *State
		delegator      std.Address
		expectedResult []DelegationHistory
		expectPanic    bool
		panicMessage   string
		description    string
	}{
		{
			name: "empty delegation history",
			state: &State{
				delegationHistory: make(HistoryMap),
			},
			delegator:      delegator1,
			expectedResult: []DelegationHistory{},
			expectPanic:    false,
			description:    "should return empty slice when no delegation history exists",
		},
		{
			name: "single delegation history entry",
			state: &State{
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
			state: &State{
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
			state: &State{
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
			state: &State{
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
			state: &State{
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
			state: &State{
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
			state: &State{
				delegationHistory: make(HistoryMap),
			},
			delegator:    invalidAddress,
			expectPanic:  true,
			panicMessage: "invalid delegator address",
			description:  "should panic with invalid delegator address",
		},
		{
			name: "delegation history with same delegatee multiple times",
			state: &State{
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
					panicStr := fmt.Sprintf("%v", r)
					if !strings.Contains(panicStr, tt.panicMessage) {
						t.Errorf("expected panic to contain '%s', got '%s'", tt.panicMessage, panicStr)
					}
				}()
			}

			result := tt.state.GetDelegateHistoryOf(tt.delegator)

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
		state          *State
		delegator      std.Address
		expectedResult []DelegationSnapShotHistory
		expectPanic    bool
		panicMessage   string
		description    string
	}{
		{
			name: "empty snapshot history",
			state: &State{
				snapShotHistory: make(SnapShotMap),
			},
			delegator:      delegator1,
			expectedResult: []DelegationSnapShotHistory{},
			expectPanic:    false,
			description:    "should return empty slice when no snapshot history exists",
		},
		{
			name: "single snapshot history entry",
			state: &State{
				snapShotHistory: SnapShotMap{
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
			state: &State{
				snapShotHistory: SnapShotMap{
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
			state: &State{
				snapShotHistory: SnapShotMap{
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
			state: &State{
				snapShotHistory: SnapShotMap{
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
			state: &State{
				snapShotHistory: SnapShotMap{
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
			state: &State{
				snapShotHistory: SnapShotMap{
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
			name: "invalid delegator address",
			state: &State{
				snapShotHistory: make(SnapShotMap),
			},
			delegator:    invalidAddress,
			expectPanic:  true,
			panicMessage: "invalid delegator address",
			description:  "should panic with invalid delegator address",
		},
		{
			name: "snapshot history with fluctuating amounts",
			state: &State{
				snapShotHistory: SnapShotMap{
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
			state: &State{
				snapShotHistory: SnapShotMap{
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
					panicStr := fmt.Sprintf("%v", r)
					if !strings.Contains(panicStr, tt.panicMessage) {
						t.Errorf("expected panic to contain '%s', got '%s'", tt.panicMessage, panicStr)
					}
				}()
			}

			result := tt.state.GetDelegationSnapShotHistoryOf(tt.delegator)

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

func TestCleanDelegationStatHistory(t *testing.T) {
	caller := testutils.TestAddress("caller")
	to := testutils.TestAddress("delegatee")
	addrKey := to.String()

	tests := []struct {
		name          string
		currentHeight uint64
		lastCleaned   uint64
		threshold     int64
		inputHistory  []DelegationSnapShotHistory
		expectedLen   int
	}{
		{
			name:          "no cleaning needed",
			currentHeight: 1000,
			lastCleaned:   990,
			threshold:     20,
			inputHistory: []DelegationSnapShotHistory{
				{to: to, updatedBlock: 980, updatedAt: uint64(time.Now().Unix()) - 100, amount: 100},
				{to: to, updatedBlock: 995, updatedAt: uint64(time.Now().Unix()) - 10, amount: 120},
			},
			expectedLen: 2,
		},
		{
			name:          "clean old entries",
			currentHeight: 1000,
			lastCleaned:   800,
			threshold:     100,
			inputHistory: []DelegationSnapShotHistory{
				{to: to, updatedBlock: 700, updatedAt: uint64(time.Now().Unix()) - 200, amount: 50},
				{to: to, updatedBlock: 901, updatedAt: uint64(time.Now().Unix()) - 90, amount: 100},
				{to: to, updatedBlock: 950, updatedAt: uint64(time.Now().Unix()) - 10, amount: 150},
			},
			expectedLen: 3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			thresholdVotingWeightBlockHeight = tt.threshold

			// Set up the realm and state
			testing.SetOriginCaller(caller)
			testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/gov/staker"))

			state := NewState()
			state.SnapShotHistory()[addrKey] = tt.inputHistory

			last := tt.lastCleaned
			state.CleanDelegationStatHistory(&last, tt.threshold)

			snapshots := state.SnapShotHistory()[addrKey]
			uassert.Equal(t, tt.expectedLen, len(snapshots), "unexpected snapshot history length")
		})
	}
}
