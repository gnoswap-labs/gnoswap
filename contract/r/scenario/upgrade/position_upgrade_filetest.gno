// Position contract upgrade scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/position"

	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/position/v2_invalid"
)

var t = &testing.T{}

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	positionV1Path   = "gno.land/r/gnoswap/position/v1"
	positionTestPath = "gno.land/r/gnoswap/position/v2_invalid"
)

func main() {
	println("[SCENARIO] 1. Initialize position contract with v1")
	initializeV1()
	println()

	println("[SCENARIO] 2. Upgrade position contract to test version")
	testPositionUpgrade()
	println()

	println("[SCENARIO] 3. Verify test implementation panics correctly")
	verifyTestImplementation()
	println()
}

func initializeV1() {
	currentVersion := position.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current implementation: %s\n", currentVersion)

	if currentVersion != positionV1Path {
		ufmt.Println("[INFO] Setting implementation to v1")
		testing.SetRealm(adminRealm)
		position.UpgradeImpl(cross, positionV1Path)
		currentVersion = position.GetImplementationPackagePath()
	}

	ufmt.Printf("[EXPECTED] Position initialized with v1: %s\n", currentVersion)
	if currentVersion != positionV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testPositionUpgrade() {
	// Verify current version is v1
	currentVersion := position.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != positionV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading position contract to test version")
	testing.SetRealm(adminRealm)
	position.UpgradeImpl(cross, positionTestPath)

	currentVersion = position.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Position upgraded to: %s\n", currentVersion)
	if currentVersion != positionTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}
}

func verifyTestImplementation() {
	// Verify current version is test version
	currentVersion := position.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != positionTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Test Mint - should panic with test implementation message
	ufmt.Println("[INFO] Testing Mint function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: Mint not supported", func() {
		position.Mint(cross, "gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar", 500, -1000, 1000, "1000", "1000", "0", "0", 9999999999, adminAddr, adminAddr, "")
	})
	ufmt.Println("[EXPECTED] Mint panics correctly")

	// Test IncreaseLiquidity - should panic with test implementation message
	ufmt.Println("[INFO] Testing IncreaseLiquidity function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: IncreaseLiquidity not supported", func() {
		position.IncreaseLiquidity(cross, 1, "1000", "1000", "0", "0", 9999999999)
	})
	ufmt.Println("[EXPECTED] IncreaseLiquidity panics correctly")

	// Test SetPositionOperator - should panic with test implementation message
	ufmt.Println("[INFO] Testing SetPositionOperator function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: SetPositionOperator not supported", func() {
		position.SetPositionOperator(cross, 1, adminAddr)
	})
	ufmt.Println("[EXPECTED] SetPositionOperator panics correctly")

	// Test DecreaseLiquidity - should panic with test implementation message
	ufmt.Println("[INFO] Testing DecreaseLiquidity function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: DecreaseLiquidity not supported", func() {
		position.DecreaseLiquidity(cross, 1, "1000", "0", "0", 9999999999, false)
	})
	ufmt.Println("[EXPECTED] DecreaseLiquidity panics correctly")

	// Test Reposition - should panic with test implementation message
	ufmt.Println("[INFO] Testing Reposition function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: Reposition not supported", func() {
		position.Reposition(cross, 1, -2000, 2000, "1000", "1000", "0", "0")
	})
	ufmt.Println("[EXPECTED] Reposition panics correctly")

	// Test CollectFee - should panic with test implementation message
	ufmt.Println("[INFO] Testing CollectFee function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: CollectFee not supported", func() {
		position.CollectFee(cross, 1, false)
	})
	ufmt.Println("[EXPECTED] CollectFee panics correctly")
}

// Output:
// [SCENARIO] 1. Initialize position contract with v1
// [INFO] Current implementation: gno.land/r/gnoswap/position/v1
// [EXPECTED] Position initialized with v1: gno.land/r/gnoswap/position/v1
//
// [SCENARIO] 2. Upgrade position contract to test version
// [INFO] Current version: gno.land/r/gnoswap/position/v1
// [INFO] Upgrading position contract to test version
// [EXPECTED] Position upgraded to: gno.land/r/gnoswap/position/v2_invalid
//
// [SCENARIO] 3. Verify test implementation panics correctly
// [INFO] Current version: gno.land/r/gnoswap/position/v2_invalid
// [INFO] Testing Mint function panics correctly
// [EXPECTED] Mint panics correctly
// [INFO] Testing IncreaseLiquidity function panics correctly
// [EXPECTED] IncreaseLiquidity panics correctly
// [INFO] Testing SetPositionOperator function panics correctly
// [EXPECTED] SetPositionOperator panics correctly
// [INFO] Testing DecreaseLiquidity function panics correctly
// [EXPECTED] DecreaseLiquidity panics correctly
// [INFO] Testing Reposition function panics correctly
// [EXPECTED] Reposition panics correctly
// [INFO] Testing CollectFee function panics correctly
// [EXPECTED] CollectFee panics correctly
