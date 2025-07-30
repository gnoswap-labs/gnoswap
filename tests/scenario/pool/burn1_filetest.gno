package main

import (
	"std"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"

	"gno.land/r/gnoswap/v1/pool"
)

var t *testing.T

// Constants for fee tiers
const (
	FeeTier100 uint32 = 100
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
)

// Variables for test addresses and realms
var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = std.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = std.NewUserRealm(positionAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
)

func main() {
	testZeroLiquidityBurn()
}

// testZeroLiquidityBurn tests burning zero liquidity (should return zero amounts)
func testZeroLiquidityBurn() {
	// Given: Pool exists with minted position
	barTokenPath := "gno.land/r/onbloc/bar"
	bazTokenPath := "gno.land/r/onbloc/baz"
	fee := FeeTier100
	liquidityAmount := "10000000000"
	tickLower := int32(-100)
	tickUpper := int32(100)

	println("[INFO] Creating pool with fee tier:", fee)
	println("[INFO] Initial liquidity amount:", liquidityAmount)
	println("[INFO] Tick range:", tickLower, "to", tickUpper)

	// Create pool
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)
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

	// When: Burn zero liquidity
	burnAmount := "0"
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

	// Then: Verify zero amounts returned
	println("[EXPECTED] Burned amount0 should be: 0")
	println("[EXPECTED] Burned amount1 should be: 0")
	println("[INFO] Actual burned amount0:", amount0)
	println("[INFO] Actual burned amount1:", amount1)

	println("[SCENARIO] 2. Zero Liquidity Burn - PASSED")
}

// Output:
// [INFO] Creating pool with fee tier: 100
// [INFO] Initial liquidity amount: 10000000000
// [INFO] Tick range: -100 to 100
// [INFO] Position minted successfully
// [INFO] Burning liquidity amount: 0
// [EXPECTED] Burned amount0 should be: 0
// [EXPECTED] Burned amount1 should be: 0
// [INFO] Actual burned amount0: 0
// [INFO] Actual burned amount1: 0
// [SCENARIO] 2. Zero Liquidity Burn - PASSED
