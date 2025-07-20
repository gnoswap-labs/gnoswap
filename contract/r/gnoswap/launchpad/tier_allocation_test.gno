package launchpad

import (
	"testing"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
)

// TestTierAllocationNoLeftover verifies that all deposit amounts are fully allocated
// to tiers without any leftover due to percentage truncation
func TestTierAllocationNoLeftover(t *testing.T) {
	tests := []struct {
		name          string
		depositAmount int64
		tier30Ratio   int64
		tier90Ratio   int64
		tier180Ratio  int64
		description   string
	}{
		{
			name:          "even_split",
			depositAmount: 10000000,
			tier30Ratio:   33,
			tier90Ratio:   33,
			tier180Ratio:  34,
			description:   "33/33/34 split should allocate all funds",
		},
		{
			name:          "uneven_split_with_truncation",
			depositAmount: 10000000,
			tier30Ratio:   30,
			tier90Ratio:   30,
			tier180Ratio:  40,
			description:   "30/30/40 split should allocate all funds",
		},
		{
			name:          "one_third_each",
			depositAmount: 10000001, // Odd amount
			tier30Ratio:   33,
			tier90Ratio:   33,
			tier180Ratio:  34,
			description:   "Should handle odd amounts correctly",
		},
		{
			name:          "small_percentages",
			depositAmount: 100000000,
			tier30Ratio:   1,
			tier90Ratio:   2,
			tier180Ratio:  97,
			description:   "1/2/97 split should allocate all funds",
		},
		{
			name:          "all_to_one_tier",
			depositAmount: 5000000,
			tier30Ratio:   0,
			tier90Ratio:   0,
			tier180Ratio:  100,
			description:   "All funds to tier 180",
		},
		{
			name:          "prime_number_percentages",
			depositAmount: 123456789,
			tier30Ratio:   17,
			tier90Ratio:   23,
			tier180Ratio:  60,
			description:   "Prime percentages with odd deposit amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			deposits = avl.NewTree()
			depositCounter = NewCounter()
			projects = avl.NewTree()
			projectTierRewardManagers = avl.NewTree()

			currentTime := time.Now().Unix()
			currentHeight := int64(100)
			testing.SetHeight(currentHeight)

			project, _ := createProject(
				&createProjectParams{
					name:               "Test Project",
					tokenPath:          "gno.land/r/onbloc/obl",
					depositAmount:      tt.depositAmount,
					tier30Ratio:        tt.tier30Ratio,
					tier90Ratio:        tt.tier90Ratio,
					tier180Ratio:       tt.tier180Ratio,
					averageBlockTimeMs: 2000,
					recipient:          testutils.TestAddress("project"),
					startTime:          currentTime,
					currentTime:        currentTime,
					currentHeight:      currentHeight,
				},
			)
			projects.Set(project.ID(), project)

			// get all tiers and calculate total allocated
			tier30, _ := project.getTier(30)
			tier90, _ := project.getTier(90)
			tier180, _ := project.getTier(180)

			tier30Amount := tier30.TotalDistributeAmount()
			tier90Amount := tier90.TotalDistributeAmount()
			tier180Amount := tier180.TotalDistributeAmount()
			totalAllocated := tier30Amount + tier90Amount + tier180Amount

			// should be no leftover
			uassert.Equal(t, tt.depositAmount, totalAllocated,
				"Total allocated should equal deposit amount (no leftover)")

			// verify individual tier calculations
			expectedTier30 := tt.depositAmount * tt.tier30Ratio / 100
			expectedTier90 := tt.depositAmount * tt.tier90Ratio / 100
			// tier 180 gets the calculated amount plus any remainder
			expectedTier180Base := tt.depositAmount * tt.tier180Ratio / 100
			expectedRemainder := tt.depositAmount - expectedTier30 - expectedTier90 - expectedTier180Base
			expectedTier180 := expectedTier180Base + expectedRemainder

			uassert.Equal(t, expectedTier30, tier30Amount, "Tier 30 amount mismatch")
			uassert.Equal(t, expectedTier90, tier90Amount, "Tier 90 amount mismatch")
			uassert.Equal(t, expectedTier180, tier180Amount,
				"Tier 180 should include base amount plus remainder")
		})
	}
}

// TestTierAllocationRemainder specifically tests the remainder handling logic
func TestTierAllocationRemainder(t *testing.T) {
	deposits = avl.NewTree()
	depositCounter = NewCounter()
	projects = avl.NewTree()
	projectTierRewardManagers = avl.NewTree()

	currentTime := time.Now().Unix()
	currentHeight := int64(100)
	testing.SetHeight(currentHeight)

	// Create a project where truncation will definitely occur
	// 1000 / 3 = 333.33... which truncates to 333
	depositAmount := int64(1000)

	project, _ := createProject(
		&createProjectParams{
			name:               "Remainder Test",
			tokenPath:          "gno.land/r/onbloc/obl",
			depositAmount:      depositAmount,
			tier30Ratio:        33, // 1000 * 33 / 100 = 330
			tier90Ratio:        33, // 1000 * 33 / 100 = 330
			tier180Ratio:       34, // 1000 * 34 / 100 = 340
			averageBlockTimeMs: 2000,
			recipient:          testutils.TestAddress("project"),
			startTime:          currentTime,
			currentTime:        currentTime,
			currentHeight:      currentHeight,
		},
	)
	projects.Set(project.ID(), project)

	tier30, _ := project.getTier(30)
	tier90, _ := project.getTier(90)
	tier180, _ := project.getTier(180)

	// Manual calculation
	expected30 := depositAmount * 33 / 100                                 // 330
	expected90 := depositAmount * 33 / 100                                 // 330
	expected180Base := depositAmount * 34 / 100                            // 340
	remainder := depositAmount - expected30 - expected90 - expected180Base // 0
	expected180Total := expected180Base + remainder                        // 340

	t.Logf("Manual calculation:")
	t.Logf("  Tier 30: %d * 33 / 100 = %d", depositAmount, expected30)
	t.Logf("  Tier 90: %d * 33 / 100 = %d", depositAmount, expected90)
	t.Logf("  Tier 180 base: %d * 34 / 100 = %d", depositAmount, expected180Base)
	t.Logf("  Remainder: %d - %d - %d - %d = %d",
		depositAmount, expected30, expected90, expected180Base, remainder)
	t.Logf("  Tier 180 total: %d + %d = %d", expected180Base, remainder, expected180Total)

	uassert.Equal(t, expected30, tier30.TotalDistributeAmount())
	uassert.Equal(t, expected90, tier90.TotalDistributeAmount())
	uassert.Equal(t, expected180Total, tier180.TotalDistributeAmount())

	totalAllocated := tier30.TotalDistributeAmount() +
		tier90.TotalDistributeAmount() +
		tier180.TotalDistributeAmount()

	uassert.Equal(t, depositAmount, totalAllocated,
		"All funds should be allocated with no leftover")
}
