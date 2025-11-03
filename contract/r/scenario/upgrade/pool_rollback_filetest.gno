// Pool contract rollback scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/pool/test"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	poolV1Path   = "gno.land/r/gnoswap/pool/v1"
	poolTestPath = "gno.land/r/gnoswap/pool/test"
)

func main() {
	println("[SCENARIO] Pool Contract Rollback Test")
	testPoolRollback()
	println()
}

func testPoolRollback() {
	// First, upgrade to test version
	ufmt.Println("[INFO] Preparing: Upgrading to test version")
	testing.SetRealm(adminRealm)
	pool.UpgradeImpl(cross, poolTestPath)

	currentVersion := pool.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != poolTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back pool contract to v1")
	testing.SetRealm(adminRealm)
	pool.UpgradeImpl(cross, poolV1Path)

	currentVersion = pool.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Pool rolled back to: %s\n", currentVersion)
	if currentVersion != poolV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

// Output:
// [SCENARIO] Pool Contract Rollback Test
// [INFO] Preparing: Upgrading to test version
// [INFO] Current version: gno.land/r/gnoswap/pool/test
// [INFO] Rolling back pool contract to v1
// [EXPECTED] Pool rolled back to: gno.land/r/gnoswap/pool/v1
