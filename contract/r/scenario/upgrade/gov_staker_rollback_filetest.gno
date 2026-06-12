// PKGPATH: gno.land/r/gnoswap/v1/main

// Gov/Staker contract rollback scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	govStaker "gno.land/r/gnoswap/gov/staker"

	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/gov/staker/v2_invalid"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	govStakerV1Path   = "gno.land/r/gnoswap/gov/staker/v1"
	govStakerTestPath = "gno.land/r/gnoswap/gov/staker/v2_invalid"
)

func main(cur realm) {
	println("[SCENARIO] Gov/Staker Contract Rollback Test")
	testGovStakerRollback(cur)
	println()
}

func testGovStakerRollback(cur realm) {
	// First, upgrade to test version
	ufmt.Println("[INFO] Preparing: Upgrading to test version")
	testing.SetRealm(adminRealm)
	govStaker.UpgradeImpl(cross(cur), govStakerTestPath)

	currentVersion := govStaker.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != govStakerTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back gov/staker contract to v1")
	testing.SetRealm(adminRealm)
	govStaker.UpgradeImpl(cross(cur), govStakerV1Path)

	currentVersion = govStaker.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Gov/Staker rolled back to: %s\n", currentVersion)
	if currentVersion != govStakerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

// Output:
// [SCENARIO] Gov/Staker Contract Rollback Test
// [INFO] Preparing: Upgrading to test version
// [INFO] Current version: gno.land/r/gnoswap/gov/staker/v2_invalid
// [INFO] Rolling back gov/staker contract to v1
// [EXPECTED] Gov/Staker rolled back to: gno.land/r/gnoswap/gov/staker/v1
