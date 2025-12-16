// Scenario: Emission halt does not block other contract operations
//
// This test verifies that when emission is halted, other contracts like position
// can still operate normally. This is achieved by using MintAndDistributeGns
// which returns gracefully instead of panicking when emission is halted.
//
// Problem (before fix):
//   - emission.MintAndDistributeGns() panics when emission is halted
//   - Position.Mint() calls emission.MintAndDistributeGns() internally
//   - Therefore, halting emission would also block position minting
//
// Solution (after fix):
//   - Position.Mint() now calls emission.MintAndDistributeGns()
//   - MintAndDistributeGns() returns (0, false) instead of panicking
//   - Position minting succeeds even when emission is halted

package main

import (
	"chain"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	_ "gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const INT64_MAX int64 = 9223372036854775807

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee     = uint32(3000)
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool and tokens")
	initPoolAndTokens()
	println()

	ufmt.Println("[SCENARIO] 2. Mint position with emission enabled (normal case)")
	mintPositionWithEmissionEnabled()
	println()

	ufmt.Println("[SCENARIO] 3. Set halt level to Emergency (emission becomes halted)")
	setEmissionHalt()
	println()

	ufmt.Println("[SCENARIO] 4. Mint position with emission halted (graceful degradation)")
	mintPositionWithEmissionHalted()
	println()

	ufmt.Println("[SCENARIO] 5. Resume emission and verify it works again")
	resumeEmissionAndVerify()
	println()
}

func initPoolAndTokens() {
	testing.SetRealm(adminRealm)

	// Initialize emission
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	testing.SkipHeights(1)

	// Distribute tokens to alice
	defaultTokenAmount := int64(100000000)
	bar.Transfer(cross, aliceAddr, defaultTokenAmount)
	foo.Transfer(cross, aliceAddr, defaultTokenAmount)

	ufmt.Printf("[INFO] Alice BAR balance: %d\n", bar.BalanceOf(aliceAddr))
	ufmt.Printf("[INFO] Alice FOO balance: %d\n", foo.BalanceOf(aliceAddr))

	// Create pool
	pool.SetPoolCreationFee(cross, 0)
	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
	ufmt.Println("[INFO] Pool created: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000")
}

func mintPositionWithEmissionEnabled() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Emission is ENABLED - minting position...")

	testing.SetOriginSend(chain.Coins{})
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee,
		-960,
		960,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position minted successfully with ID: %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0: %s, Amount1: %s\n", amount0, amount1)
}

func setEmissionHalt() {
	testing.SetRealm(adminRealm)

	// Instead of using Emergency level (which halts many things),
	// we selectively halt only emission to demonstrate graceful degradation
	halt.SetOperationStatus(cross, halt.OpTypeEmission, true)

	isEmissionHalted := halt.IsHaltedEmission()
	isPositionHalted := halt.IsHaltedPosition()
	isPoolHalted := halt.IsHaltedPool()

	ufmt.Printf("[INFO] Emission selectively halted\n")
	ufmt.Printf("[EXPECTED] Emission halted: %t (should be true)\n", isEmissionHalted)
	ufmt.Printf("[EXPECTED] Position halted: %t (should be false)\n", isPositionHalted)
	ufmt.Printf("[EXPECTED] Pool halted: %t (should be false)\n", isPoolHalted)
}

func mintPositionWithEmissionHalted() {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Emission is HALTED - attempting to mint position...")
	ufmt.Println("[INFO] With MintAndDistributeGns, this should succeed without panic")

	testing.SetOriginSend(chain.Coins{})
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee,
		-1920,
		1920,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position minted successfully despite emission halt! ID: %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0: %s, Amount1: %s\n", amount0, amount1)
	ufmt.Println("[SUCCESS] Graceful degradation working - emission halt did not block position")
}

func resumeEmissionAndVerify() {
	testing.SetRealm(adminRealm)

	// Resume all operations
	halt.SetHaltLevel(cross, halt.HaltLevelNone)

	isEmissionHalted := halt.IsHaltedEmission()
	ufmt.Printf("[INFO] Halt level reset to NONE\n")
	ufmt.Printf("[EXPECTED] Emission halted: %t (should be false)\n", isEmissionHalted)

	// Skip some blocks and verify emission works
	testing.SkipHeights(10)

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/emission"))
	distributed, ok := emission.MintAndDistributeGns(cross)
	ufmt.Printf("[INFO] Distributed amount: %d\n", distributed)
	ufmt.Printf("[INFO] Success: %t\n", ok)

	ufmt.Printf("[EXPECTED] Emission resumed, distributed amount: %d (should be > 0)\n", distributed)
}

// Output:
// [SCENARIO] 1. Initialize pool and tokens
// [INFO] Alice BAR balance: 100000000
// [INFO] Alice FOO balance: 100000000
// [INFO] Pool created: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000
//
// [SCENARIO] 2. Mint position with emission enabled (normal case)
// [INFO] Emission is ENABLED - minting position...
// [EXPECTED] Position minted successfully with ID: 1
// [EXPECTED] Liquidity: 213383746
// [EXPECTED] Amount0: 10000000, Amount1: 10000000
//
// [SCENARIO] 3. Set halt level to Emergency (emission becomes halted)
// [INFO] Emission selectively halted
// [EXPECTED] Emission halted: true (should be true)
// [EXPECTED] Position halted: false (should be false)
// [EXPECTED] Pool halted: false (should be false)
//
// [SCENARIO] 4. Mint position with emission halted (graceful degradation)
// [INFO] Emission is HALTED - attempting to mint position...
// [INFO] With MintAndDistributeGns, this should succeed without panic
// [EXPECTED] Position minted successfully despite emission halt! ID: 2
// [EXPECTED] Liquidity: 109251858
// [EXPECTED] Amount0: 10000000, Amount1: 10000000
// [SUCCESS] Graceful degradation working - emission halt did not block position
//
// [SCENARIO] 5. Resume emission and verify it works again
// [INFO] Halt level reset to NONE
// [EXPECTED] Emission halted: false (should be false)
// [INFO] Distributed amount: 356735150
// [INFO] Success: true
// [EXPECTED] Emission resumed, distributed amount: 356735150 (should be > 0)
