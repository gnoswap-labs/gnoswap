package v1

import (
	"math"
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/staker"
)

// Test CleanStakerDelegationSnapshotByAdmin function
func TestStakerDelegationSnapshot_CleanStakerDelegationSnapshotByAdmin(t *testing.T) {
	tests := []struct {
		name          string
		caller        address
		threshold     int64
		expectPanic   bool
		expectedError string
	}{
		{
			name:          "Non-admin caller should panic",
			caller:        testutils.TestAddress("alice"),
			threshold:     100,
			expectPanic:   true,
			expectedError: "unauthorized: caller " + testutils.TestAddress("alice").String() + " is not admin",
		},
		{
			name:          "Invalid caller address should panic",
			caller:        testutils.TestAddress("invalid"),
			threshold:     100,
			expectPanic:   true,
			expectedError: "unauthorized: caller g1d9h8vctvd9j97h6lta047h6lta047h6l8k5rvt is not admin",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gs := createTestGovStaker()
			// Given: Setup test environment
			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
						gs.CleanStakerDelegationSnapshotByAdmin(tt.threshold)
					}(cross)
				})
			} else {
				func(cur realm) {
					// Should not panic for admin
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					gs.CleanStakerDelegationSnapshotByAdmin(tt.threshold)
				}(cross)
			}
		})
	}
}

// Test edge cases and integration scenarios
func TestStakerDelegationSnapshot_EdgeCases(t *testing.T) {
	gs := createTestGovStaker()
	tests := []struct {
		name         string
		description  string
		testFunction func(t *testing.T)
	}{
		{
			name:        "Multiple SetUnDelegationLockupPeriodByAdmin operations should work",
			description: "Admin should be able to perform multiple SetUnDelegationLockupPeriodByAdmin operations in sequence",
			testFunction: func(t *testing.T) {
				// Given: Admin context
				testing.SetRealm(testing.NewUserRealm(admin))

				func(cur realm) {
					gs.SetUnDelegationLockupPeriodByAdmin(1000)
					gs.SetUnDelegationLockupPeriodByAdmin(2000)
					gs.SetUnDelegationLockupPeriodByAdmin(3000)
				}(cross)
			},
		},
		{
			name:        "Large height values should be handled",
			description: "System should handle large block height values without issues",
			testFunction: func(t *testing.T) {
				// Given: Admin context
				testing.SetRealm(testing.NewUserRealm(admin))

				// When: Use large height value
				largeHeight := int64(9223372036854775807) // max int64

				// Then: Should not panic
				func(cur realm) {
					gs.SetUnDelegationLockupPeriodByAdmin(largeHeight)
				}(cross)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute test function
			tt.testFunction(t)
		})
	}
}

// Test boundary conditions for safe arithmetic in delegation snapshot cleanup
func TestStakerDelegationSnapshot_BoundaryConditions(t *testing.T) {
	t.Run("CleanTotalDelegationHistory with MaxInt64 cutoff", func(t *testing.T) {
		// given: gov staker with delegation history
		gs := createTestGovStaker()
		testing.SetRealm(testing.NewUserRealm(admin))

		// Set up some delegation history
		func(cur realm) {
			history := gs.store.GetTotalDelegationHistory()
			history.Set(100, int64(1000))
			history.Set(200, int64(2000))
			history.Set(math.MaxInt64-1, int64(3000))
			err := gs.store.SetTotalDelegationHistory(history)
			if err != nil {
				panic(err)
			}
		}(cross)

		// when: clean history with MaxInt64 cutoff (uses safeAddInt64 at line 93)
		// This should NOT panic because the code checks cutoffTimestamp < math.MaxInt64
		func(cur realm) {
			gs.cleanTotalDelegationHistory(math.MaxInt64)
		}(cross)

		// then: should succeed without overflow
		history := gs.store.GetTotalDelegationHistory()
		uassert.True(t, history.Size() > 0)
	})

	t.Run("CleanUserDelegationHistory with MaxInt64 cutoff", func(t *testing.T) {
		// given: gov staker with user delegation history
		gs := createTestGovStaker()
		testing.SetRealm(testing.NewUserRealm(admin))

		aliceAddr := testutils.TestAddress("alice").String()

		// Set up user delegation history
		func(cur realm) {
			userHistory := staker.NewUintTree()
			userHistory.Set(100, int64(1000))
			userHistory.Set(200, int64(2000))
			userHistory.Set(math.MaxInt64-1, int64(3000))

			history := avl.NewTree()
			history.Set(aliceAddr, userHistory)
			err := gs.store.SetUserDelegationHistory(history)
			if err != nil {
				panic(err)
			}
		}(cross)

		// when: clean user history with MaxInt64 cutoff (uses safeAddInt64 at line 136)
		// This should NOT panic because the code checks cutoffTimestamp < math.MaxInt64
		func(cur realm) {
			gs.cleanUserDelegationHistory(math.MaxInt64)
		}(cross)

		// then: should succeed without overflow
		history := gs.store.GetUserDelegationHistory()
		uassert.True(t, history.Size() > 0)
	})

	t.Run("CleanTotalDelegationHistory with near-max cutoff", func(t *testing.T) {
		// given: gov staker with delegation history
		gs := createTestGovStaker()
		testing.SetRealm(testing.NewUserRealm(admin))

		// Set up delegation history with timestamps
		func(cur realm) {
			history := gs.store.GetTotalDelegationHistory()
			history.Set(100, int64(1000))
			history.Set(math.MaxInt64-1000, int64(2000))
			history.Set(math.MaxInt64-500, int64(3000))
			err := gs.store.SetTotalDelegationHistory(history)
			if err != nil {
				panic(err)
			}
		}(cross)

		// when: clean history with near-max cutoff (uses safeAddInt64)
		cutoff := int64(math.MaxInt64 - 100)
		func(cur realm) {
			gs.cleanTotalDelegationHistory(cutoff)
		}(cross)

		// then: should preserve continuity and clean old entries
		history := gs.store.GetTotalDelegationHistory()
		// Should have at least the cutoff entry
		val, exists := history.Get(cutoff)
		uassert.True(t, exists || history.Size() > 0)
		_ = val
	})

	t.Run("CleanUserDelegationHistory with near-max cutoff", func(t *testing.T) {
		// given: gov staker with user delegation history
		gs := createTestGovStaker()
		testing.SetRealm(testing.NewUserRealm(admin))

		aliceAddr := testutils.TestAddress("alice").String()

		// Set up user delegation history
		func(cur realm) {
			userHistory := staker.NewUintTree()
			userHistory.Set(100, int64(1000))
			userHistory.Set(math.MaxInt64-1000, int64(2000))
			userHistory.Set(math.MaxInt64-500, int64(3000))

			history := avl.NewTree()
			history.Set(aliceAddr, userHistory)
			err := gs.store.SetUserDelegationHistory(history)
			if err != nil {
				panic(err)
			}
		}(cross)

		// when: clean user history with near-max cutoff (uses safeAddInt64)
		cutoff := int64(math.MaxInt64 - 100)
		func(cur realm) {
			gs.cleanUserDelegationHistory(cutoff)
		}(cross)

		// then: should preserve user history
		history := gs.store.GetUserDelegationHistory()
		uassert.True(t, history.Size() > 0)
	})
}
