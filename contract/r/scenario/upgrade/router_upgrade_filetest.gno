// Router contract upgrade scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/router"

	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/router/v2_invalid"
)

var t = &testing.T{}

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	routerV1Path   = "gno.land/r/gnoswap/router/v1"
	routerTestPath = "gno.land/r/gnoswap/router/v2_invalid"
)

func main() {
	println("[SCENARIO] 1. Initialize router contract with v1")
	initializeV1()
	println()

	println("[SCENARIO] 2. Upgrade router contract to test version")
	testRouterUpgrade()
	println()

	println("[SCENARIO] 3. Verify test implementation panics correctly")
	verifyTestImplementation()
	println()
}

func initializeV1() {
	currentVersion := router.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current implementation: %s\n", currentVersion)

	if currentVersion != routerV1Path {
		ufmt.Println("[INFO] Setting implementation to v1")
		testing.SetRealm(adminRealm)
		router.UpgradeImpl(cross, routerV1Path)
		currentVersion = router.GetImplementationPackagePath()
	}

	ufmt.Printf("[EXPECTED] Router initialized with v1: %s\n", currentVersion)
	if currentVersion != routerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testRouterUpgrade() {
	// Verify current version is v1
	currentVersion := router.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != routerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading router contract to test version")
	testing.SetRealm(adminRealm)
	router.UpgradeImpl(cross, routerTestPath)

	currentVersion = router.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Router upgraded to: %s\n", currentVersion)
	if currentVersion != routerTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}
}

func verifyTestImplementation() {
	// Verify current version is test version
	currentVersion := router.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != routerTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Test ExactInSwapRoute - should panic with test implementation message
	ufmt.Println("[INFO] Testing ExactInSwapRoute function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: ExactInSwapRoute not supported", func() {
		router.ExactInSwapRoute(cross, "gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar", "1000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "500", "0", 9999999999, "")
	})
	ufmt.Println("[EXPECTED] ExactInSwapRoute panics correctly")

	// Test SetSwapFee - should panic with test implementation message
	ufmt.Println("[INFO] Testing SetSwapFee function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: SetSwapFee not supported", func() {
		router.SetSwapFee(cross, 15)
	})
	ufmt.Println("[EXPECTED] SetSwapFee panics correctly")

	// Test ExactInSingleSwapRoute - should panic with test implementation message
	ufmt.Println("[INFO] Testing ExactInSingleSwapRoute function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: ExactInSingleSwapRoute not supported", func() {
		router.ExactInSingleSwapRoute(cross, "gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar", "1000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "0", "0", 9999999999, "")
	})
	ufmt.Println("[EXPECTED] ExactInSingleSwapRoute panics correctly")

	// Test ExactOutSwapRoute - should panic with test implementation message
	ufmt.Println("[INFO] Testing ExactOutSwapRoute function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: ExactOutSwapRoute not supported", func() {
		router.ExactOutSwapRoute(cross, "gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar", "1000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "500", "10000", 9999999999, "")
	})
	ufmt.Println("[EXPECTED] ExactOutSwapRoute panics correctly")

	// Test ExactOutSingleSwapRoute - should panic with test implementation message
	ufmt.Println("[INFO] Testing ExactOutSingleSwapRoute function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: ExactOutSingleSwapRoute not supported", func() {
		router.ExactOutSingleSwapRoute(cross, "gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar", "1000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "10000", "0", 9999999999, "")
	})
	ufmt.Println("[EXPECTED] ExactOutSingleSwapRoute panics correctly")
}

// Output:
// [SCENARIO] 1. Initialize router contract with v1
// [INFO] Current implementation: gno.land/r/gnoswap/router/v1
// [EXPECTED] Router initialized with v1: gno.land/r/gnoswap/router/v1
//
// [SCENARIO] 2. Upgrade router contract to test version
// [INFO] Current version: gno.land/r/gnoswap/router/v1
// [INFO] Upgrading router contract to test version
// [EXPECTED] Router upgraded to: gno.land/r/gnoswap/router/v2_invalid
//
// [SCENARIO] 3. Verify test implementation panics correctly
// [INFO] Current version: gno.land/r/gnoswap/router/v2_invalid
// [INFO] Testing ExactInSwapRoute function panics correctly
// [EXPECTED] ExactInSwapRoute panics correctly
// [INFO] Testing SetSwapFee function panics correctly
// [EXPECTED] SetSwapFee panics correctly
// [INFO] Testing ExactInSingleSwapRoute function panics correctly
// [EXPECTED] ExactInSingleSwapRoute panics correctly
// [INFO] Testing ExactOutSwapRoute function panics correctly
// [EXPECTED] ExactOutSwapRoute panics correctly
// [INFO] Testing ExactOutSingleSwapRoute function panics correctly
// [EXPECTED] ExactOutSingleSwapRoute panics correctly
