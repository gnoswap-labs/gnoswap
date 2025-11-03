// Router contract rollback scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/router"

	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/router/test"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	routerV1Path   = "gno.land/r/gnoswap/router/v1"
	routerTestPath = "gno.land/r/gnoswap/router/test"
)

func main() {
	println("[SCENARIO] Router Contract Rollback Test")
	testRouterRollback()
	println()
}

func testRouterRollback() {
	// First, upgrade to test version
	ufmt.Println("[INFO] Preparing: Upgrading to test version")
	testing.SetRealm(adminRealm)
	router.UpgradeImpl(cross, routerTestPath)

	currentVersion := router.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != routerTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back router contract to v1")
	testing.SetRealm(adminRealm)
	router.UpgradeImpl(cross, routerV1Path)

	currentVersion = router.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Router rolled back to: %s\n", currentVersion)
	if currentVersion != routerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

// Output:
// [SCENARIO] Router Contract Rollback Test
// [INFO] Preparing: Upgrading to test version
// [INFO] Current version: gno.land/r/gnoswap/router/test
// [INFO] Rolling back router contract to v1
// [EXPECTED] Router rolled back to: gno.land/r/gnoswap/router/v1
