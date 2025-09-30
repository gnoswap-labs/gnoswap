package main

import (
	"chain"
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
)

const (
	milliSecondsOfYear = 31536000000 // 365 * 24 * 60 * 60 * 1000
	defaultBlockTime   = 2000        // 2 seconds = 2000 milliseconds
)

var (
	emissionAddr = chain.PackageAddress("gno.land/r/gnoswap/emission")
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	userAddr     = testutils.TestAddress("user")

	t *testing.T
)

func main() {
	println("[SCENARIO] Test Distribution Start Block Height with Halving Year Adjustment")

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	// Run each scenario
	testScenario1InitialConfiguration()
	testScenario2SetDistributionStartHeight()
	testScenario3VerifyHalvingYearBoundaries()
	testScenario4EmissionAfterStartHeight()
	testScenario5ReinitializeProtection()
	testScenario6VerifyTotalEmissionPeriod()

	println("[EXPECTED] All scenarios should pass")
}

func testScenario1InitialConfiguration() {
	println("[SCENARIO] 1. Initial Halving Year Configuration")

	// Get initial emission state
	initialStartHeight := gns.GetEmissionStartTimestamp()
	initialEndHeight := gns.GetEmissionEndTimestamp() // Last halving year
	ufmt.Printf("[INFO] Initial emission start height: %d\n", initialStartHeight)
	ufmt.Printf("[INFO] Initial emission end height (year 12): %d\n", initialEndHeight)
	ufmt.Printf("[INFO] Total blocks for emission: %d\n", initialEndHeight-initialStartHeight+1)
	ufmt.Println()
}

func testScenario2SetDistributionStartHeight() {
	println("[SCENARIO] 2. Set Distribution Start Height and Check Halving Year Adjustment")

	testing.SetOriginCaller(adminAddr)
	futureTimestamp := time.Now().Unix() + 10000/defaultBlockTime
	emission.SetDistributionStartTime(cross, futureTimestamp)

	// Check if halving years were adjusted
	newStartHeight := gns.GetEmissionStartTimestamp()
	newEndHeight := gns.GetEmissionEndTimestamp()

	ufmt.Printf("[INFO] New emission start height: %d\n", newStartHeight)
	ufmt.Printf("[INFO] New emission end height (year 12): %d\n", newEndHeight)
	ufmt.Printf("[INFO] Total blocks for emission: %d\n", newEndHeight-newStartHeight+1)
	ufmt.Printf("[EXPECTED] Start time should be %d\n", futureTimestamp)
	ufmt.Printf("[EXPECTED] Total blocks should remain the same\n")
	ufmt.Println()
}

func testScenario3VerifyHalvingYearBoundaries() {
	println("[SCENARIO] 3. Verify Halving Year Boundaries")

	for year := int64(1); year <= 3; year++ {
		startTime := gns.GetHalvingYearStartTimestamp(year)
		endTime := gns.GetHalvingYearEndTimestamp(year)
		blocksInYear := endTime - startTime + 1

		ufmt.Printf("[INFO] Year %d: Start time %d, End time %d, Total blocks: %d\n",
			year, startTime, endTime, blocksInYear)
	}
	ufmt.Println()
}

func testScenario4EmissionAfterStartHeight() {
	println("[SCENARIO] 4. Test Emission After Reaching Start Height")

	// Skip blocks to reach start height
	testing.SkipHeights(10000)
	currentHeight := runtime.ChainHeight()
	ufmt.Printf("[INFO] Current chain height after skipping: %d\n", currentHeight)

	// Try to mint
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/emission"))
	distributedAmount := emission.MintAndDistributeGns(cross)
	ufmt.Printf("[INFO] Distributed amount: %d\n", distributedAmount)
	ufmt.Printf("[EXPECTED] Should be > 0 (distribution started)\n")

	// Check which halving year we're in
	currentYear := gns.GetHalvingYear(time.Now().Unix())
	ufmt.Printf("[INFO] Current halving year: %d\n", currentYear)
	ufmt.Printf("[EXPECTED] Should be 1 (first year)\n")
	ufmt.Println()
}

func testScenario5ReinitializeProtection() {
	println("[SCENARIO] 5. Test Reinitialize Protection After Minting")

	// Try to set a new distribution start height after minting has begun
	expectedPanic := "distribution has already started, cannot change start timestamp"
	futureTimestamp := time.Now().Unix() + 20000/defaultBlockTime

	uassert.AbortsWithMessage(t, expectedPanic, func() {
		testing.SetOriginCaller(adminAddr)
		emission.SetDistributionStartTime(cross, futureTimestamp)
	})

	println("[EXPECTED] Should panic with 'distribution has already started, cannot change start block height'")
	println()
}

func testScenario6VerifyTotalEmissionPeriod() {
	println("[SCENARIO] 6. Verify Total Emission Period")

	newStartHeight := gns.GetEmissionStartTimestamp()
	newEndHeight := gns.GetEmissionEndTimestamp()

	blocksPerYear := int64(365 * 24 * 60 * 60 * 1000 / defaultBlockTime)
	expectedTotalBlocks := blocksPerYear * 12
	actualTotalBlocks := newEndHeight - newStartHeight + 1

	ufmt.Printf("[INFO] Expected total blocks (12 years): %d\n", expectedTotalBlocks)
	ufmt.Printf("[INFO] Actual total blocks: %d\n", actualTotalBlocks)
	ufmt.Printf("[INFO] Difference: %d blocks\n", actualTotalBlocks-expectedTotalBlocks)
	ufmt.Printf("[EXPECTED] Difference should be minimal (< 12 blocks for rounding)\n")
	println()
}

// Output:
// [SCENARIO] Test Distribution Start Block Height with Halving Year Adjustment
// [SCENARIO] 1. Initial Halving Year Configuration
// [INFO] Initial emission start height: 0
// [INFO] Initial emission end height (year 12): 378431999
// [INFO] Total blocks for emission: 378432000
//
// [SCENARIO] 2. Set Distribution Start Height and Check Halving Year Adjustment
// [INFO] New emission start height: 1234567895
// [INFO] New emission end height (year 12): 1612999894
// [INFO] Total blocks for emission: 378432000
// [EXPECTED] Start time should be 1234567895
// [EXPECTED] Total blocks should remain the same
//
// [SCENARIO] 3. Verify Halving Year Boundaries
// [INFO] Year 1: Start time 1234567895, End time 1266103894, Total blocks: 31536000
// [INFO] Year 2: Start time 1266103895, End time 1297639894, Total blocks: 31536000
// [INFO] Year 3: Start time 1297639895, End time 1329175894, Total blocks: 31536000
//
// [SCENARIO] 4. Test Emission After Reaching Start Height
// [INFO] Current chain height after skipping: 10123
// [INFO] Distributed amount: 356706611187
// [EXPECTED] Should be > 0 (distribution started)
// [INFO] Current halving year: 1
// [EXPECTED] Should be 1 (first year)
//
// [SCENARIO] 5. Test Reinitialize Protection After Minting
// [EXPECTED] Should panic with 'distribution has already started, cannot change start block height'
//
// [SCENARIO] 6. Verify Total Emission Period
// [INFO] Expected total blocks (12 years): 189216000
// [INFO] Actual total blocks: 378432000
// [INFO] Difference: 189216000 blocks
// [EXPECTED] Difference should be minimal (< 12 blocks for rounding)
//
// [EXPECTED] All scenarios should pass
