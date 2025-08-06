package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
)

var adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())

func main() {
	println("[SCENARIO] Test Override Distribution Start Height with Halving Year Recalculation")

	testing.SetRealm(std.NewUserRealm(adminAddr))
	testing.SetOriginCaller(adminAddr)

	// Scenario 1: Initial state before any distribution
	println("\n[SCENARIO 1] Initial State")
	initialEmissionStart := gns.EmissionStartHeight()
	initialYear1End := gns.GetHalvingYearEndBlock(1)
	initialYear12End := gns.GetHalvingYearEndBlock(12)

	ufmt.Printf("[INFO] Initial emission start height: %d\n", initialEmissionStart)
	ufmt.Printf("[INFO] Initial Year 1 end block: %d\n", initialYear1End)
	ufmt.Printf("[INFO] Initial Year 12 end block: %d\n", initialYear12End)

	// Scenario 2: Set distribution start height to 5000
	println("\n[SCENARIO 2] Set Distribution Start Height to 5000")
	emission.SetDistributionStartBlockHeight(cross, 5000)

	newEmissionStart1 := gns.EmissionStartHeight()
	newYear1End1 := gns.GetHalvingYearEndBlock(1)
	newYear12End1 := gns.GetHalvingYearEndBlock(12)

	ufmt.Printf("[INFO] New emission start height: %d\n", newEmissionStart1)
	ufmt.Printf("[INFO] New Year 1 end block: %d\n", newYear1End1)
	ufmt.Printf("[INFO] New Year 12 end block: %d\n", newYear12End1)
	ufmt.Printf("[EXPECTED] Emission start should be 5000\n")
	ufmt.Printf("[EXPECTED] All halving years should be shifted by ~4876 blocks\n")

	// Scenario 3: Override to 10000
	println("\n[SCENARIO 3] Override Distribution Start Height to 10000")
	emission.SetDistributionStartBlockHeight(cross, 10000)

	newEmissionStart2 := gns.EmissionStartHeight()
	newYear1End2 := gns.GetHalvingYearEndBlock(1)
	newYear12End2 := gns.GetHalvingYearEndBlock(12)

	ufmt.Printf("[INFO] New emission start height: %d\n", newEmissionStart2)
	ufmt.Printf("[INFO] New Year 1 end block: %d\n", newYear1End2)
	ufmt.Printf("[INFO] New Year 12 end block: %d\n", newYear12End2)
	ufmt.Printf("[EXPECTED] Emission start should be 10000\n")
	ufmt.Printf("[EXPECTED] All halving years should be recalculated from 10000\n")

	// Verify the shift is correct
	shift1 := newEmissionStart1 - initialEmissionStart
	shift2 := newEmissionStart2 - newEmissionStart1

	println("\n[VERIFICATION] Halving Year Shifts")
	ufmt.Printf("[INFO] Shift from initial to 5000: %d blocks\n", shift1)
	ufmt.Printf("[INFO] Shift from 5000 to 10000: %d blocks\n", shift2)
	ufmt.Printf("[INFO] Year 12 end shift (initial to 5000): %d blocks\n", newYear12End1-initialYear12End)
	ufmt.Printf("[INFO] Year 12 end shift (5000 to 10000): %d blocks\n", newYear12End2-newYear12End1)
	ufmt.Printf("[EXPECTED] All shifts should match the distribution start height changes\n")
}

// Output:
// [SCENARIO] Test Override Distribution Start Height with Halving Year Recalculation
//
// [SCENARIO 1] Initial State
// [INFO] Initial emission start height: 124
// [INFO] Initial Year 1 end block: 15768123
// [INFO] Initial Year 12 end block: 189216123
//
// [SCENARIO 2] Set Distribution Start Height to 5000
// [INFO] New emission start height: 5000
// [INFO] New Year 1 end block: 15772999
// [INFO] New Year 12 end block: 189220999
// [EXPECTED] Emission start should be 5000
// [EXPECTED] All halving years should be shifted by ~4876 blocks
//
// [SCENARIO 3] Override Distribution Start Height to 10000
// [INFO] New emission start height: 10000
// [INFO] New Year 1 end block: 15777999
// [INFO] New Year 12 end block: 189225999
// [EXPECTED] Emission start should be 10000
// [EXPECTED] All halving years should be recalculated from 10000
//
// [VERIFICATION] Halving Year Shifts
// [INFO] Shift from initial to 5000: 4876 blocks
// [INFO] Shift from 5000 to 10000: 5000 blocks
// [INFO] Year 12 end shift (initial to 5000): 4876 blocks
// [INFO] Year 12 end shift (5000 to 10000): 5000 blocks
// [EXPECTED] All shifts should match the distribution start height changes
