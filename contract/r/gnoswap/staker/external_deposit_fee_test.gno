package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"
)

func TestGetDepositGnsAmount(t *testing.T) {
	expected := int64(1_000_000_000)
	actual := GetDepositGnsAmount()

	if actual != expected {
		t.Errorf("GetDepositGnsAmount() = %d; want %d", actual, expected)
	}
}

func TestSetDepositGnsAmountByAdmin(t *testing.T) {
	tests := []struct {
		name        string
		caller      std.Address
		newAmount   int64
		shouldPanic bool
	}{
		{
			name:        "Success - Admin sets deposit amount",
			caller:      adminAddr,
			newAmount:   2_000_000_000,
			shouldPanic: false,
		},
		{
			name:        "Failure - Non-admin tries to set deposit amount",
			caller:      std.Address("user1"),
			newAmount:   2_000_000_000,
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetOriginCaller(tt.caller)

			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
				defer func() {
					r := recover()
					if r != nil {
						if !tt.shouldPanic {
							t.Errorf("Unexpected panic: %v", r)
						}
					} else if tt.shouldPanic {
						t.Errorf("Expected panic but did not occur")
					}
				}()

				SetDepositGnsAmountByAdmin(tt.newAmount)

				if !tt.shouldPanic {
					actual := GetDepositGnsAmount()
					if actual != tt.newAmount {
						t.Errorf("SetDepositGnsAmountByAdmin() = %d; want %d", actual, tt.newAmount)
					}
				}
			}()
		})
	}
}

func TestSetDepositGnsAmount(t *testing.T) {
	tests := []struct {
		name        string
		caller      std.Address
		newAmount   int64
		shouldPanic bool
	}{
		{
			name:        "Success - Governance sets deposit amount",
			caller:      govGovernanceAddr,
			newAmount:   3_000_000_000,
			shouldPanic: false,
		},
		{
			name:        "Failure - Non-governance tries to set deposit amount",
			caller:      std.Address("user2"),
			newAmount:   3_000_000_000,
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetOriginCaller(tt.caller)

			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
				defer func() {
					r := recover()
					if r != nil {
						if !tt.shouldPanic {
							t.Errorf("Unexpected panic: %v", r)
						}
					} else if tt.shouldPanic {
						t.Errorf("Expected panic but did not occur")
					}
				}()

				SetDepositGnsAmount(tt.newAmount)

				if !tt.shouldPanic {
					actual := GetDepositGnsAmount()
					if actual != tt.newAmount {
						t.Errorf("SetDepositGnsAmount() = %d; want %d", actual, tt.newAmount)
					}
				}
			}()
		})
	}
}

func TestMinimumRewardAmountLogic(t *testing.T) {
	token1 := "gno.land/r/demo/token1"
	token2 := "gno.land/r/demo/token2"

	// --- Setup & Defer Cleanup ---
	originalDefaultMin := GetMinimumRewardAmount()
	originalToken1Min, found1 := GetSpecificTokenMinimumRewardAmount(token1)
	originalToken2Min, found2 := GetSpecificTokenMinimumRewardAmount(token2)

	// Cleanup function to restore original state
	defer func() {
		// Restore default
		minimumRewardAmount = originalDefaultMin
		// Restore token1 specific (or remove if it wasn't there originally)
		if found1 {
			tokenSpecificMinimumRewards.Set(token1, originalToken1Min)
		} else {
			tokenSpecificMinimumRewards.Remove(token1)
		}
		// Restore token2 specific
		if found2 {
			tokenSpecificMinimumRewards.Set(token2, originalToken2Min)
		} else {
			tokenSpecificMinimumRewards.Remove(token2)
		}
	}()
	// --- End Setup & Defer Cleanup ---

	// --- Test Cases ---
	t.Run("Default minimum is applied when no specific minimum is set", func(t *testing.T) {
		currentDefault := GetMinimumRewardAmount()
		actual := GetMinimumRewardAmountForToken(token1)
		if actual != currentDefault {
			t.Errorf("Expected default minimum %d for token1, got %d", currentDefault, actual)
		}
	})

	t.Run("Setting specific minimum overrides default", func(t *testing.T) {
		currentDefault := GetMinimumRewardAmount()
		specificMin := currentDefault + 500 // Set a different value
		paramStr := ufmt.Sprintf("%s:%d", token1, specificMin)

		// Set specific minimum via governance
		testing.SetOriginCaller(govGovernanceAddr)
		func() {
			testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))

			SetTokenMinimumRewardAmount(paramStr)
		}()

		// Check specific token
		actualSpecific := GetMinimumRewardAmountForToken(token1)
		if actualSpecific != specificMin {
			t.Errorf("Expected specific minimum %d for token1, got %d", specificMin, actualSpecific)
		}

		// Check another token still uses default
		actualDefault := GetMinimumRewardAmountForToken(token2)
		if actualDefault != currentDefault {
			t.Errorf("Expected default minimum %d for token2 after setting token1, got %d", currentDefault, actualDefault)
		}
	})

	t.Run("Deleting specific minimum reverts to default", func(t *testing.T) {
		currentDefault := GetMinimumRewardAmount()
		// First, ensure a specific minimum is set (building on previous test is risky, so set it again)
		specificMin := currentDefault + 500
		paramsSetStr := ufmt.Sprintf("%s:%d", token1, specificMin)
		testing.SetOriginCaller(govGovernanceAddr)
		func() {
			testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
			SetTokenMinimumRewardAmount(paramsSetStr)

			// Verify it's set
			if GetMinimumRewardAmountForToken(token1) != specificMin {
				t.Fatalf("Setup failed: could not set specific minimum for token1 before deletion test")
			}

			// Delete the specific minimum via governance (amount 0)
			paramsDelStr := ufmt.Sprintf("%s:0", token1)
			SetTokenMinimumRewardAmount(paramsDelStr)
		}()

		// Check the token reverts to default
		actual := GetMinimumRewardAmountForToken(token1)
		if actual != currentDefault {
			t.Errorf("Expected default minimum %d for token1 after deletion, got %d", currentDefault, actual)
		}
		// Verify it's actually removed from the specific map
		_, found := GetSpecificTokenMinimumRewardAmount(token1)
		if found {
			t.Errorf("Token1 specific minimum was not removed from the map after setting amount to 0")
		}
	})

	t.Run("Changing default minimum applies subsequently", func(t *testing.T) {
		originalDefault := GetMinimumRewardAmount()
		newDefault := originalDefault + 1000

		// Set a specific minimum for token1 *before* changing default
		specificMinToken1 := originalDefault + 500
		paramStr := ufmt.Sprintf("%s:%d", token1, specificMinToken1)
		testing.SetOriginCaller(govGovernanceAddr)
		func() {
			testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
			SetTokenMinimumRewardAmount(paramStr)

			// Change the default minimum via governance
			SetMinimumRewardAmount(newDefault)
		}()

		// Check token without specific minimum uses the NEW default
		actualNewDefault := GetMinimumRewardAmountForToken(token2)
		if actualNewDefault != newDefault {
			t.Errorf("Expected new default minimum %d for token2, got %d", newDefault, actualNewDefault)
		}

		// Check token WITH specific minimum *still* uses its specific minimum
		actualSpecific := GetMinimumRewardAmountForToken(token1)
		if actualSpecific != specificMinToken1 {
			t.Errorf("Expected specific minimum %d for token1 to persist, got %d", specificMinToken1, actualSpecific)
		}
	})
}
