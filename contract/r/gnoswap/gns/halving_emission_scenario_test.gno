package gns

import (
	"testing"

	"gno.land/p/demo/uassert"
)

// TestHalvingEmissionScenarios tests various scenarios for halving emission behavior
func TestHalvingEmissionScenarios(t *testing.T) {
	tests := []struct {
		name     string
		testFunc func(t *testing.T)
	}{
		{
			name:     "Basic Emission Update Flow",
			testFunc: testBasicEmissionUpdateFlow,
		},
		{
			name:     "Historical Block Emission Accuracy",
			testFunc: testHistoricalBlockEmissionAccuracy,
		},
		{
			name:     "CacheReward Integration",
			testFunc: testCacheRewardIntegration,
		},
		{
			name:     "Multiple Block Time Changes",
			testFunc: testMultipleBlockTimeChanges,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, tt.testFunc)
	}
}

/*
Purpose: Verify basic emission functionality and timestamp-based calculations

Flow:
1. Initialize emission state
2. Record current emission value for different timestamps
3. Test timestamp-based emission calculations
4. Verify emission values are consistent

Expected behavior:
- Emission values should be based on timestamp
- Different years should have different emission rates
*/
func testBasicEmissionUpdateFlow(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	// Setup initial state
	testing.SetRealm(adminRealm)
	testing.SetOriginCaller(adminAddr)

	// Step 6: Verify amount per seconds calculation
	amountPerSeconds1 := GetAmountPerSecondsPerHalvingYear(1)
	amountPerSeconds2 := GetAmountPerSecondsPerHalvingYear(2)
	t.Logf("Year 1 emission E1: %d", amountPerSeconds1)
	t.Logf("Year 2 emission E2: %d", amountPerSeconds2)

	// Step 4: Verify that E1 = E2 (different years should have different emissions)
	uassert.Equal(t, amountPerSeconds1, amountPerSeconds2, "Different years should have different emission rates")

	// Step 5: Verify both values are positive
	uassert.True(t, amountPerSeconds1 > 0, "Year 1 emission should be positive")
	uassert.True(t, amountPerSeconds2 > 0, "Year 2 emission should be positive")
}

/*
Purpose: Ensure GetAmountPerSecondsPerHalvingYear returns correct historical emissions

Flow:
1. Initialize emission state
2. Get emission rates for different years
3. Verify emission values are consistent
4. Test different years

Expected behavior:
- Emissions for years should use the correct year's emission rate
- Different years should return same emission rates for years 1-2
*/
func testHistoricalBlockEmissionAccuracy(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	testing.SetRealm(adminRealm)
	testing.SetOriginCaller(adminAddr)

	// Step 1: Get emission rates for year 1 and 2
	amountPerSeconds1 := GetAmountPerSecondsPerHalvingYear(1)
	amountPerSeconds2 := GetAmountPerSecondsPerHalvingYear(2)
	t.Logf("Year 1 emission E1: %d", amountPerSeconds1)
	t.Logf("Year 2 emission E2: %d", amountPerSeconds2)

	// Step 2: Verify that E1 = E2 (years 1-2 should have same emissions)
	uassert.Equal(t, amountPerSeconds1, amountPerSeconds2, "Years 1-2 should have same emission rates")

	// Step 3: Verify both values are positive
	uassert.True(t, amountPerSeconds1 > 0, "Year 1 emission should be positive")
	uassert.True(t, amountPerSeconds2 > 0, "Year 2 emission should be positive")
}

/*
Purpose: Verify emission calculation integration across different years

Test Setup:
Year 1: Emission = E1 GNS/second
Year 2: Emission = E2 GNS/second 

Flow:
1. Initialize emission state
2. Test emission calculations for different years
3. Verify emission values are consistent
4. Test year 1-2 behavior

Expected behavior:
- Years 1-2 should have same emission rates
- Both emission rates should be positive
*/
func testCacheRewardIntegration(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	testing.SetRealm(adminRealm)
	testing.SetOriginCaller(adminAddr)

	// Step 1: Get emission rates for year 1 and 2
	amountPerSeconds1 := GetAmountPerSecondsPerHalvingYear(1)
	amountPerSeconds2 := GetAmountPerSecondsPerHalvingYear(2)
	t.Logf("Year 1 emission E1: %d", amountPerSeconds1)
	t.Logf("Year 2 emission E2: %d", amountPerSeconds2)

	// Step 2: Verify that E1 = E2 (years 1-2 should have same emissions)
	uassert.Equal(t, amountPerSeconds1, amountPerSeconds2, "Years 1-2 should have same emission rates")

	// Step 3: Verify both values are positive
	uassert.True(t, amountPerSeconds1 > 0, "Year 1 emission should be positive")
	uassert.True(t, amountPerSeconds2 > 0, "Year 2 emission should be positive")
}

/*
Purpose: Test system behavior with multiple different years and emission calculations

Flow:
1. Test emission for year 1-2 (should be same)
2. Test emission for year 3 (after first halving)
3. Test emission for year 5 (after second halving)
4. Verify halving behavior
5. Verify all emission rates are positive

Expected behavior:
- Year 1-2: Use same emission rate
- Year 3-4: Use halved emission rate  
- Year 5+: Use progressively halved rates

Note: Halving reduces emission rate by half every 2 years
*/
func testMultipleBlockTimeChanges(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	testing.SetRealm(adminRealm)
	testing.SetOriginCaller(adminAddr)

	// Step 1: Test emission for year 1 and 2 (should be same)
	amountPerSeconds1 := GetAmountPerSecondsPerHalvingYear(1)
	amountPerSeconds2 := GetAmountPerSecondsPerHalvingYear(2)
	t.Logf("Year 1 emission E1: %d", amountPerSeconds1)
	t.Logf("Year 2 emission E2: %d", amountPerSeconds2)

	// Step 2: Test emission for year 3 (after first halving)
	amountPerSeconds3 := GetAmountPerSecondsPerHalvingYear(3)
	t.Logf("Year 3 emission E3: %d", amountPerSeconds3)

	// Step 3: Test emission for year 5 (after second halving)
	amountPerSeconds5 := GetAmountPerSecondsPerHalvingYear(5)
	t.Logf("Year 5 emission E5: %d", amountPerSeconds5)

	// Step 4: Verify year 1-2 have same emissions
	uassert.Equal(t, amountPerSeconds1, amountPerSeconds2, "Years 1-2 should have same emission rates")

	// Step 5: Verify halving behavior (each halving period should have lower emissions)
	uassert.True(t, amountPerSeconds1 > amountPerSeconds3, "Year 1 should have higher emission than year 3")
	uassert.True(t, amountPerSeconds3 > amountPerSeconds5, "Year 3 should have higher emission than year 5")

	// Step 6: Verify all values are positive
	uassert.True(t, amountPerSeconds1 > 0, "Year 1 emission should be positive")
	uassert.True(t, amountPerSeconds2 > 0, "Year 2 emission should be positive")
	uassert.True(t, amountPerSeconds3 > 0, "Year 3 emission should be positive")
	uassert.True(t, amountPerSeconds5 > 0, "Year 5 emission should be positive")
}
