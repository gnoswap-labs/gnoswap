// ProtocolFee contract rollback scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	protocolFee "gno.land/r/gnoswap/protocol_fee"

	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v2_invalid"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	protocolFeeV1Path   = "gno.land/r/gnoswap/protocol_fee/v1"
	protocolFeeTestPath = "gno.land/r/gnoswap/protocol_fee/v2_invalid"
)

func main() {
	println("[SCENARIO] ProtocolFee Contract Rollback Test")
	testProtocolFeeRollback()
	println()
}

func testProtocolFeeRollback() {
	// First, upgrade to test version
	ufmt.Println("[INFO] Preparing: Upgrading to test version")
	testing.SetRealm(adminRealm)
	protocolFee.UpgradeImpl(cross, protocolFeeTestPath)

	currentVersion := protocolFee.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != protocolFeeTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Rollback to v1
	ufmt.Println("[INFO] Rolling back protocol_fee contract to v1")
	testing.SetRealm(adminRealm)
	protocolFee.UpgradeImpl(cross, protocolFeeV1Path)

	currentVersion = protocolFee.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] ProtocolFee rolled back to: %s\n", currentVersion)
	if currentVersion != protocolFeeV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

// Output:
// [SCENARIO] ProtocolFee Contract Rollback Test
// [INFO] Preparing: Upgrading to test version
// [INFO] Current version: gno.land/r/gnoswap/protocol_fee/v2_invalid
// [INFO] Rolling back protocol_fee contract to v1
// [EXPECTED] ProtocolFee rolled back to: gno.land/r/gnoswap/protocol_fee/v1
