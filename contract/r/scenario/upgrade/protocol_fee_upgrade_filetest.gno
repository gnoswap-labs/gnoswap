// ProtocolFee contract upgrade scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	protocolFee "gno.land/r/gnoswap/protocol_fee"

	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v2_invalid"
)

var t = &testing.T{}

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	protocolFeeV1Path   = "gno.land/r/gnoswap/protocol_fee/v1"
	protocolFeeTestPath = "gno.land/r/gnoswap/protocol_fee/v2_invalid"
)

func main() {
	println("[SCENARIO] 1. Initialize protocol_fee contract with v1")
	initializeV1()
	println()

	println("[SCENARIO] 2. Upgrade protocol_fee contract to test version")
	testProtocolFeeUpgrade()
	println()

	println("[SCENARIO] 3. Verify test implementation panics correctly")
	verifyTestImplementation()
	println()
}

func initializeV1() {
	currentVersion := protocolFee.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current implementation: %s\n", currentVersion)

	if currentVersion != protocolFeeV1Path {
		ufmt.Println("[INFO] Setting implementation to v1")
		testing.SetRealm(adminRealm)
		protocolFee.UpgradeImpl(cross, protocolFeeV1Path)
		currentVersion = protocolFee.GetImplementationPackagePath()
	}

	ufmt.Printf("[EXPECTED] ProtocolFee initialized with v1: %s\n", currentVersion)
	if currentVersion != protocolFeeV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testProtocolFeeUpgrade() {
	// Verify current version is v1
	currentVersion := protocolFee.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != protocolFeeV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading protocol_fee contract to test version")
	testing.SetRealm(adminRealm)
	protocolFee.UpgradeImpl(cross, protocolFeeTestPath)

	currentVersion = protocolFee.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] ProtocolFee upgraded to: %s\n", currentVersion)
	if currentVersion != protocolFeeTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}
}

func verifyTestImplementation() {
	// Verify current version is test version
	currentVersion := protocolFee.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != protocolFeeTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Test DistributeProtocolFee - should panic with test implementation message
	ufmt.Println("[INFO] Testing DistributeProtocolFee function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: DistributeProtocolFee not supported", func() {
		protocolFee.DistributeProtocolFee(cross)
	})
	ufmt.Println("[EXPECTED] DistributeProtocolFee panics correctly")

	// Test SetDevOpsPct - should panic with test implementation message
	ufmt.Println("[INFO] Testing SetDevOpsPct function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: SetDevOpsPct not supported", func() {
		protocolFee.SetDevOpsPct(cross, 50)
	})
	ufmt.Println("[EXPECTED] SetDevOpsPct panics correctly")

	// Test AddToProtocolFee - should panic with test implementation message
	ufmt.Println("[INFO] Testing AddToProtocolFee function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: AddToProtocolFee not supported", func() {
		protocolFee.AddToProtocolFee(cross, "gno.land/r/onbloc/foo", 100)
	})
	ufmt.Println("[EXPECTED] AddToProtocolFee panics correctly")

	// Test SetGovStakerPct - should panic with test implementation message
	ufmt.Println("[INFO] Testing SetGovStakerPct function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: SetGovStakerPct not supported", func() {
		protocolFee.SetGovStakerPct(cross, 50)
	})
	ufmt.Println("[EXPECTED] SetGovStakerPct panics correctly")

	// Test ClearTokenListWithAmount - should panic with test implementation message
	ufmt.Println("[INFO] Testing ClearTokenListWithAmount function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: ClearTokenListWithAmount not supported", func() {
		protocolFee.ClearTokenListWithAmount(cross)
	})
	ufmt.Println("[EXPECTED] ClearTokenListWithAmount panics correctly")

	// Test ClearAccuTransferToGovStaker - should panic with test implementation message
	ufmt.Println("[INFO] Testing ClearAccuTransferToGovStaker function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: ClearAccuTransferToGovStaker not supported", func() {
		protocolFee.ClearAccuTransferToGovStaker(cross)
	})
	ufmt.Println("[EXPECTED] ClearAccuTransferToGovStaker panics correctly")
}

// Output:
// [SCENARIO] 1. Initialize protocol_fee contract with v1
// [INFO] Current implementation: gno.land/r/gnoswap/protocol_fee/v1
// [EXPECTED] ProtocolFee initialized with v1: gno.land/r/gnoswap/protocol_fee/v1
//
// [SCENARIO] 2. Upgrade protocol_fee contract to test version
// [INFO] Current version: gno.land/r/gnoswap/protocol_fee/v1
// [INFO] Upgrading protocol_fee contract to test version
// [EXPECTED] ProtocolFee upgraded to: gno.land/r/gnoswap/protocol_fee/v2_invalid
//
// [SCENARIO] 3. Verify test implementation panics correctly
// [INFO] Current version: gno.land/r/gnoswap/protocol_fee/v2_invalid
// [INFO] Testing DistributeProtocolFee function panics correctly
// [EXPECTED] DistributeProtocolFee panics correctly
// [INFO] Testing SetDevOpsPct function panics correctly
// [EXPECTED] SetDevOpsPct panics correctly
// [INFO] Testing AddToProtocolFee function panics correctly
// [EXPECTED] AddToProtocolFee panics correctly
// [INFO] Testing SetGovStakerPct function panics correctly
// [EXPECTED] SetGovStakerPct panics correctly
// [INFO] Testing ClearTokenListWithAmount function panics correctly
// [EXPECTED] ClearTokenListWithAmount panics correctly
// [INFO] Testing ClearAccuTransferToGovStaker function panics correctly
// [EXPECTED] ClearAccuTransferToGovStaker panics correctly
