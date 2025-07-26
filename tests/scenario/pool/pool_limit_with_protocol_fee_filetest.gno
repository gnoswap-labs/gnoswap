package main

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"

	"gno.land/r/gnoswap/v1/gns"
)

var t *testing.T

// Constants for fee tiers
const (
	fee100 uint32 = 100
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806

	MAX_UINT128 string = "340282366920938463463374607431768211455"
)

// Variables for test addresses and realms
var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = std.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = std.NewUserRealm(positionAddr)
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())
	rouRealm        = std.NewUserRealm(routerAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
)

// Token paths
var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
)

// Test variables
var (
	tickLower       = int32(9000)
	tickUpper       = int32(12000)
	poolCreationFee = int64(100_000_000)

	test_liquidityExpectStr = "10000000000"

	MAX_PRICE string = "1461446703485210103287273052203988822378723970341"
)

// turn protocol fee on
func init() {
	testing.SetRealm(adminRealm)
	pool.SetFeeProtocolByAdmin(cross, 4, 4)
}

func main() {
	println("[SCENARIO] Limit Order Thru Positive 1 With Fee")
	println("[INFO] Starting scenario: Limit order thru positive 1 with fee")

	println("[INFO] Setting up pool with specific tick")

	println("[INFO] Approving pool creation fee")
	println()
	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, fee100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	thisPool := pool.GetPool(barPath, fooPath, fee100)

	println("[SCENARIO] 1. Minting position spanning current tick")
	testing.SetRealm(posRealm)
	mint0, mint1 := pool.Mint(
		cross,
		barPath,
		fooPath,
		fee100,
		positionAddr,
		0,
		120,
		test_liquidityExpectStr,
		adminAddr,
	)

	println("[INFO] Minted position:", mint0, mint1)

	// SWAP 1 -> 0
	testing.SetRealm(rouRealm)
	swap0, swap1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee100,
		adminAddr,
		false,
		"60183363",
		MAX_PRICE,
		adminAddr,
	)

	println("[INFO] Swapped:", swap0, swap1)

	// BURN
	testing.SetRealm(posRealm)
	burn0, burn1 := pool.Burn(
		cross,
		barPath,
		fooPath,
		fee100,
		0,
		120,
		test_liquidityExpectStr,
		adminAddr,
	)

	println("[INFO] Burned:", burn0, burn1)

	// COLLECT
	testing.SetRealm(posRealm)
	collect0, collect1 := pool.Collect(
		cross,
		barPath,
		fooPath,
		fee100,
		adminAddr,
		0,
		120,
		MAX_UINT128,
		MAX_UINT128,
	)

	println("[INFO] Collected:", collect0, collect1)

	slotTick := thisPool.Slot0Tick()
	println("[EXPECTED] Pool tick:", slotTick, "expected: >= 120")
	uassert.True(t, slotTick >= 120, ufmt.Sprintf("tick(%d) should be >= 120", slotTick)) //temporary fix (cc @jinoosss)
	println()
	println("[INFO] Scenario completed")
}

// Output:
// [SCENARIO] Limit Order Thru Positive 1 With Fee
// [INFO] Starting scenario: Limit order thru positive 1 with fee
// [INFO] Setting up pool with specific tick
// [INFO] Approving pool creation fee
//
// [SCENARIO] 1. Minting position spanning current tick
// [INFO] Minted position: 59817378 0
// [INFO] Swapped: -59817377 60183363
// [INFO] Burned: 0 60177342
// [INFO] Collected: 0 60177342
// [EXPECTED] Pool tick: 120 expected: >= 120
//
// [INFO] Scenario completed
