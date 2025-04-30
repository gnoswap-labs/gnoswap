package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
)

// TestGetPossibleVotingAddressWithWeight tests the voting weight calculation functionality.
//
// The test verifies that:
// 1. All delegators can participate in voting with their current delegation amounts
// 2. Delegation records updated after endTimestamp are properly included
// 3. The latest delegation amount is used for each delegator
// 4. Empty delegation histories are handled correctly
//
// Expected behavior:
// - Each delegator's voting weight should be their latest delegation amount
// - Total voting weight should be the sum of all latest delegation amounts
// - Delegators with empty histories should not be included in results
// - The function should work correctly regardless of when delegation records were updated
func TestGetPossibleVotingAddressWithWeight(t *testing.T) {
	addr1 := testutils.TestAddress("addr1")
	addr2 := testutils.TestAddress("addr2")
	addr3 := testutils.TestAddress("addr3")

	// set timestam
	now := uint64(time.Now().Unix())
	beforeEndTime := now - 1000
	afterEndTime := now + 1000

	// case 1: normal delegation
	history1 := []DelegationSnapShotHistory{
		{
			to:           addr1,
			amount:       1000,
			updatedAt:    beforeEndTime,
			updatedBlock: 1,
		},
	}
	delegationSnapShotHistory.Set(addr1.String(), history1)

	// case 2: delegation record updated after endTimestamp
	history2 := []DelegationSnapShotHistory{
		{
			to:           addr2,
			amount:       2000,
			updatedAt:    afterEndTime,
			updatedBlock: 2,
		},
	}
	delegationSnapShotHistory.Set(addr2.String(), history2)

	// case 3: multiple delegation records
	history3 := []DelegationSnapShotHistory{
		{
			to:           addr3,
			amount:       500,
			updatedAt:    beforeEndTime - 1000,
			updatedBlock: 3,
		},
		{
			to:           addr3,
			amount:       1500,
			updatedAt:    afterEndTime,
			updatedBlock: 4,
		},
	}
	delegationSnapShotHistory.Set(addr3.String(), history3)

	// execute test
	totalWeight, addressWithWeight := GetPossibleVotingAddressWithWeight(beforeEndTime)

	expectedTotalWeight := uint64(4500) // 1000 + 2000 + 1500
	if totalWeight != expectedTotalWeight {
		t.Errorf("Expected total weight %d, got %d", expectedTotalWeight, totalWeight)
	}

	// verify each address delegation amount
	tests := []struct {
		addr           std.Address
		expectedWeight uint64
	}{
		{addr1, 1000},
		{addr2, 2000},
		{addr3, 1500},
	}

	for _, test := range tests {
		if weight, exists := addressWithWeight[test.addr]; !exists || weight != test.expectedWeight {
			t.Errorf("Expected weight %d for %s, got %d", test.expectedWeight, test.addr, weight)
		}
	}

	// test empty delegation history
	emptyAddr := testutils.TestAddress("addr4")
	delegationSnapShotHistory.Set(emptyAddr.String(), []DelegationSnapShotHistory{})

	// test empty delegation history
	totalWeight, addressWithWeight = GetPossibleVotingAddressWithWeight(beforeEndTime)
	if _, exists := addressWithWeight[emptyAddr]; exists {
		t.Error("Empty delegation history should not be included in results")
	}
}
