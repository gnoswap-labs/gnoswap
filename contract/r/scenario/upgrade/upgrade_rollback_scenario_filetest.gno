// Upgrade and rollback scenario test for all upgradable contracts
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"

	// Import v1 contracts for initial registration
	_ "gno.land/r/gnoswap/gov/governance/v1"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	// Import test implementation contracts for upgrade
	_ "gno.land/r/gnoswap/gov/governance/test"
	_ "gno.land/r/gnoswap/gov/staker/test"
	_ "gno.land/r/gnoswap/pool/test"
	_ "gno.land/r/gnoswap/position/test"
	_ "gno.land/r/gnoswap/protocol_fee/test"
	_ "gno.land/r/gnoswap/router/test"
	_ "gno.land/r/gnoswap/staker/test"

	govGovernance "gno.land/r/gnoswap/gov/governance"
	govStaker "gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	protocolFee "gno.land/r/gnoswap/protocol_fee"
	"gno.land/r/gnoswap/router"
	"gno.land/r/gnoswap/staker"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

// Contract package paths
const (
	// V1 package paths
	govGovernanceV1Path = "gno.land/r/gnoswap/gov/governance/v1"
	govStakerV1Path     = "gno.land/r/gnoswap/gov/staker/v1"
	poolV1Path          = "gno.land/r/gnoswap/pool/v1"
	positionV1Path      = "gno.land/r/gnoswap/position/v1"
	protocolFeeV1Path   = "gno.land/r/gnoswap/protocol_fee/v1"
	routerV1Path        = "gno.land/r/gnoswap/router/v1"
	stakerV1Path        = "gno.land/r/gnoswap/staker/v1"

	// Test package paths
	govGovernanceTestPath = "gno.land/r/gnoswap/gov/governance/test"
	govStakerTestPath     = "gno.land/r/gnoswap/gov/staker/test"
	poolTestPath          = "gno.land/r/gnoswap/pool/test"
	positionTestPath      = "gno.land/r/gnoswap/position/test"
	protocolFeeTestPath   = "gno.land/r/gnoswap/protocol_fee/test"
	routerTestPath        = "gno.land/r/gnoswap/router/test"
	stakerTestPath        = "gno.land/r/gnoswap/staker/test"
)

func main() {
	println("[SCENARIO] 1. Initialize all contracts with v1")
	initializeV1()
	println()

	println("[SCENARIO] 2. Test Pool Contract Upgrade and Rollback")
	testPoolUpgradeRollback()
	println()

	println("[SCENARIO] 3. Test Position Contract Upgrade and Rollback")
	testPositionUpgradeRollback()
	println()

	println("[SCENARIO] 4. Test ProtocolFee Contract Upgrade and Rollback")
	testProtocolFeeUpgradeRollback()
	println()

	println("[SCENARIO] 5. Test Router Contract Upgrade and Rollback")
	testRouterUpgradeRollback()
	println()

	println("[SCENARIO] 6. Test Staker Contract Upgrade and Rollback")
	testStakerUpgradeRollback()
	println()

	println("[SCENARIO] 7. Test Gov/Governance Contract Upgrade and Rollback")
	testGovGovernanceUpgradeRollback()
	println()

	println("[SCENARIO] 8. Test Gov/Staker Contract Upgrade and Rollback")
	testGovStakerUpgradeRollback()
	println()
}

func initializeV1() {
	testing.SetRealm(adminRealm)
	pool.UpgradeImpl(cross, poolV1Path)
	position.UpgradeImpl(cross, positionV1Path)
	protocolFee.UpgradeImpl(cross, protocolFeeV1Path)
	router.UpgradeImpl(cross, routerV1Path)
	staker.UpgradeImpl(cross, stakerV1Path)
	govGovernance.UpgradeImpl(cross, govGovernanceV1Path)
	govStaker.UpgradeImpl(cross, govStakerV1Path)

	println("[INFO] All contracts initialized with v1")
	println("[EXPECTED] All pool implementations path is: %s", poolV1Path)
	println("[EXPECTED] All position implementations path is: %s", positionV1Path)
	println("[EXPECTED] All protocolFee implementations path is: %s", protocolFeeV1Path)
	println("[EXPECTED] All router implementations path is: %s", routerV1Path)
	println("[EXPECTED] All staker implementations path is: %s", stakerV1Path)
	println("[EXPECTED] All govGovernance implementations path is: %s", govGovernanceV1Path)
	println("[EXPECTED] All govStaker implementations path is: %s", govStakerV1Path)
}

func testPoolUpgradeRollback() {
	// Check initial state
	currentVersion := pool.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Initial version: %s\n", currentVersion)
	if currentVersion != poolV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading to test version")
	testing.SetRealm(adminRealm)
	pool.UpgradeImpl(cross, poolTestPath)
	currentVersion = pool.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Upgraded to: %s\n", currentVersion)
	if currentVersion != poolTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back to v1")
	testing.SetRealm(adminRealm)
	pool.UpgradeImpl(cross, poolV1Path)
	currentVersion = pool.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Rolled back to: %s\n", currentVersion)
	if currentVersion != poolV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testPositionUpgradeRollback() {
	// Check initial state
	currentVersion := position.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Initial version: %s\n", currentVersion)
	if currentVersion != positionV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading to test version")
	testing.SetRealm(adminRealm)
	position.UpgradeImpl(cross, positionTestPath)
	currentVersion = position.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Upgraded to: %s\n", currentVersion)
	if currentVersion != positionTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back to v1")
	testing.SetRealm(adminRealm)
	position.UpgradeImpl(cross, positionV1Path)
	currentVersion = position.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Rolled back to: %s\n", currentVersion)
	if currentVersion != positionV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testProtocolFeeUpgradeRollback() {
	// Check initial state
	currentVersion := protocolFee.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Initial version: %s\n", currentVersion)
	if currentVersion != protocolFeeV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading to test version")
	testing.SetRealm(adminRealm)
	protocolFee.UpgradeImpl(cross, protocolFeeTestPath)
	currentVersion = protocolFee.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Upgraded to: %s\n", currentVersion)
	if currentVersion != protocolFeeTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back to v1")
	testing.SetRealm(adminRealm)
	protocolFee.UpgradeImpl(cross, protocolFeeV1Path)
	currentVersion = protocolFee.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Rolled back to: %s\n", currentVersion)
	if currentVersion != protocolFeeV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testRouterUpgradeRollback() {
	// Check initial state
	currentVersion := router.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Initial version: %s\n", currentVersion)
	if currentVersion != routerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading to test version")
	testing.SetRealm(adminRealm)
	router.UpgradeImpl(cross, routerTestPath)
	currentVersion = router.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Upgraded to: %s\n", currentVersion)
	if currentVersion != routerTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back to v1")
	testing.SetRealm(adminRealm)
	router.UpgradeImpl(cross, routerV1Path)
	currentVersion = router.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Rolled back to: %s\n", currentVersion)
	if currentVersion != routerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testStakerUpgradeRollback() {
	// Check initial state
	currentVersion := staker.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Initial version: %s\n", currentVersion)
	if currentVersion != stakerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading to test version")
	testing.SetRealm(adminRealm)
	staker.UpgradeImpl(cross, stakerTestPath)
	currentVersion = staker.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Upgraded to: %s\n", currentVersion)
	if currentVersion != stakerTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back to v1")
	testing.SetRealm(adminRealm)
	staker.UpgradeImpl(cross, stakerV1Path)
	currentVersion = staker.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Rolled back to: %s\n", currentVersion)
	if currentVersion != stakerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testGovGovernanceUpgradeRollback() {
	// Check initial state
	currentVersion := govGovernance.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Initial version: %s\n", currentVersion)
	if currentVersion != govGovernanceV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading to test version")
	testing.SetRealm(adminRealm)
	govGovernance.UpgradeImpl(cross, govGovernanceTestPath)
	currentVersion = govGovernance.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Upgraded to: %s\n", currentVersion)
	if currentVersion != govGovernanceTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back to v1")
	testing.SetRealm(adminRealm)
	govGovernance.UpgradeImpl(cross, govGovernanceV1Path)
	currentVersion = govGovernance.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Rolled back to: %s\n", currentVersion)
	if currentVersion != govGovernanceV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testGovStakerUpgradeRollback() {
	// Check initial state
	currentVersion := govStaker.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Initial version: %s\n", currentVersion)
	if currentVersion != govStakerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading to test version")
	testing.SetRealm(adminRealm)
	govStaker.UpgradeImpl(cross, govStakerTestPath)
	currentVersion = govStaker.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Upgraded to: %s\n", currentVersion)
	if currentVersion != govStakerTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back to v1")
	testing.SetRealm(adminRealm)
	govStaker.UpgradeImpl(cross, govStakerV1Path)
	currentVersion = govStaker.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Rolled back to: %s\n", currentVersion)
	if currentVersion != govStakerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

// Output:
// [SCENARIO] 1. Initialize all contracts with v1
// [INFO] All contracts initialized with v1
// [EXPECTED] All pool implementations path is: %s gno.land/r/gnoswap/pool/v1
// [EXPECTED] All position implementations path is: %s gno.land/r/gnoswap/position/v1
// [EXPECTED] All protocolFee implementations path is: %s gno.land/r/gnoswap/protocol_fee/v1
// [EXPECTED] All router implementations path is: %s gno.land/r/gnoswap/router/v1
// [EXPECTED] All staker implementations path is: %s gno.land/r/gnoswap/staker/v1
// [EXPECTED] All govGovernance implementations path is: %s gno.land/r/gnoswap/gov/governance/v1
// [EXPECTED] All govStaker implementations path is: %s gno.land/r/gnoswap/gov/staker/v1
//
// [SCENARIO] 2. Test Pool Contract Upgrade and Rollback
// [INFO] Initial version: gno.land/r/gnoswap/pool/v1
// [INFO] Upgrading to test version
// [EXPECTED] Upgraded to: gno.land/r/gnoswap/pool/test
// [INFO] Rolling back to v1
// [EXPECTED] Rolled back to: gno.land/r/gnoswap/pool/v1
//
// [SCENARIO] 3. Test Position Contract Upgrade and Rollback
// [INFO] Initial version: gno.land/r/gnoswap/position/v1
// [INFO] Upgrading to test version
// [EXPECTED] Upgraded to: gno.land/r/gnoswap/position/test
// [INFO] Rolling back to v1
// [EXPECTED] Rolled back to: gno.land/r/gnoswap/position/v1
//
// [SCENARIO] 4. Test ProtocolFee Contract Upgrade and Rollback
// [INFO] Initial version: gno.land/r/gnoswap/protocol_fee/v1
// [INFO] Upgrading to test version
// [EXPECTED] Upgraded to: gno.land/r/gnoswap/protocol_fee/test
// [INFO] Rolling back to v1
// [EXPECTED] Rolled back to: gno.land/r/gnoswap/protocol_fee/v1
//
// [SCENARIO] 5. Test Router Contract Upgrade and Rollback
// [INFO] Initial version: gno.land/r/gnoswap/router/v1
// [INFO] Upgrading to test version
// [EXPECTED] Upgraded to: gno.land/r/gnoswap/router/test
// [INFO] Rolling back to v1
// [EXPECTED] Rolled back to: gno.land/r/gnoswap/router/v1
//
// [SCENARIO] 6. Test Staker Contract Upgrade and Rollback
// [INFO] Initial version: gno.land/r/gnoswap/staker/v1
// [INFO] Upgrading to test version
// [EXPECTED] Upgraded to: gno.land/r/gnoswap/staker/test
// [INFO] Rolling back to v1
// [EXPECTED] Rolled back to: gno.land/r/gnoswap/staker/v1
//
// [SCENARIO] 7. Test Gov/Governance Contract Upgrade and Rollback
// [INFO] Initial version: gno.land/r/gnoswap/gov/governance/v1
// [INFO] Upgrading to test version
// [EXPECTED] Upgraded to: gno.land/r/gnoswap/gov/governance/test
// [INFO] Rolling back to v1
// [EXPECTED] Rolled back to: gno.land/r/gnoswap/gov/governance/v1
//
// [SCENARIO] 8. Test Gov/Staker Contract Upgrade and Rollback
// [INFO] Initial version: gno.land/r/gnoswap/gov/staker/v1
// [INFO] Upgrading to test version
// [EXPECTED] Upgraded to: gno.land/r/gnoswap/gov/staker/test
// [INFO] Rolling back to v1
// [EXPECTED] Rolled back to: gno.land/r/gnoswap/gov/staker/v1
