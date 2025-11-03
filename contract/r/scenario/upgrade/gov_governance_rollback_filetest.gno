// Gov/Governance contract rollback scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	govGovernance "gno.land/r/gnoswap/gov/governance"

	_ "gno.land/r/gnoswap/gov/governance/test"
	_ "gno.land/r/gnoswap/gov/governance/v1"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	govGovernanceV1Path   = "gno.land/r/gnoswap/gov/governance/v1"
	govGovernanceTestPath = "gno.land/r/gnoswap/gov/governance/test"
)

func main() {
	println("[SCENARIO] Gov/Governance Contract Rollback Test")
	testGovGovernanceRollback()
	println()
}

func testGovGovernanceRollback() {
	// First, upgrade to test version
	ufmt.Println("[INFO] Preparing: Upgrading to test version")
	testing.SetRealm(adminRealm)
	govGovernance.UpgradeImpl(cross, govGovernanceTestPath)

	currentVersion := govGovernance.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != govGovernanceTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back gov/governance contract to v1")
	testing.SetRealm(adminRealm)
	govGovernance.UpgradeImpl(cross, govGovernanceV1Path)

	currentVersion = govGovernance.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Gov/Governance rolled back to: %s\n", currentVersion)
	if currentVersion != govGovernanceV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

// Output:
// [SCENARIO] Gov/Governance Contract Rollback Test
// [INFO] Preparing: Upgrading to test version
// [INFO] Current version: gno.land/r/gnoswap/gov/governance/test
// [INFO] Rolling back gov/governance contract to v1
// [EXPECTED] Gov/Governance rolled back to: gno.land/r/gnoswap/gov/governance/v1
