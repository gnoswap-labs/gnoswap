// Scenario: Emergency Mode keeps position recovery paths available

package main

import (
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/pool"
	_ "gno.land/r/gnoswap/pool/v1"
	"gno.land/r/gnoswap/position"
	_ "gno.land/r/gnoswap/position/v1"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var t *testing.T

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	aliceAddr     = testutils.TestAddress("alice")
	aliceRealm    = testing.NewUserRealm(aliceAddr)
	barPath       = "gno.land/r/onbloc/bar"
	fooPath       = "gno.land/r/onbloc/foo"
	fee           = uint32(3000)
	deadline      = int64(4102444800)
)

func main() {
	println("[SCENARIO] 1. Initialize pool and mint position")
	setupPoolAndPosition()
	println()

	println("[SCENARIO] 2. Set emergency mode")
	setEmergencyMode()
	println()

	println("[SCENARIO] 3. DecreaseLiquidity remains allowed")
	testDecreaseLiquidity()
	println()

	println("[SCENARIO] 4. CollectFee remains allowed")
	testCollectFee()
	println()
}

func setupPoolAndPosition() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)
	bar.Transfer(cross, aliceAddr, 100000000)
	foo.Transfer(cross, aliceAddr, 100000000)
	pool.CreatePool(cross, barPath, fooPath, fee, common.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, 9223372036854775807)
	foo.Approve(cross, poolAddr, 9223372036854775807)
	position.Mint(cross, barPath, fooPath, fee, -960, 960, "50000000", "50000000", "0", "0", deadline, aliceAddr, aliceAddr, "")
	ufmt.Println("[INFO] position minted")
}

func setEmergencyMode() {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelEmergency)
	ufmt.Printf("[INFO] Position halted: %t\n", halt.IsHaltedPosition())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func testDecreaseLiquidity() {
	testing.SetRealm(aliceRealm)
	_, liquidity, _, _, amount0, amount1, _ := position.DecreaseLiquidity(cross, 1, "1000000", "0", "0", deadline)
	ufmt.Printf("[EXPECTED] removed liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] removed amount0: %s\n", amount0)
	ufmt.Printf("[EXPECTED] removed amount1: %s\n", amount1)
}

func testCollectFee() {
	testing.SetRealm(aliceRealm)
	_, _, _, amount0, amount1, _ := position.CollectFee(cross, 1)
	ufmt.Printf("[EXPECTED] collected fee amount0: %s\n", amount0)
	ufmt.Printf("[EXPECTED] collected fee amount1: %s\n", amount1)
}

// Output:
// [SCENARIO] 1. Initialize pool and mint position
// [INFO] position minted
//
// [SCENARIO] 2. Set emergency mode
// [INFO] Position halted: true
// [INFO] Withdraw halted: false
//
// [SCENARIO] 3. DecreaseLiquidity remains allowed
// [EXPECTED] removed liquidity: 1000000
// [EXPECTED] removed amount0: 46863
// [EXPECTED] removed amount1: 46863
//
// [SCENARIO] 4. CollectFee remains allowed
// [EXPECTED] collected fee amount0: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000
// [EXPECTED] collected fee amount1: 0
