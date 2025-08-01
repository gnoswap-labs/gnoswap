package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
)

const (
	milliSecondsOfYear = 31536000000 // 365 * 24 * 60 * 60 * 1000
	defaultBlockTime   = 2000        // 2 seconds = 2000 milliseconds
)

var (
	emissionAddr = std.DerivePkgAddr("gno.land/r/gnoswap/v1/emission")
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	userAddr     = testutils.TestAddress("user")
)

func main() {
	println("[SCENARIO] Test Distribution Start Block Height with Halving Year Adjustment")

	testing.SetRealm(std.NewUserRealm(adminAddr))

	// Run each scenario
	testScenario1InitialConfiguration()
	testScenario2SetDistributionStartHeight()
	testScenario3VerifyHalvingYearBoundaries()
	testScenario4EmissionAfterStartHeight()
	testScenario5ReinitializeProtection()
	testScenario6VerifyTotalEmissionPeriod()
}

func testScenario1InitialConfiguration() {
	println("[SCENARIO] 1. Initial Halving Year Configuration")

	// Get initial emission state
	initialStartHeight := gns.EmissionStartHeight()
	initialEndHeight := gns.GetHalvingYearEndBlock(12) // Last halving year
	ufmt.Printf("[INFO] Initial emission start height: %d\n", initialStartHeight)
	ufmt.Printf("[INFO] Initial emission end height (year 12): %d\n", initialEndHeight)
	ufmt.Printf("[INFO] Total blocks for emission: %d\n", initialEndHeight-initialStartHeight+1)
	ufmt.Println()
}

func testScenario2SetDistributionStartHeight() {
	println("[SCENARIO] 2. Set Distribution Start Height and Check Halving Year Adjustment")

	futureHeight := int64(10000)
	testing.SetOriginCaller(adminAddr)
	emission.SetDistributionStartBlockHeight(cross, futureHeight)

	// Check if halving years were adjusted
	newStartHeight := gns.EmissionStartHeight()
	newEndHeight := gns.GetHalvingYearEndBlock(12)

	ufmt.Printf("[INFO] New emission start height: %d\n", newStartHeight)
	ufmt.Printf("[INFO] New emission end height (year 12): %d\n", newEndHeight)
	ufmt.Printf("[INFO] Total blocks for emission: %d\n", newEndHeight-newStartHeight+1)
	ufmt.Printf("[EXPECTED] Start height should be %d\n", futureHeight)
	ufmt.Printf("[EXPECTED] Total blocks should remain the same\n")
	ufmt.Println()
}

func testScenario3VerifyHalvingYearBoundaries() {
	println("[SCENARIO] 3. Verify Halving Year Boundaries")

	for year := int64(1); year <= 3; year++ {
		startBlock := gns.GetHalvingYearStartBlock(year)
		endBlock := gns.GetHalvingYearEndBlock(year)
		blocksInYear := endBlock - startBlock + 1

		ufmt.Printf("[INFO] Year %d: Start block %d, End block %d, Total blocks: %d\n",
			year, startBlock, endBlock, blocksInYear)
	}
	ufmt.Println()
}

func testScenario4EmissionAfterStartHeight() {
	println("[SCENARIO] 4. Test Emission After Reaching Start Height")

	// Skip blocks to reach start height
	testing.SkipHeights(10000)
	currentHeight := std.ChainHeight()
	ufmt.Printf("[INFO] Current chain height after skipping: %d\n", currentHeight)

	// Try to mint
	testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/emission"))
	distributedAmount := emission.MintAndDistributeGns(cross)
	ufmt.Printf("[INFO] Distributed amount: %d\n", distributedAmount)
	ufmt.Printf("[EXPECTED] Should be > 0 (distribution started)\n")

	// Check which halving year we're in
	currentYear := gns.HalvingYearByHeight(currentHeight)
	ufmt.Printf("[INFO] Current halving year: %d\n", currentYear)
	ufmt.Printf("[EXPECTED] Should be 1 (first year)\n")
	ufmt.Println()
}

func testScenario5ReinitializeProtection() {
	println("[SCENARIO] 5. Test Reinitialize Protection After Minting")

	// Try to set a new distribution start height after minting has begun
	newFutureHeight := int64(20000)
	testing.SetOriginCaller(adminAddr)
	emission.SetDistributionStartBlockHeight(cross, newFutureHeight)

	// Check if halving years remained unchanged (should not reinitialize)
	currentStartHeight := gns.EmissionStartHeight()
	currentEndHeight := gns.GetHalvingYearEndBlock(12)

	ufmt.Printf("[INFO] Start height after attempted change: %d\n", currentStartHeight)
	ufmt.Printf("[INFO] End height after attempted change: %d\n", currentEndHeight)
	ufmt.Printf("[EXPECTED] Should remain at %d (no reinitialize after minting)\n", currentStartHeight)
	ufmt.Println()
}

func testScenario6VerifyTotalEmissionPeriod() {
	println("[SCENARIO] 6. Verify Total Emission Period")

	newStartHeight := gns.EmissionStartHeight()
	newEndHeight := gns.GetHalvingYearEndBlock(12)

	blocksPerYear := int64(365 * 24 * 60 * 60 * 1000 / defaultBlockTime)
	expectedTotalBlocks := blocksPerYear * 12
	actualTotalBlocks := newEndHeight - newStartHeight + 1

	ufmt.Printf("[INFO] Expected total blocks (12 years): %d\n", expectedTotalBlocks)
	ufmt.Printf("[INFO] Actual total blocks: %d\n", actualTotalBlocks)
	ufmt.Printf("[INFO] Difference: %d blocks\n", actualTotalBlocks-expectedTotalBlocks)
	ufmt.Printf("[EXPECTED] Difference should be minimal (< 12 blocks for rounding)\n")
}

// Output:
// [SCENARIO] Test Distribution Start Block Height with Halving Year Adjustment
// [SCENARIO] 1. Initial Halving Year Configuration
// [INFO] Initial emission start height: 124
// [INFO] Initial emission end height (year 12): 189216123
// [INFO] Total blocks for emission: 189216000
//
// [SCENARIO] 2. Set Distribution Start Height and Check Halving Year Adjustment
// [INFO] New emission start height: 10000
// [INFO] New emission end height (year 12): 189225999
// [INFO] Total blocks for emission: 189216000
// [EXPECTED] Start height should be 10000
// [EXPECTED] Total blocks should remain the same
//
// [SCENARIO] 3. Verify Halving Year Boundaries
// [INFO] Year 1: Start block 10000, End block 15777999, Total blocks: 15768000
// [INFO] Year 2: Start block 15778000, End block 31545999, Total blocks: 15768000
// [INFO] Year 3: Start block 31546000, End block 47313999, Total blocks: 15768000
//
// [SCENARIO] 4. Test Emission After Reaching Start Height
// [INFO] Current chain height after skipping: 10123
// [INFO] Distributed amount: 1769406343
// [EXPECTED] Should be > 0 (distribution started)
// [INFO] Current halving year: 1
// [EXPECTED] Should be 1 (first year)
//
// [SCENARIO] 5. Test Reinitialize Protection After Minting
// [INFO] Start height after attempted change: 10000
// [INFO] End height after attempted change: 189225999
// [EXPECTED] Should remain at 10000 (no reinitialize after minting)
//
// [SCENARIO] 6. Verify Total Emission Period
// [INFO] Expected total blocks (12 years): 189216000
// [INFO] Actual total blocks: 189216000
// [INFO] Difference: 0 blocks
// [EXPECTED] Difference should be minimal (< 12 blocks for rounding)
