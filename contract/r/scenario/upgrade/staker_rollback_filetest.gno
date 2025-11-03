// Staker contract rollback scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/staker"

	_ "gno.land/r/gnoswap/staker/v1"
	_ "gno.land/r/gnoswap/staker/test"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	stakerV1Path   = "gno.land/r/gnoswap/staker/v1"
	stakerTestPath = "gno.land/r/gnoswap/staker/test"
)

func main() {
	println("[SCENARIO] Staker Contract Rollback Test")
	testStakerRollback()
	println()
}

func testStakerRollback() {
	// First, upgrade to test version
	ufmt.Println("[INFO] Preparing: Upgrading to test version")
	testing.SetRealm(adminRealm)
	staker.UpgradeImpl(cross, stakerTestPath)

	currentVersion := staker.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != stakerTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back staker contract to v1")
	testing.SetRealm(adminRealm)
	staker.UpgradeImpl(cross, stakerV1Path)

	currentVersion = staker.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Staker rolled back to: %s\n", currentVersion)
	if currentVersion != stakerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

// Output:
// [SCENARIO] Staker Contract Rollback Test
// [INFO] Preparing: Upgrading to test version
// [INFO] Current version: gno.land/r/gnoswap/staker/test
// [INFO] Rolling back staker contract to v1
// [EXPECTED] Staker rolled back to: gno.land/r/gnoswap/staker/v1
