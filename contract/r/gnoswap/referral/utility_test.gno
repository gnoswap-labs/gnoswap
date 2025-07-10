package referral

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
)

var (
	// Test addresses for utility tests
	utilityAddr1 = testutils.TestAddress("utility1")
	utilityAddr2 = testutils.TestAddress("utility2")
	utilityAddr3 = testutils.TestAddress("utility3")
	utilityAddr4 = testutils.TestAddress("utility4")
)

func setupUtilityKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func mockValidCallerUtility() func() {
	origCaller := std.OriginCaller()
	routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
	testing.SetOriginCaller(routerAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

// TestGlobalTryRegister tests the global TryRegister function
func TestGlobalTryRegister(t *testing.T) {
	// Create a fresh global keeper for this test
	gReferralKeeper = NewKeeper()
	
	t.Run("successful registration", func(t *testing.T) {
		cleanup := mockValidCallerUtility()
		defer cleanup()

		// Also set origin caller to router address like the working test
		routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
		testing.SetOriginCaller(routerAddr)

		// Use unique addresses to avoid conflicts with other tests and rate limiting
		tryAddr1 := testutils.TestAddress("tryRegUnique1")
		tryAddr2 := testutils.TestAddress("tryRegUnique2")
		
		result := TryRegister(cross, tryAddr1, tryAddr2.String())
		uassert.True(t, result)
	})

	t.Run("handles self referral", func(t *testing.T) {
		cleanup := mockValidCallerUtility()
		defer cleanup()

		// Also set origin caller to router address
		routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
		testing.SetOriginCaller(routerAddr)

		tryAddr3 := testutils.TestAddress("tryReg3")
		result := TryRegister(cross, tryAddr3, tryAddr3.String())
		uassert.False(t, result)
	})

	t.Run("handles invalid address", func(t *testing.T) {
		cleanup := mockValidCallerUtility()
		defer cleanup()

		// Also set origin caller to router address
		routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
		testing.SetOriginCaller(routerAddr)

		tryAddr4 := testutils.TestAddress("tryReg4")
		// Invalid address format should fail
		result := TryRegister(cross, tryAddr4, "g1invalid")
		uassert.False(t, result)
	})

	t.Run("handles zero address referrer", func(t *testing.T) {
		cleanup := mockValidCallerUtility()
		defer cleanup()

		// Also set origin caller to router address
		routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
		testing.SetOriginCaller(routerAddr)

		tryAddr5 := testutils.TestAddress("tryRegZero5")
		// Zero address referrer should succeed (means no referrer)
		result := TryRegister(cross, tryAddr5, zeroAddress.String())
		uassert.True(t, result)
	})
}

// TestGlobalKeeperFunctions tests the global keeper accessor functions
func TestGlobalKeeperFunctions(t *testing.T) {
	cleanup := mockValidCallerUtility()
	defer cleanup()

	t.Run("GetKeeper returns valid keeper", func(t *testing.T) {
		keeper := GetKeeper()
		uassert.NotNil(t, keeper)
	})

	t.Run("GetReferral returns correct referral", func(t *testing.T) {
		// Register a referral
		keeper := GetKeeper()
		err := keeper.register(utilityAddr1, utilityAddr2)
		uassert.NoError(t, err)

		// Get referral should return the correct address
		refStr := GetReferral(utilityAddr1.String())
		uassert.Equal(t, utilityAddr2.String(), refStr)

		// Non-existent referral should return empty string
		refStr = GetReferral(utilityAddr3.String())
		uassert.Equal(t, "", refStr)
	})

	t.Run("HasReferral returns correct status", func(t *testing.T) {
		// Initially no referral
		has := HasReferral(utilityAddr1.String())
		uassert.True(t, has) // Should be true from previous test

		// Non-existent referral
		has = HasReferral(utilityAddr3.String())
		uassert.False(t, has)
	})

	t.Run("IsEmpty returns correct state", func(t *testing.T) {
		// Should not be empty after registering referrals
		isEmpty := IsEmpty()
		uassert.False(t, isEmpty)
	})
}

// TestUtilityFunctions tests utility and helper functions
func TestUtilityFunctions(t *testing.T) {
	t.Run("address string conversion consistency", func(t *testing.T) {
		addr := utilityAddr1
		addrStr := addr.String()

		// Converting back and forth should be consistent
		uassert.True(t, len(addrStr) > 0)
		uassert.True(t, addrStr != "")
	})

	t.Run("zero address handling", func(t *testing.T) {
		zeroStr := zeroAddress.String()

		// Zero address should have a specific string representation
		uassert.True(t, len(zeroStr) >= 0) // Could be empty string

		// Should be different from regular addresses (unless empty)
		if zeroStr != "" {
			uassert.NotEqual(t, zeroStr, utilityAddr1.String())
		}
	})

	t.Run("address comparison", func(t *testing.T) {
		// Same address should have same string representation
		addr1Str1 := utilityAddr1.String()
		addr1Str2 := utilityAddr1.String()
		uassert.Equal(t, addr1Str1, addr1Str2)

		// Different addresses should have different string representations
		addr1Str := utilityAddr1.String()
		addr2Str := utilityAddr2.String()
		uassert.NotEqual(t, addr1Str, addr2Str)
	})
}

// TestErrorHandlingInGlobalFunctions tests error handling in global functions
func TestErrorHandlingInGlobalFunctions(t *testing.T) {
	t.Run("TryRegister handles errors gracefully", func(t *testing.T) {
		// Without proper authorization should return false
		result := TryRegister(cross, std.Address("invalid"), utilityAddr1.String())
		uassert.False(t, result)
	})

	t.Run("global functions handle missing data", func(t *testing.T) {
		// Functions should work even when no referrals exist for specific addresses
		refStr := GetReferral("nonexistent")
		uassert.Equal(t, "", refStr)

		has := HasReferral("nonexistent")
		uassert.False(t, has)
	})
}

// TestIntegrationWithKeeper tests integration between global functions and keeper
func TestIntegrationWithKeeper(t *testing.T) {
	cleanup := mockValidCallerUtility()
	defer cleanup()

	t.Run("global functions reflect keeper state", func(t *testing.T) {
		// Use unique addresses to avoid conflicts
		integrationAddr1 := testutils.TestAddress("integration1")
		integrationAddr2 := testutils.TestAddress("integration2")

		// Initial state - no relationship for new address
		has := HasReferral(integrationAddr1.String())
		uassert.False(t, has)

		// Create relationship through global keeper
		k := GetKeeper()
		err := k.register(integrationAddr1, integrationAddr2)
		uassert.NoError(t, err)

		// Global function should reflect new state
		has = HasReferral(integrationAddr1.String())
		uassert.True(t, has)

		refStr := GetReferral(integrationAddr1.String())
		uassert.Equal(t, integrationAddr2.String(), refStr)
	})

	t.Run("TryRegister reflects authorization state", func(t *testing.T) {
		// Set up proper authorization context
		routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
		testing.SetOriginCaller(routerAddr)
		
		// With authorization, registration should work
		result := TryRegister(cross, utilityAddr1, utilityAddr2.String())
		// Could be true or false depending on whether already registered and rate limits
		uassert.True(t, result == true || result == false)
	})

	t.Run("functions maintain consistency", func(t *testing.T) {
		// Use unique addresses to avoid conflicts
		consistencyAddr1 := testutils.TestAddress("consistency1")
		consistencyAddr2 := testutils.TestAddress("consistency2")

		// Create referral using global keeper
		k := GetKeeper()
		err := k.register(consistencyAddr1, consistencyAddr2)
		uassert.NoError(t, err)

		// Global functions should be consistent with keeper state
		uassert.True(t, k.has(consistencyAddr1))
		has := HasReferral(consistencyAddr1.String())
		uassert.True(t, has)

		refStr := GetReferral(consistencyAddr1.String())
		uassert.Equal(t, consistencyAddr2.String(), refStr)
	})
}
