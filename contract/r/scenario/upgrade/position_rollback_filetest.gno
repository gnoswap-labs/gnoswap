// Position contract rollback scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/position"

	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/position/test"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	positionV1Path   = "gno.land/r/gnoswap/position/v1"
	positionTestPath = "gno.land/r/gnoswap/position/test"
)

func main() {
	println("[SCENARIO] Position Contract Rollback Test")
	testPositionRollback()
	println()
}

func testPositionRollback() {
	// First, upgrade to test version
	ufmt.Println("[INFO] Preparing: Upgrading to test version")
	testing.SetRealm(adminRealm)
	position.UpgradeImpl(cross, positionTestPath)

	currentVersion := position.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != positionTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back position contract to v1")
	testing.SetRealm(adminRealm)
	position.UpgradeImpl(cross, positionV1Path)

	currentVersion = position.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Position rolled back to: %s\n", currentVersion)
	if currentVersion != positionV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

// Output:
// [SCENARIO] Position Contract Rollback Test
// [INFO] Preparing: Upgrading to test version
// [INFO] Current version: gno.land/r/gnoswap/position/test
// [INFO] Rolling back position contract to v1
// [EXPECTED] Position rolled back to: gno.land/r/gnoswap/position/v1
