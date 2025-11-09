// Pool contract upgrade scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/pool/v2_invalid"
)

var t = &testing.T{}

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	poolV1Path   = "gno.land/r/gnoswap/pool/v1"
	poolTestPath = "gno.land/r/gnoswap/pool/v2_invalid"
)

func main() {
	println("[SCENARIO] 1. Initialize pool contract with v1")
	initializeV1()
	println()

	println("[SCENARIO] 2. Upgrade pool contract to test version")
	testPoolUpgrade()
	println()

	println("[SCENARIO] 3. Verify test implementation panics correctly")
	verifyTestImplementation()
	println()
}

func initializeV1() {
	currentVersion := pool.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current implementation: %s\n", currentVersion)

	if currentVersion != poolV1Path {
		ufmt.Println("[INFO] Setting implementation to v1")
		testing.SetRealm(adminRealm)
		pool.UpgradeImpl(cross, poolV1Path)
		currentVersion = pool.GetImplementationPackagePath()
	}

	ufmt.Printf("[EXPECTED] Pool initialized with v1: %s\n", currentVersion)
	if currentVersion != poolV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testPoolUpgrade() {
	// Verify current version is v1
	currentVersion := pool.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != poolV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading pool contract to test version")
	testing.SetRealm(adminRealm)
	pool.UpgradeImpl(cross, poolTestPath)

	currentVersion = pool.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Pool upgraded to: %s\n", currentVersion)
	if currentVersion != poolTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}
}

func verifyTestImplementation() {
	// Verify current version is test version
	currentVersion := pool.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != poolTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Test CreatePool - should panic with test implementation message
	ufmt.Println("[INFO] Testing CreatePool function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: CreatePool not supported", func() {
		pool.CreatePool(cross, "gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar", 500, "79228162514264337593543950336")
	})
	ufmt.Println("[EXPECTED] CreatePool panics correctly")

	// Test SetPoolCreationFee - should panic with test implementation message
	ufmt.Println("[INFO] Testing SetPoolCreationFee function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: SetPoolCreationFee not supported", func() {
		pool.SetPoolCreationFee(cross, 100)
	})
	ufmt.Println("[EXPECTED] SetPoolCreationFee panics correctly")

	// Test SetFeeProtocol - should panic with test implementation message
	ufmt.Println("[INFO] Testing SetFeeProtocol function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: SetFeeProtocol not supported", func() {
		pool.SetFeeProtocol(cross, 6, 6)
	})
	ufmt.Println("[EXPECTED] SetFeeProtocol panics correctly")

	// Test SetWithdrawalFee - should panic with test implementation message
	ufmt.Println("[INFO] Testing SetWithdrawalFee function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: SetWithdrawalFee not supported", func() {
		pool.SetWithdrawalFee(cross, 100)
	})
	ufmt.Println("[EXPECTED] SetWithdrawalFee panics correctly")

	// Test CollectProtocol - should panic with test implementation message
	ufmt.Println("[INFO] Testing CollectProtocol function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: CollectProtocol not supported", func() {
		pool.CollectProtocol(cross, "gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar", 500, adminAddr, "100", "100")
	})
	ufmt.Println("[EXPECTED] CollectProtocol panics correctly")
}

// Output:
// [SCENARIO] 1. Initialize pool contract with v1
// [INFO] Current implementation: gno.land/r/gnoswap/pool/v1
// [EXPECTED] Pool initialized with v1: gno.land/r/gnoswap/pool/v1
//
// [SCENARIO] 2. Upgrade pool contract to test version
// [INFO] Current version: gno.land/r/gnoswap/pool/v1
// [INFO] Upgrading pool contract to test version
// [EXPECTED] Pool upgraded to: gno.land/r/gnoswap/pool/v2_invalid
//
// [SCENARIO] 3. Verify test implementation panics correctly
// [INFO] Current version: gno.land/r/gnoswap/pool/v2_invalid
// [INFO] Testing CreatePool function panics correctly
// [EXPECTED] CreatePool panics correctly
// [INFO] Testing SetPoolCreationFee function panics correctly
// [EXPECTED] SetPoolCreationFee panics correctly
// [INFO] Testing SetFeeProtocol function panics correctly
// [EXPECTED] SetFeeProtocol panics correctly
// [INFO] Testing SetWithdrawalFee function panics correctly
// [EXPECTED] SetWithdrawalFee panics correctly
// [INFO] Testing CollectProtocol function panics correctly
// [EXPECTED] CollectProtocol panics correctly
