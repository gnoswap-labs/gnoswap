package main

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/pool"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var t *testing.T

// Constants for addresses and approvals
const (
	FeeTier100 uint32 = 100
	maxApprove int64  = 9223372036854775806
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
	testPartialLiquidityBurn()
}

// testPartialLiquidityBurn tests burning partial liquidity from a position
func testPartialLiquidityBurn() {
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

	// When: Burn partial liquidity (50% of total)
	burnAmount := "5000000000" // 50% of total liquidity
	println("[INFO] Burning partial liquidity amount:", burnAmount, "(50% of total)")

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

	// Then: Verify partial burn results (approximately 50% of full burn amounts)
	println("[EXPECTED] Burned amount0 should be approximately half of full burn")
	println("[EXPECTED] Burned amount1 should be approximately half of full burn")
	println("[INFO] Actual burned amount0:", amount0)
	println("[INFO] Actual burned amount1:", amount1)

	// Calculate expected amounts (approximately half of full burn)
	expectedAmount0 := "24936360" // Approximately half of 49872720
	expectedAmount1 := "24936360" // Approximately half of 49872720

	uassert.Equal(t, expectedAmount0, amount0)
	uassert.Equal(t, expectedAmount1, amount1)

	println("[SCENARIO] 5. Partial Liquidity Burn - PASSED")
}

// Output:
// [INFO] Creating pool with fee tier: 100
// [INFO] Initial liquidity amount: 10000000000
// [INFO] Tick range: -100 to 100
// [INFO] Position minted successfully
// [INFO] Minted amount0: 49872721
// [INFO] Minted amount1: 49872721
// [INFO] Burning partial liquidity amount: 5000000000 (50% of total)
// [EXPECTED] Burned amount0 should be approximately half of full burn
// [EXPECTED] Burned amount1 should be approximately half of full burn
// [INFO] Actual burned amount0: 24936360
// [INFO] Actual burned amount1: 24936360
// [SCENARIO] 5. Partial Liquidity Burn - PASSED
