package v1

import (
	"math"
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/staker"
)

func TestNewProtocolFeeRewardState(t *testing.T) {
	tests := []struct {
		name                               string
		accumulatedProtocolFeeX128PerStake map[string]*u256.Uint
		expectedTokenCount                 int
	}{
		{
			name:                               "Create with empty protocol fee map",
			accumulatedProtocolFeeX128PerStake: make(map[string]*u256.Uint),
			expectedTokenCount:                 0,
		},
		{
			name: "Create with single token",
			accumulatedProtocolFeeX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(1000),
			},
			expectedTokenCount: 1,
		},
		{
			name: "Create with multiple tokens",
			accumulatedProtocolFeeX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(1000),
				"token2": u256.NewUintFromInt64(2000),
				"token3": u256.NewUintFromInt64(3000),
			},
			expectedTokenCount: 3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When: Create new protocol fee reward state
			state := staker.NewProtocolFeeRewardState(func() *avl.Tree {
				tree := avl.NewTree()
				for k, v := range tt.accumulatedProtocolFeeX128PerStake {
					tree.Set(k, v)
				}
				return tree
			}())
			resolver := NewProtocolFeeRewardStateResolver(state)

			// Then: Should initialize correctly
			uassert.NotEqual(t, resolver, nil)
			uassert.Equal(t, resolver.GetRewardDebtX128().Size(), tt.expectedTokenCount)
			uassert.Equal(t, resolver.GetAccumulatedTimestamp(), int64(0))
			uassert.Equal(t, resolver.GetClaimedTimestamp(), int64(0))
			uassert.Equal(t, resolver.GetStakedAmount(), int64(0))

			// Verify reward debt is properly cloned
			for token, originalAmount := range tt.accumulatedProtocolFeeX128PerStake {
				debtAmount := resolver.GetRewardDebtX128ForToken(token)
				uassert.NotEqual(t, debtAmount, nil)
				uassert.Equal(t, debtAmount.Cmp(originalAmount), 0)
			}
		})
	}
}

// Test IsClaimable
func TestProtocolFeeRewardState_IsClaimable(t *testing.T) {
	tests := []struct {
		name             string
		claimedTimestamp int64
		currentTimestamp int64
		expected         bool
	}{
		{
			name:             "Not claimable when current height equals claimed height",
			claimedTimestamp: 100,
			currentTimestamp: 100,
			expected:         false,
		},
		{
			name:             "Not claimable when current height is less than claimed height",
			claimedTimestamp: 100,
			currentTimestamp: 50,
			expected:         false,
		},
		{
			name:             "Claimable when current height is greater than claimed height",
			claimedTimestamp: 50,
			currentTimestamp: 100,
			expected:         true,
		},
		{
			name:             "Claimable when never claimed before",
			claimedTimestamp: 0,
			currentTimestamp: 100,
			expected:         true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward state with claimed height
			state := staker.NewProtocolFeeRewardState(avl.NewTree())
			resolver := NewProtocolFeeRewardStateResolver(state)
			resolver.SetClaimedTimestamp(tt.claimedTimestamp)

			// When: Check if claimable
			result := resolver.IsClaimable(tt.currentTimestamp)

			// Then: Should return expected result
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test GetClaimableRewardAmounts
func TestProtocolFeeRewardState_GetClaimableRewardAmounts(t *testing.T) {
	tests := []struct {
		name                           string
		setupState                     func(*ProtocolFeeRewardStateResolver)
		accumulatedRewardsX128PerStake map[string]*u256.Uint
		currentTimestamp               int64
		expectedTokenCount             int
	}{
		{
			name: "No rewards when accumulated height is greater than current height",
			setupState: func(s *ProtocolFeeRewardStateResolver) {
				s.SetAccumulatedTimestamp(200)
				s.SetAccumulatedRewards(func() *avl.Tree {
					tree := avl.NewTree()
					tree.Set("token1", int64(1000))
					return tree
				}())
			},
			accumulatedRewardsX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(1000),
			},
			currentTimestamp:   100,
			expectedTokenCount: 1, // Returns accumulated rewards
		},
		{
			name: "Calculate rewards when current height is greater",
			setupState: func(s *ProtocolFeeRewardStateResolver) {
				s.SetAccumulatedTimestamp(50)
				s.SetStakedAmount(1000)
				s.SetRewardDebtX128ForToken("token1", u256.NewUint(0))
			},
			accumulatedRewardsX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(500).Lsh(u256.NewUintFromInt64(500), 128),
			},
			currentTimestamp:   100,
			expectedTokenCount: 1,
		},
		{
			name: "Multiple tokens calculation",
			setupState: func(s *ProtocolFeeRewardStateResolver) {
				s.SetAccumulatedTimestamp(50)
				s.SetStakedAmount(1000)
				s.SetRewardDebtX128ForToken("token1", u256.NewUint(0))
				s.SetRewardDebtX128ForToken("token2", u256.NewUint(0))
				s.SetRewardDebtX128ForToken("token3", u256.NewUint(0))
			},
			accumulatedRewardsX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(100).Lsh(u256.NewUintFromInt64(100), 128),
				"token2": u256.NewUintFromInt64(200).Lsh(u256.NewUintFromInt64(200), 128),
				"token3": u256.NewUintFromInt64(300).Lsh(u256.NewUintFromInt64(300), 128),
			},
			currentTimestamp:   100,
			expectedTokenCount: 3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward state setup
			state := staker.NewProtocolFeeRewardState(avl.NewTree())
			resolver := NewProtocolFeeRewardStateResolver(state)
			tt.setupState(resolver)

			// When: Get claimable reward amounts
			result, _ := resolver.GetClaimableRewardAmounts(func() *avl.Tree {
				tree := avl.NewTree()
				for k, v := range tt.accumulatedRewardsX128PerStake {
					tree.Set(k, v)
				}
				return tree
			}(), tt.currentTimestamp)

			// Then: Should return expected number of tokens
			uassert.Equal(t, len(result), tt.expectedTokenCount)

			// Verify all amounts are non-negative
			for token, amount := range result {
				uassert.True(t, amount >= 0, "Reward amount should be non-negative for token: "+token)
			}
		})
	}
}

// Test addStake
func TestProtocolFeeRewardState_addStake(t *testing.T) {
	tests := []struct {
		name          string
		initialStake  int64
		addAmount     int64
		expectedStake int64
	}{
		{
			name:          "Add stake to empty state",
			initialStake:  0,
			addAmount:     1000,
			expectedStake: 1000,
		},
		{
			name:          "Add stake to existing stake",
			initialStake:  500,
			addAmount:     300,
			expectedStake: 800,
		},
		{
			name:          "Add zero stake",
			initialStake:  1000,
			addAmount:     0,
			expectedStake: 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward state with initial stake
			state := staker.NewProtocolFeeRewardState(avl.NewTree())
			resolver := NewProtocolFeeRewardStateResolver(state)
			resolver.SetStakedAmount(tt.initialStake)

			// When: Add stake
			resolver.addStake(tt.addAmount)

			// Then: Staked amount should be updated
			uassert.Equal(t, resolver.GetStakedAmount(), tt.expectedStake)
		})
	}
}

// Test removeStake
func TestProtocolFeeRewardState_removeStake(t *testing.T) {
	tests := []struct {
		name          string
		initialStake  int64
		removeAmount  int64
		expectedStake int64
	}{
		{
			name:          "Remove partial stake",
			initialStake:  1000,
			removeAmount:  300,
			expectedStake: 700,
		},
		{
			name:          "Remove all stake",
			initialStake:  1000,
			removeAmount:  1000,
			expectedStake: 0,
		},
		{
			name:          "Remove zero stake",
			initialStake:  1000,
			removeAmount:  0,
			expectedStake: 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward state with initial stake
			state := staker.NewProtocolFeeRewardState(avl.NewTree())
			resolver := NewProtocolFeeRewardStateResolver(state)
			resolver.SetStakedAmount(tt.initialStake)

			// When: Remove stake
			resolver.removeStake(tt.removeAmount)

			// Then: Staked amount should be updated
			uassert.Equal(t, resolver.GetStakedAmount(), tt.expectedStake)
		})
	}
}

// Test claimRewards
func TestProtocolFeeRewardState_claimRewards(t *testing.T) {
	tests := []struct {
		name                  string
		setupState            func(*ProtocolFeeRewardStateResolver)
		currentTimestamp      int64
		expectError           bool
		expectedClaimedLength int
	}{
		{
			name: "Claim when not claimable",
			setupState: func(s *ProtocolFeeRewardStateResolver) {
				s.SetClaimedTimestamp(100)
				s.SetAccumulatedRewards(func() *avl.Tree {
					tree := avl.NewTree()
					tree.Set("token1", int64(1000))
					return tree
				}())
			},
			currentTimestamp: 100,
			expectError:      true,
		},
		{
			name: "Claim when accumulated height is less than current height",
			setupState: func(s *ProtocolFeeRewardStateResolver) {
				s.SetClaimedTimestamp(50)
				s.SetAccumulatedTimestamp(50)
				s.SetAccumulatedRewards(func() *avl.Tree {
					tree := avl.NewTree()
					tree.Set("token1", int64(1000))
					return tree
				}())
			},
			currentTimestamp: 100,
			expectError:      true, // Must update reward debt before claiming
		},
		{
			name: "Successful claim",
			setupState: func(s *ProtocolFeeRewardStateResolver) {
				s.SetClaimedTimestamp(50)
				s.SetAccumulatedTimestamp(100)
				s.SetAccumulatedRewards(func() *avl.Tree {
					tree := avl.NewTree()
					tree.Set("token1", int64(1000))
					tree.Set("token2", int64(500))
					return tree
				}())
				s.SetClaimedRewards(func() *avl.Tree {
					tree := avl.NewTree()
					tree.Set("token1", int64(300))
					tree.Set("token2", int64(0))
					return tree
				}())
			},
			currentTimestamp:      100,
			expectError:           false,
			expectedClaimedLength: 2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward state setup
			state := staker.NewProtocolFeeRewardState(avl.NewTree())
			resolver := NewProtocolFeeRewardStateResolver(state)
			tt.setupState(resolver)

			// When: Claim rewards
			claimedRewards, err := resolver.claimRewards(tt.currentTimestamp)

			// Then: Check result
			if tt.expectError {
				uassert.Error(t, err)
				uassert.Equal(t, claimedRewards, nil)
			} else {
				uassert.NoError(t, err)
				uassert.NotEqual(t, claimedRewards, nil)
				uassert.Equal(t, len(claimedRewards), tt.expectedClaimedLength)
				uassert.Equal(t, resolver.GetClaimedTimestamp(), tt.currentTimestamp)
			}
		})
	}
}

// Test updateRewardDebtX128
func TestProtocolFeeRewardState_updateRewardDebtX128(t *testing.T) {
	tests := []struct {
		name                               string
		setupState                         func(*ProtocolFeeRewardStateResolver)
		accumulatedProtocolFeeX128PerStake map[string]*u256.Uint
		currentTimestamp                   int64
		shouldUpdate                       bool
	}{
		{
			name: "No update when accumulated height is greater than current height",
			setupState: func(s *ProtocolFeeRewardStateResolver) {
				s.SetAccumulatedTimestamp(200)
			},
			accumulatedProtocolFeeX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(1000),
			},
			currentTimestamp: 100,
			shouldUpdate:     false,
		},
		{
			name: "No update when accumulated height equals current height",
			setupState: func(s *ProtocolFeeRewardStateResolver) {
				s.SetAccumulatedTimestamp(100)
			},
			accumulatedProtocolFeeX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(1000),
			},
			currentTimestamp: 100,
			shouldUpdate:     false,
		},
		{
			name: "Update when current height is greater",
			setupState: func(s *ProtocolFeeRewardStateResolver) {
				s.SetAccumulatedTimestamp(50)
				s.SetStakedAmount(1000)
				s.SetRewardDebtX128ForToken("token1", u256.NewUint(0))
				s.SetAccumulatedRewards(func() *avl.Tree {
					tree := avl.NewTree()
					tree.Set("token1", int64(200))
					return tree
				}())
			},
			accumulatedProtocolFeeX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(500).Lsh(u256.NewUintFromInt64(500), 128),
			},
			currentTimestamp: 100,
			shouldUpdate:     true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward state setup
			state := staker.NewProtocolFeeRewardState(avl.NewTree())
			resolver := NewProtocolFeeRewardStateResolver(state)
			tt.setupState(resolver)
			startedAt := resolver.GetAccumulatedTimestamp()

			// When: Update reward debt X128
			resolver.updateRewardDebtX128(func() *avl.Tree {
				tree := avl.NewTree()
				for k, v := range tt.accumulatedProtocolFeeX128PerStake {
					tree.Set(k, v)
				}
				return tree
			}(), tt.currentTimestamp)

			// Then: Check if state was updated as expected
			if tt.shouldUpdate {
				uassert.Equal(t, resolver.GetAccumulatedTimestamp(), tt.currentTimestamp)
			} else {
				uassert.Equal(t, resolver.GetAccumulatedTimestamp(), startedAt)
			}
		})
	}
}

// Test combined operations
func TestProtocolFeeRewardState_CombinedOperations(t *testing.T) {
	tests := []struct {
		name        string
		operations  func(*ProtocolFeeRewardStateResolver)
		description string
	}{
		{
			name: "Add stake with update reward debt",
			operations: func(s *ProtocolFeeRewardStateResolver) {
				accumulatedFees := map[string]*u256.Uint{
					"token1": u256.NewUintFromInt64(1000),
				}

				s.addStakeWithUpdateRewardDebtX128(500, func() *avl.Tree {
					tree := avl.NewTree()
					for k, v := range accumulatedFees {
						tree.Set(k, v)
					}
					return tree
				}(), 100)

				uassert.Equal(t, s.GetStakedAmount(), int64(500))
				uassert.Equal(t, s.GetAccumulatedTimestamp(), int64(100))
			},
			description: "Should add stake and update reward debt",
		},
		{
			name: "Remove stake with update reward debt",
			operations: func(s *ProtocolFeeRewardStateResolver) {
				s.SetStakedAmount(1000)
				accumulatedFees := map[string]*u256.Uint{
					"token1": u256.NewUintFromInt64(1000),
				}

				s.removeStakeWithUpdateRewardDebtX128(300, func() *avl.Tree {
					tree := avl.NewTree()
					for k, v := range accumulatedFees {
						tree.Set(k, v)
					}
					return tree
				}(), 100)

				uassert.Equal(t, s.GetStakedAmount(), int64(700))
				uassert.Equal(t, s.GetAccumulatedTimestamp(), int64(100))
			},
			description: "Should remove stake and update reward debt",
		},
		{
			name: "Claim rewards with update reward debt",
			operations: func(s *ProtocolFeeRewardStateResolver) {
				s.SetClaimedTimestamp(50)
				s.SetStakedAmount(1000)
				accumulatedFees := map[string]*u256.Uint{
					"token1": u256.NewUintFromInt64(500).Lsh(u256.NewUintFromInt64(500), 128),
				}

				rewards, err := s.claimRewardsWithUpdateRewardDebtX128(func() *avl.Tree {
					tree := avl.NewTree()
					for k, v := range accumulatedFees {
						tree.Set(k, v)
					}
					return tree
				}(), 100)

				uassert.NoError(t, err)
				uassert.NotEqual(t, rewards, nil)
				uassert.Equal(t, s.GetAccumulatedTimestamp(), int64(100))
				uassert.Equal(t, s.GetClaimedTimestamp(), int64(100))
			},
			description: "Should claim rewards and update reward debt",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			state := staker.NewProtocolFeeRewardState(avl.NewTree())
			resolver := NewProtocolFeeRewardStateResolver(state)
			tt.operations(resolver)
		})
	}
}

// Test edge cases
func TestProtocolFeeRewardState_EdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		setupTest   func(*ProtocolFeeRewardStateResolver)
		description string
	}{
		{
			name: "Handle nil reward debt for new token",
			setupTest: func(s *ProtocolFeeRewardStateResolver) {
				s.SetStakedAmount(1000)
				accumulatedRewards := map[string]*u256.Uint{
					"newtoken": u256.NewUintFromInt64(1000).Lsh(u256.NewUintFromInt64(1000), 128),
				}

				// Should handle nil reward debt gracefully
				result, _ := s.calculateClaimableRewards(func() *avl.Tree {
					tree := avl.NewTree()
					for k, v := range accumulatedRewards {
						tree.Set(k, v)
					}
					return tree
				}(), 100)

				uassert.NotEqual(t, result, nil)
				uassert.True(t, len(result) > 0)
			},
			description: "Should handle nil reward debt for new tokens",
		},
		{
			name: "Multiple claim attempts",
			setupTest: func(s *ProtocolFeeRewardStateResolver) {
				s.SetClaimedTimestamp(50)
				s.SetAccumulatedTimestamp(100)
				s.SetAccumulatedRewards(func() *avl.Tree {
					tree := avl.NewTree()
					tree.Set("token1", int64(1000))
					return tree
				}())
				s.SetClaimedRewards(func() *avl.Tree {
					tree := avl.NewTree()
					tree.Set("token1", int64(0))
					return tree
				}())

				// First claim
				rewards1, err1 := s.claimRewards(100)
				uassert.NoError(t, err1)
				if rewards1["token1"] != 1000 {
					t.Errorf("Expected 1000, got %d", rewards1["token1"])
				}

				// Second claim should fail (same height)
				_, err2 := s.claimRewards(100)
				uassert.Error(t, err2)
			},
			description: "Should handle multiple claim attempts correctly",
		},
		{
			name: "Zero staked amount calculation",
			setupTest: func(s *ProtocolFeeRewardStateResolver) {
				s.SetStakedAmount(0)
				accumulatedRewards := map[string]*u256.Uint{
					"token1": u256.NewUintFromInt64(1000).Lsh(u256.NewUintFromInt64(1000), 128),
				}

				result, _ := s.calculateClaimableRewards(func() *avl.Tree {
					tree := avl.NewTree()
					for k, v := range accumulatedRewards {
						tree.Set(k, v)
					}
					return tree
				}(), 100)

				// Should return zero rewards when no stake
				uassert.Equal(t, result["token1"], int64(0))
			},
			description: "Should handle zero staked amount correctly",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			state := staker.NewProtocolFeeRewardState(avl.NewTree())
			resolver := NewProtocolFeeRewardStateResolver(state)
			tt.setupTest(resolver)
		})
	}
}

// TestProtocolFeeRewardState_cloneAccumulatedProtocolFeeX128PerStake tests the private clone function
func TestProtocolFeeRewardState_cloneAccumulatedProtocolFeeX128PerStake(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "clone empty map",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given - empty map
			original := make(map[string]*u256.Uint)

			// when
			cloned := cloneAccumulatedProtocolFeeX128PerStake(func() *avl.Tree {
				tree := avl.NewTree()
				for k, v := range original {
					tree.Set(k, v)
				}
				return tree
			}())

			// then
			uassert.NotNil(t, cloned)
			uassert.Equal(t, cloned.Size(), 0)
		})
	}

	t.Run("clone map with single token", func(t *testing.T) {
		// given
		original := make(map[string]*u256.Uint)
		original["token1"] = u256.NewUintFromInt64(1000)

		// when
		cloned := cloneAccumulatedProtocolFeeX128PerStake(func() *avl.Tree {
			tree := avl.NewTree()
			for k, v := range original {
				tree.Set(k, v)
			}
			return tree
		}())

		// then
		uassert.NotNil(t, cloned)
		uassert.Equal(t, cloned.Size(), 1)
		val1, exists1 := cloned.Get("token1")
		uassert.True(t, exists1 && val1 != nil)
		uassert.Equal(t, val1.(*u256.Uint).ToString(), "1000")

		// verify deep copy - modifying original shouldn't affect clone
		original["token1"] = u256.NewUintFromInt64(2000)
		val1After, _ := cloned.Get("token1")
		uassert.Equal(t, val1After.(*u256.Uint).ToString(), "1000")
	})

	t.Run("clone map with multiple tokens", func(t *testing.T) {
		// given
		original := make(map[string]*u256.Uint)
		original["token1"] = u256.NewUintFromInt64(1000)
		original["token2"] = u256.NewUintFromInt64(2000)
		original["token3"] = u256.NewUintFromInt64(3000)

		// when
		cloned := cloneAccumulatedProtocolFeeX128PerStake(func() *avl.Tree {
			tree := avl.NewTree()
			for k, v := range original {
				tree.Set(k, v)
			}
			return tree
		}())

		// then
		uassert.NotNil(t, cloned)
		uassert.Equal(t, cloned.Size(), 3)
		val1, _ := cloned.Get("token1")
		uassert.Equal(t, val1.(*u256.Uint).ToString(), "1000")
		val2, _ := cloned.Get("token2")
		uassert.Equal(t, val2.(*u256.Uint).ToString(), "2000")
		val3, _ := cloned.Get("token3")
		uassert.Equal(t, val3.(*u256.Uint).ToString(), "3000")

		// verify deep copy
		original["token1"] = u256.NewUintFromInt64(9999)
		val1After, _ := cloned.Get("token1")
		uassert.Equal(t, val1After.(*u256.Uint).ToString(), "1000")
	})

	t.Run("clone map with large values", func(t *testing.T) {
		// given
		original := make(map[string]*u256.Uint)
		largeValue := u256.NewUintFromInt64(1000)
		largeValue = largeValue.Lsh(largeValue, 128) // Shift left by 128 bits
		original["token1"] = largeValue

		// when
		cloned := cloneAccumulatedProtocolFeeX128PerStake(func() *avl.Tree {
			tree := avl.NewTree()
			for k, v := range original {
				tree.Set(k, v)
			}
			return tree
		}())

		// then
		uassert.NotNil(t, cloned)
		uassert.Equal(t, cloned.Size(), 1)
		val1, _ := cloned.Get("token1")
		uassert.Equal(t, val1.(*u256.Uint).ToString(), largeValue.ToString())
	})
}

// Test boundary conditions for safe arithmetic in protocol fee reward operations
func TestProtocolFeeRewardState_BoundaryConditions(t *testing.T) {
	t.Run("AddStake boundary - large staked amount", func(t *testing.T) {
		// given: protocol fee reward state with large staked amount
		state := staker.NewProtocolFeeRewardState(avl.NewTree())
		resolver := NewProtocolFeeRewardStateResolver(state)

		// Set initial large staked amount
		state.SetStakedAmount(math.MaxInt64 / 2)

		// when: add more stake (uses safeAddInt64 in addStake)
		accumulatedFees := avl.NewTree()
		err := resolver.addStakeWithUpdateRewardDebtX128(math.MaxInt64/4, accumulatedFees, 1000)

		// then: should succeed without overflow
		uassert.NoError(t, err)
		expected := int64((math.MaxInt64 / 2) + (math.MaxInt64 / 4))
		uassert.Equal(t, state.GetStakedAmount(), expected)
	})

	t.Run("AddStake boundary - overflow", func(t *testing.T) {
		// given: protocol fee reward state near max staked amount
		state := staker.NewProtocolFeeRewardState(avl.NewTree())
		resolver := NewProtocolFeeRewardStateResolver(state)

		state.SetStakedAmount(math.MaxInt64 - 1000)

		// when: add stake causing overflow (uses safeAddInt64)
		didPanic := false
		func() {
			defer func() {
				if r := recover(); r != nil {
					didPanic = true
				}
			}()
			accumulatedFees := avl.NewTree()
			_ = resolver.addStakeWithUpdateRewardDebtX128(2000, accumulatedFees, 1000)
		}()

		// then: should panic on overflow
		uassert.True(t, didPanic)
	})

	t.Run("RemoveStake boundary - clamping to zero", func(t *testing.T) {
		// given: protocol fee reward state with some staked amount
		state := staker.NewProtocolFeeRewardState(avl.NewTree())
		resolver := NewProtocolFeeRewardStateResolver(state)

		state.SetStakedAmount(1000)

		// when: remove more than available (uses safeSubInt64 with clamping)
		accumulatedFees := avl.NewTree()
		err := resolver.removeStakeWithUpdateRewardDebtX128(2000, accumulatedFees, 1000)

		// then: should clamp to zero
		uassert.NoError(t, err)
		uassert.Equal(t, state.GetStakedAmount(), int64(0))
	})

	t.Run("ClaimRewards boundary - exact subtraction", func(t *testing.T) {
		// given: protocol fee reward state with accumulated and claimed equal
		state := staker.NewProtocolFeeRewardState(avl.NewTree())
		resolver := NewProtocolFeeRewardStateResolver(state)
		token := "gno.land/r/demo/foo"

		rewardAmount := int64(1000000)
		state.SetAccumulatedRewardForToken(token, rewardAmount)
		state.SetClaimedRewardForToken(token, rewardAmount)
		currentTimestamp := int64(2000)
		state.SetAccumulatedTimestamp(currentTimestamp) // Update to match claim timestamp
		state.SetClaimedTimestamp(500)

		// when: claim rewards (uses safeSubInt64 in claimRewards)
		claimed, err := resolver.claimRewards(currentTimestamp)

		// then: should result in zero claimable
		uassert.NoError(t, err)
		uassert.Equal(t, claimed[token], int64(0))
	})
}
