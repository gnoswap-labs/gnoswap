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
	testSuccessfulBurn(t)
}

// testSuccessfulBurn tests successful burning of all liquidity from a position
func testSuccessfulBurn(t *testing.T) {
	pool.InitPoolTest(t)

	// Given: Pool exists with minted position
	barTokenPath := "gno.land/r/onbloc/bar"
	bazTokenPath := "gno.land/r/onbloc/baz"
	fee := FeeTier100
	liquidityAmount := "10000000000"
	tickLower := int32(-100)
	tickUpper := int32(100)

	println("[INFO] Creating pool with fee tier:", fee)
	println("[INFO] Token0:", barTokenPath)
	println("[INFO] Token1:", bazTokenPath)
	println("[INFO] Initial liquidity amount:", liquidityAmount)
	println("[INFO] Tick range:", tickLower, "to", tickUpper)

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
	mintAmount0, mintAmount1 := pool.Mint(
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
	println("[INFO] Minted amount0:", mintAmount0)
	println("[INFO] Minted amount1:", mintAmount1)

	// When: Burn all liquidity
	burnAmount := "10000000000"
	println("[INFO] Burning liquidity amount:", burnAmount)

	amount0, amount1 := pool.Burn(
		cross,
		barTokenPath,
		bazTokenPath,
		fee,
		tickLower,
		tickUpper,
		burnAmount,
		adminAddr,
	)

	// Then: Verify burn results
	println("[EXPECTED] Burned amount0 should be:", "49872720")
	println("[EXPECTED] Burned amount1 should be:", "49872720")
	println("[INFO] Actual burned amount0:", amount0)
	println("[INFO] Actual burned amount1:", amount1)

	uassert.Equal(t, "49872720", amount0)
	uassert.Equal(t, "49872720", amount1)

	println("[SCENARIO] 1. Successful Burn - PASSED")
}

// Output:
// [INFO] Creating pool with fee tier: 100
// [INFO] Token0: gno.land/r/onbloc/bar
// [INFO] Token1: gno.land/r/onbloc/baz
// [INFO] Initial liquidity amount: 10000000000
// [INFO] Tick range: -100 to 100
// [INFO] Position minted successfully
// [INFO] Minted amount0: 49872721
// [INFO] Minted amount1: 49872721
// [INFO] Burning liquidity amount: 10000000000
// [EXPECTED] Burned amount0 should be: 49872720
// [EXPECTED] Burned amount1 should be: 49872720
// [INFO] Actual burned amount0: 49872720
// [INFO] Actual burned amount1: 49872720
// [SCENARIO] 1. Successful Burn - PASSED
