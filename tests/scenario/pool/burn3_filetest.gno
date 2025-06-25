package main

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/pool"
)

var t *testing.T

// Constants for fee tiers
const (
	FeeTier100 uint32 = 100
	FeeTier500 uint32 = 500
)

// Variables for test addresses and realms
var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	posRealm     = std.NewCodeRealm(consts.POSITION_PATH)
)

func main() {
	testNonExistentPoolBurn()
}

// testNonExistentPoolBurn tests burning from non-existent pool (should abort)
func testNonExistentPoolBurn() {
	// Given: No pool exists
	barTokenPath := "gno.land/r/onbloc/bar"
	bazTokenPath := "gno.land/r/onbloc/baz"
	fee := FeeTier500
	tickLower := int32(-100)
	tickUpper := int32(100)
	burnAmount := "1000000"

	println("[INFO] Attempting to burn from non-existent pool")
	println("[INFO] Token0:", barTokenPath)
	println("[INFO] Token1:", bazTokenPath)
	println("[INFO] Fee tier:", fee)
	println("[INFO] Tick range:", tickLower, "to", tickUpper)
	println("[INFO] Burn amount:", burnAmount)

	// When: Try to burn from non-existent pool
	testing.SetRealm(posRealm)

	// Then: Should abort with specific error message
	expectedAbortMsg := "[GNOSWAP-POOL-008] requested data not found || expected poolPath(gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500) to exist"
	println("[EXPECTED] Should abort with message:", expectedAbortMsg)

	uassert.AbortsWithMessage(t, expectedAbortMsg, func() {
		pool.Burn(
			cross,
			barTokenPath,
			bazTokenPath,
			fee,
			tickLower,
			tickUpper,
			burnAmount,
			adminAddr,
		)
	})

	println("[SCENARIO] 4. Non-existent Pool Burn - PASSED")
}

// Output:
// [INFO] Attempting to burn from non-existent pool
// [INFO] Token0: gno.land/r/onbloc/bar
// [INFO] Token1: gno.land/r/onbloc/baz
// [INFO] Fee tier: 500
// [INFO] Tick range: -100 to 100
// [INFO] Burn amount: 1000000
// [EXPECTED] Should abort with message: [GNOSWAP-POOL-008] requested data not found || expected poolPath(gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500) to exist
// [SCENARIO] 4. Non-existent Pool Burn - PASSED
