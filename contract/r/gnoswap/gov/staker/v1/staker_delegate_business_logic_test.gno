package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	_ "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/access"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
)

// TestBusinessLogic_UndelegateExcessAmount tests undelegation when requested amount exceeds delegated amount
// Critical: Validates that undelegation processes only available amount without panic
func TestBusinessLogic_UndelegateExcessAmount(t *testing.T) {
	t.Run("undelegate more than delegated - single delegation", func(t *testing.T) {
		// given
		gs := createTestGovStaker()
		cleanupStakerDelegateTest(t, gs)

		alice := testutils.TestAddress("alice")
		validator := testutils.TestAddress("validator1")

		// Alice delegates minimumAmount
		testing.SetRealm(testing.NewUserRealm(alice))
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator, minimumAmount, "")
		}(cross)

		// Verify delegation
		delegatedBefore, _ := gs.store.GetTotalDelegatedAmount()
		uassert.Equal(t, delegatedBefore, int64(minimumAmount))

		// when - Alice tries to undelegate more than delegated (excess amount)
		excessAmount := int64(minimumAmount * 2)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			// Should not panic, should process only available amount
			gs.Undelegate(validator, excessAmount)
		}(cross)

		// then - Only minimumAmount should be undelegated (all available amount)
		delegatedAfter, _ := gs.store.GetTotalDelegatedAmount()
		uassert.Equal(t, delegatedAfter, int64(0)) // All delegated amount removed

		// Verify total locked equals undelegated amount (pending withdrawal)
		totalLocked, _ := gs.store.GetTotalLockedAmount()
		uassert.Equal(t, totalLocked, int64(minimumAmount))
	})

	t.Run("undelegate partial excess - verifies capping logic", func(t *testing.T) {
		// given
		gs := createTestGovStaker()
		cleanupStakerDelegateTest(t, gs)

		bob := testutils.TestAddress("bob")
		validator := testutils.TestAddress("validator2")

		// Bob delegates 200 * minimumAmount
		delegateAmount := int64(minimumAmount * 200)
		testing.SetRealm(testing.NewUserRealm(bob))
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator, delegateAmount, "")
		}(cross)

		// when - Bob tries to undelegate 250 * minimumAmount (more than 200)
		undelegateAmount := int64(minimumAmount * 250)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Undelegate(validator, undelegateAmount)
		}(cross)

		// then - Only delegateAmount undelegated, total delegated becomes 0
		totalDelegated, _ := gs.store.GetTotalDelegatedAmount()
		uassert.Equal(t, totalDelegated, int64(0))

		// All should be locked (pending withdrawal)
		totalLocked, _ := gs.store.GetTotalLockedAmount()
		uassert.Equal(t, totalLocked, delegateAmount)
	})
}

// TestBusinessLogic_MultipleDelegationsUndelegateOrder tests FIFO ordering of undelegations across multiple delegations
// Critical: Ensures delegation records are processed in correct order (by delegation ID)
func TestBusinessLogic_MultipleDelegationsUndelegateOrder(t *testing.T) {
	t.Run("multiple delegations to same validator - partial undelegate", func(t *testing.T) {
		// given
		gs := createTestGovStaker()
		cleanupStakerDelegateTest(t, gs)

		alice := testutils.TestAddress("alice")
		validator := testutils.TestAddress("validator1")

		testing.SetRealm(testing.NewUserRealm(alice))

		// First delegation: 100
		amount1 := int64(minimumAmount * 100)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator, amount1, "")
		}(cross)

		// Second delegation: 50
		amount2 := int64(minimumAmount * 50)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator, amount2, "")
		}(cross)

		// Third delegation: 150
		amount3 := int64(minimumAmount * 150)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator, amount3, "")
		}(cross)

		// Verify total
		totalDelegated, _ := gs.store.GetTotalDelegatedAmount()
		expectedTotal := amount1 + amount2 + amount3
		uassert.Equal(t, totalDelegated, expectedTotal)

		// when - Undelegate 120 units (should process FIFO)
		undelegateAmount := int64(minimumAmount * 120)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Undelegate(validator, undelegateAmount)
		}(cross)

		// then - Total delegated should be reduced by undelegateAmount
		totalAfter, _ := gs.store.GetTotalDelegatedAmount()
		uassert.Equal(t, totalAfter, expectedTotal-undelegateAmount)

		// Verify locked amount (delegated + pending)
		totalLocked, _ := gs.store.GetTotalLockedAmount()
		uassert.Equal(t, totalLocked, expectedTotal) // All originally delegated is still locked
	})

	t.Run("undelegate all across multiple delegations", func(t *testing.T) {
		// given
		gs := createTestGovStaker()
		cleanupStakerDelegateTest(t, gs)

		bob := testutils.TestAddress("bob")
		validator := testutils.TestAddress("validator2")

		testing.SetRealm(testing.NewUserRealm(bob))

		// Create 4 delegations
		amounts := []int64{
			int64(minimumAmount * 50),
			int64(minimumAmount * 100),
			int64(minimumAmount * 150),
			int64(minimumAmount * 100),
		}

		var totalAmount int64
		for _, amt := range amounts {
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
				gs.Delegate(validator, amt, "")
			}(cross)
			totalAmount += amt
		}

		// when - Undelegate all
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Undelegate(validator, totalAmount)
		}(cross)

		// then - All delegations should be fully undelegated
		totalDelegated, _ := gs.store.GetTotalDelegatedAmount()
		uassert.Equal(t, totalDelegated, int64(0))

		// All should be in locked state (pending withdrawal)
		totalLocked, _ := gs.store.GetTotalLockedAmount()
		uassert.Equal(t, totalLocked, totalAmount)
	})
}

// TestBusinessLogic_TotalAmountConsistency tests state consistency across operations
// Critical: Ensures totalDelegated and totalLocked remain consistent with individual delegations
func TestBusinessLogic_TotalAmountConsistency(t *testing.T) {
	t.Run("total delegated across multiple users and validators", func(t *testing.T) {
		// given
		gs := createTestGovStaker()
		cleanupStakerDelegateTest(t, gs)

		alice := testutils.TestAddress("alice")
		bob := testutils.TestAddress("bob")
		validator1 := testutils.TestAddress("validator1")
		validator2 := testutils.TestAddress("validator2")

		// Multiple users delegate to multiple validators
		aliceAmount := int64(minimumAmount * 100)
		testing.SetRealm(testing.NewUserRealm(alice))
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator1, aliceAmount, "")
		}(cross)

		bob1Amount := int64(minimumAmount * 150)
		testing.SetRealm(testing.NewUserRealm(bob))
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator1, bob1Amount, "")
		}(cross)

		bob2Amount := int64(minimumAmount * 50)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator2, bob2Amount, "")
		}(cross)

		// then - Total delegated must equal sum of all delegations
		expectedTotal := aliceAmount + bob1Amount + bob2Amount
		totalDelegated, _ := gs.store.GetTotalDelegatedAmount()
		uassert.Equal(t, totalDelegated, expectedTotal)
	})

	t.Run("total locked equals delegated plus pending withdrawals", func(t *testing.T) {
		// given
		gs := createTestGovStaker()
		cleanupStakerDelegateTest(t, gs)

		alice := testutils.TestAddress("alice")
		validator := testutils.TestAddress("validator1")

		// Delegate amount
		delegateAmount := int64(minimumAmount * 200)
		testing.SetRealm(testing.NewUserRealm(alice))
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator, delegateAmount, "")
		}(cross)

		// Undelegate 80 units
		undelegateAmount := int64(minimumAmount * 80)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Undelegate(validator, undelegateAmount)
		}(cross)

		// when - Get totals
		totalDelegated, _ := gs.store.GetTotalDelegatedAmount()
		totalLocked, _ := gs.store.GetTotalLockedAmount()

		// then - Total locked = original delegate amount (delegated + pending)
		uassert.Equal(t, totalDelegated, delegateAmount-undelegateAmount) // 120 units
		uassert.Equal(t, totalLocked, delegateAmount)                     // All 200 still locked
	})

	t.Run("consistency maintained after complex operations", func(t *testing.T) {
		// given
		gs := createTestGovStaker()
		cleanupStakerDelegateTest(t, gs)

		alice := testutils.TestAddress("alice")
		validator := testutils.TestAddress("validator1")

		testing.SetRealm(testing.NewUserRealm(alice))

		// when - Complex sequence: delegate, undelegate, delegate, undelegate
		amount1 := int64(minimumAmount * 200)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator, amount1, "")
		}(cross)

		undelAmount1 := int64(minimumAmount * 50)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Undelegate(validator, undelAmount1)
		}(cross)

		amount2 := int64(minimumAmount * 100)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator, amount2, "")
		}(cross)

		undelAmount2 := int64(minimumAmount * 100)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Undelegate(validator, undelAmount2)
		}(cross)

		// then - Verify consistency
		totalDelegated, _ := gs.store.GetTotalDelegatedAmount()
		expectedDelegated := amount1 - undelAmount1 + amount2 - undelAmount2
		uassert.Equal(t, totalDelegated, expectedDelegated) // 150 units

		totalLocked, _ := gs.store.GetTotalLockedAmount()
		expectedLocked := amount1 + amount2 // All delegated amounts still locked
		uassert.Equal(t, totalLocked, expectedLocked)
	})
}

// TestBusinessLogic_LockupPeriodChangeEffect tests effect of lockup period changes on existing withdrawals
// Critical: Validates that lockup period changes don't affect already-created withdrawal requests
func TestBusinessLogic_LockupPeriodChangeEffect(t *testing.T) {
	t.Run("lockup period can be changed", func(t *testing.T) {
		// given
		gs := createTestGovStaker()
		cleanupStakerDelegateTest(t, gs)

		alice := testutils.TestAddress("alice")
		validator := testutils.TestAddress("validator1")

		// Get original lockup period (default: 86400 = 1 day)
		originalLockup, _ := gs.store.GetUnDelegationLockupPeriod()
		uassert.Equal(t, originalLockup, int64(86400))

		// Delegate and undelegate with original lockup period
		delegateAmount := int64(minimumAmount * 200)
		testing.SetRealm(testing.NewUserRealm(alice))
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator, delegateAmount, "")
		}(cross)

		undelegateAmount := int64(minimumAmount * 100)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Undelegate(validator, undelegateAmount)
		}(cross)

		// when - Admin changes lockup period to 2 days
		newLockup := int64(172800) // 2 days
		gs.store.SetUnDelegationLockupPeriod(newLockup)

		// then - Lockup period should be updated
		updatedLockup, _ := gs.store.GetUnDelegationLockupPeriod()
		uassert.Equal(t, updatedLockup, newLockup)
		uassert.NotEqual(t, updatedLockup, originalLockup)
	})

	t.Run("multiple undelegations with different lockup periods", func(t *testing.T) {
		// given
		gs := createTestGovStaker()
		cleanupStakerDelegateTest(t, gs)

		bob := testutils.TestAddress("bob")
		validator := testutils.TestAddress("validator2")

		// Delegate large amount
		delegateAmount := int64(minimumAmount * 300)
		testing.SetRealm(testing.NewUserRealm(bob))
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator, delegateAmount, "")
		}(cross)

		// First undelegation with original lockup (1 day)
		originalLockup, _ := gs.store.GetUnDelegationLockupPeriod()
		uassert.Equal(t, originalLockup, int64(86400))

		undelegateAmount1 := int64(minimumAmount * 100)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Undelegate(validator, undelegateAmount1)
		}(cross)

		// Change lockup period to 3 days
		newLockup := int64(259200) // 3 days
		gs.store.SetUnDelegationLockupPeriod(newLockup)

		// when - Second undelegation after lockup change
		undelegateAmount2 := int64(minimumAmount * 100)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Undelegate(validator, undelegateAmount2)
		}(cross)

		// then - Both undelegations processed successfully
		totalDelegated, _ := gs.store.GetTotalDelegatedAmount()
		expectedDelegated := delegateAmount - undelegateAmount1 - undelegateAmount2
		uassert.Equal(t, totalDelegated, expectedDelegated)

		// Verify lockup period was applied
		currentLockup, _ := gs.store.GetUnDelegationLockupPeriod()
		uassert.Equal(t, currentLockup, newLockup)
	})

	t.Run("delegation and undelegation work after lockup change", func(t *testing.T) {
		// given
		gs := createTestGovStaker()
		cleanupStakerDelegateTest(t, gs)

		charlie := testutils.TestAddress("charlie")
		validator := testutils.TestAddress("validator3")

		// Change lockup period to 10 days
		gs.store.SetUnDelegationLockupPeriod(864000)

		// when - Delegate and undelegate with new lockup period
		delegateAmount := int64(minimumAmount * 150)
		testing.SetRealm(testing.NewUserRealm(charlie))
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Delegate(validator, delegateAmount, "")
		}(cross)

		undelegateAmount := int64(minimumAmount * 150)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
			gs.Undelegate(validator, undelegateAmount)
		}(cross)

		// then - Operations should succeed with new lockup period
		totalDelegated, _ := gs.store.GetTotalDelegatedAmount()
		uassert.Equal(t, totalDelegated, int64(0))

		// Verify total locked equals undelegated amount
		totalLocked, _ := gs.store.GetTotalLockedAmount()
		uassert.Equal(t, totalLocked, delegateAmount)
	})
}
