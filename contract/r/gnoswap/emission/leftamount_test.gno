package emission

import (
	"testing"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/gns"
)

func TestLeftAmountFix(t *testing.T) {
	resetObject(t)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross, emissionAddr, 10000000) // 10M GNS tokens

	t.Run("Verify leftAmount is correctly tracked when rounding occurs", func(t *testing.T) {
		leftGNSAmount = 0
		distributionBpsPct = avl.NewTree()

		// Set percentages that cause rounding errors
		// Total: 9999 basis points (99.99%)
		distributionBpsPct.Set("1", int64(3333)) // 33.33%
		distributionBpsPct.Set("2", int64(3333)) // 33.33%
		distributionBpsPct.Set("3", int64(3333)) // 33.33%
		distributionBpsPct.Set("4", int64(0))    // 0%

		// Distribute 10001 tokens
		amount := int64(10001)
		totalSent := distributeToTarget(cross, amount)

		// Calculate expected distribution
		// Each target gets: 10001 * 3333 / 10000 = 3333 (truncated)
		// Total distributed: 3333 * 3 = 9999
		// Left amount: 10001 - 9999 = 2

		expectedTotalSent := int64(9999)
		expectedLeftAmount := int64(2)

		uassert.Equal(t, expectedTotalSent, totalSent)

		// leftGNSAmount should be updated correctly
		actualLeftGNSAmount := GetLeftGNSAmount()
		uassert.Equal(t, expectedLeftAmount, actualLeftGNSAmount)
	})

	t.Run("Verify fix works regardless of initial leftGNSAmount value", func(t *testing.T) {
		leftGNSAmount = 0
		amount := int64(10001)
		distributeToTarget(cross, amount)

		expectedLeftAmount := int64(2)
		actualLeftGNSAmount := GetLeftGNSAmount()
		uassert.Equal(t, expectedLeftAmount, actualLeftGNSAmount)

		// Test with leftGNSAmount > 0
		leftGNSAmount = 100
		distributeToTarget(cross, amount)

		// Should still add 2 tokens (from current distribution)
		actualLeftGNSAmount = GetLeftGNSAmount()
		uassert.Equal(t, expectedLeftAmount, actualLeftGNSAmount)

		uassert.True(t, actualLeftGNSAmount > 0)
	})

	t.Run("Integration test with MintAndDistributeGns function", func(t *testing.T) {
		// Reset everything
		leftGNSAmount = 0
		lastExecutedHeight = 0
		distributionBpsPct = avl.NewTree()

		// Set percentages that cause rounding
		distributionBpsPct.Set("1", int64(3333))
		distributionBpsPct.Set("2", int64(3333))
		distributionBpsPct.Set("3", int64(3333))
		distributionBpsPct.Set("4", int64(1)) // 0.01% to make total 9999

		// Track leftGNSAmount before distribution
		beforeLeft := GetLeftGNSAmount()

		// This would normally mint and distribute GNS
		// For this test, we'll just simulate the distribution part
		amount := int64(123456) // Some amount that will have rounding
		totalSent := distributeToTarget(cross, amount)

		afterLeft := GetLeftGNSAmount()
		leftAmount := amount - totalSent

		uassert.Equal(t, leftAmount, afterLeft-beforeLeft)
	})
}
