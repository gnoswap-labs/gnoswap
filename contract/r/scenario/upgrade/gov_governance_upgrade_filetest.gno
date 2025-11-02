// Gov/Governance contract upgrade scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	govGovernance "gno.land/r/gnoswap/gov/governance"

	_ "gno.land/r/gnoswap/gov/governance/test"
	_ "gno.land/r/gnoswap/gov/governance/v1"
)

var t = &testing.T{}

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	govGovernanceV1Path   = "gno.land/r/gnoswap/gov/governance/v1"
	govGovernanceTestPath = "gno.land/r/gnoswap/gov/governance/test"
)

func main() {
	println("[SCENARIO] 1. Initialize gov/governance contract with v1")
	initializeV1()
	println()

	println("[SCENARIO] 2. Upgrade gov/governance contract to test version")
	testGovGovernanceUpgrade()
	println()

	println("[SCENARIO] 3. Verify test implementation panics correctly")
	verifyTestImplementation()
	println()
}

func initializeV1() {
	currentVersion := govGovernance.GetImplementationPackagePath()

	if currentVersion != govGovernanceV1Path {
		testing.SetRealm(adminRealm)
		govGovernance.UpgradeImpl(cross, govGovernanceV1Path)
		currentVersion = govGovernance.GetImplementationPackagePath()
	}

	ufmt.Printf("[EXPECTED] Gov/Governance initialized with v1: %s\n", currentVersion)
	if currentVersion != govGovernanceV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testGovGovernanceUpgrade() {
	// Verify current version is v1
	currentVersion := govGovernance.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != govGovernanceV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading gov/governance contract to test version")
	testing.SetRealm(adminRealm)
	govGovernance.UpgradeImpl(cross, govGovernanceTestPath)

	currentVersion = govGovernance.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Gov/Governance upgraded to: %s\n", currentVersion)
	if currentVersion != govGovernanceTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}
}

func verifyTestImplementation() {
	// Verify current version is test version
	currentVersion := govGovernance.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != govGovernanceTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Test ProposeText - should panic with test implementation message
	ufmt.Println("[INFO] Testing ProposeText function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: ProposeText not supported", func() {
		govGovernance.ProposeText(cross, "Test Title", "Test Description")
	})
	ufmt.Println("[EXPECTED] ProposeText panics correctly")

	// Test Vote - should panic with test implementation message
	ufmt.Println("[INFO] Testing Vote function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: Vote not supported", func() {
		govGovernance.Vote(cross, 1, true)
	})
	ufmt.Println("[EXPECTED] Vote panics correctly")

	// Test Execute - should panic with test implementation message
	ufmt.Println("[INFO] Testing Execute function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: Execute not supported", func() {
		govGovernance.Execute(cross, 1)
	})
	ufmt.Println("[EXPECTED] Execute panics correctly")

	// Test ProposeCommunityPoolSpend - should panic with test implementation message
	ufmt.Println("[INFO] Testing ProposeCommunityPoolSpend function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: ProposeCommunityPoolSpend not supported", func() {
		govGovernance.ProposeCommunityPoolSpend(cross, "Test Title", "Test Description", adminAddr, "gno.land/r/onbloc/foo", 1000)
	})
	ufmt.Println("[EXPECTED] ProposeCommunityPoolSpend panics correctly")

	// Test ProposeParameterChange - should panic with test implementation message
	ufmt.Println("[INFO] Testing ProposeParameterChange function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: ProposeParameterChange not supported", func() {
		govGovernance.ProposeParameterChange(cross, "Test Title", "Test Description", 1, "{}")
	})
	ufmt.Println("[EXPECTED] ProposeParameterChange panics correctly")

	// Test Cancel - should panic with test implementation message
	ufmt.Println("[INFO] Testing Cancel function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: Cancel not supported", func() {
		govGovernance.Cancel(cross, 1)
	})
	ufmt.Println("[EXPECTED] Cancel panics correctly")

	// Test Reconfigure - should panic with test implementation message
	ufmt.Println("[INFO] Testing Reconfigure function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: Reconfigure not supported", func() {
		govGovernance.Reconfigure(cross, 100, 100, 100, 100, 100, 100, 100)
	})
	ufmt.Println("[EXPECTED] Reconfigure panics correctly")
}

// Output:
// [SCENARIO] 1. Initialize gov/governance contract with v1
// [EXPECTED] Gov/Governance initialized with v1: gno.land/r/gnoswap/gov/governance/v1
//
// [SCENARIO] 2. Upgrade gov/governance contract to test version
// [INFO] Current version: gno.land/r/gnoswap/gov/governance/v1
// [INFO] Upgrading gov/governance contract to test version
// [EXPECTED] Gov/Governance upgraded to: gno.land/r/gnoswap/gov/governance/test
//
// [SCENARIO] 3. Verify test implementation panics correctly
// [INFO] Current version: gno.land/r/gnoswap/gov/governance/test
// [INFO] Testing ProposeText function panics correctly
// [EXPECTED] ProposeText panics correctly
// [INFO] Testing Vote function panics correctly
// [EXPECTED] Vote panics correctly
// [INFO] Testing Execute function panics correctly
// [EXPECTED] Execute panics correctly
// [INFO] Testing ProposeCommunityPoolSpend function panics correctly
// [EXPECTED] ProposeCommunityPoolSpend panics correctly
// [INFO] Testing ProposeParameterChange function panics correctly
// [EXPECTED] ProposeParameterChange panics correctly
// [INFO] Testing Cancel function panics correctly
// [EXPECTED] Cancel panics correctly
// [INFO] Testing Reconfigure function panics correctly
// [EXPECTED] Reconfigure panics correctly
