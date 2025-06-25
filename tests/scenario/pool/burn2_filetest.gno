package main

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"

	"gno.land/r/gnoswap/v1/pool"
)

var t *testing.T

// Constants for fee tiers
const (
	FeeTier100   uint32 = 100
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
)

// Variables for test addresses and realms
var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)
	posRealm     = std.NewCodeRealm(consts.POSITION_PATH)
	positionAddr = consts.POSITION_ADDR
	poolAddr     = consts.POOL_ADDR
)

func main() {
	testInvalidTickRangeBurn()
}

// testInvalidTickRangeBurn tests burning with invalid tick range (should abort)
func testInvalidTickRangeBurn() {
	// Given: Pool exists with minted position
	barTokenPath := "gno.land/r/onbloc/bar"
	bazTokenPath := "gno.land/r/onbloc/baz"
	fee := FeeTier100
	liquidityAmount := "1000000"
	tickLower := int32(-100)
	tickUpper := int32(100)

	println("[INFO] Creating pool with fee tier:", fee)
	println("[INFO] Initial liquidity amount:", liquidityAmount)
	println("[INFO] Valid tick range:", tickLower, "to", tickUpper)

	// Create pool
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFeeByAdmin(cross, 0)
	pool.CreatePool(
		cross,
		barTokenPath,
		bazTokenPath,
		fee,
		"79228162514264337593543950336",
	)

	// Approve tokens for minting
	bar.Approve(cross, poolAddr, maxApprove)
	baz.Approve(cross, poolAddr, maxApprove)

	// Mint position
	testing.SetRealm(posRealm)
	pool.Mint(
		cross,
		barTokenPath,
		bazTokenPath,
		fee,
		positionAddr,
		tickLower,
		tickUpper,
		liquidityAmount,
		adminAddr,
	)

	println("[INFO] Position minted successfully")

	// When: Burn with invalid tick range (tickLower > tickUpper)
	invalidTickLower := int32(200)
	invalidTickUpper := int32(100)
	burnAmount := "1000000"

	println("[INFO] Attempting to burn with invalid tick range:", invalidTickLower, "to", invalidTickUpper)
	println("[INFO] Burn amount:", burnAmount)

	// Then: Should abort with specific error message
	expectedAbortMsg := "[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(200), tickUpper(100)"
	println("[EXPECTED] Should abort with message:", expectedAbortMsg)

	testing.SetRealm(posRealm)
	uassert.AbortsWithMessage(t, expectedAbortMsg, func() {
		pool.Burn(
			cross,
			barTokenPath,
			bazTokenPath,
			fee,
			invalidTickLower,
			invalidTickUpper,
			burnAmount,
			adminAddr,
		)
	})

	println("[SCENARIO] 3. Invalid Tick Range Burn - PASSED")
}

// Output:
// [INFO] Creating pool with fee tier: 100
// [INFO] Initial liquidity amount: 1000000
// [INFO] Valid tick range: -100 to 100
// [INFO] Position minted successfully
// [INFO] Attempting to burn with invalid tick range: 200 to 100
// [INFO] Burn amount: 1000000
// [EXPECTED] Should abort with message: [GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(200), tickUpper(100)
// [SCENARIO] 3. Invalid Tick Range Burn - PASSED
