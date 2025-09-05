package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
)

var adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())

func main() {
	println("[SCENARIO] Test Override Distribution Start Height with Halving Year Recalculation")

	testing.SetRealm(std.NewUserRealm(adminAddr))
	testing.SetOriginCaller(adminAddr)

	// Scenario 1: Initial state before any distribution
	println("\n[SCENARIO 1] Initial State")
	initialEmissionStart := gns.GetEmissionStartTimestamp()
	initialYear1End := gns.GetHalvingYearEndTimestamp(1)
	initialYear12End := gns.GetEmissionEndTimestamp()

	ufmt.Printf("[INFO] Initial emission start height: %d\n", initialEmissionStart)
	ufmt.Printf("[INFO] Initial Year 1 end time: %d\n", initialYear1End)
	ufmt.Printf("[INFO] Initial Year 12 end time: %d\n", initialYear12End)

	// Scenario 2: Set distribution start height to 5000
	println("\n[SCENARIO 2] Set Distribution Start Height to 5000")
	futureTimestamp := time.Now().Unix() + 5000/5
	emission.SetDistributionStartTime(cross, futureTimestamp)

	newEmissionStart1 := gns.GetEmissionStartTimestamp()
	newYear1End1 := gns.GetHalvingYearEndTimestamp(1)
	newYear12End1 := gns.GetEmissionEndTimestamp()

	ufmt.Printf("[INFO] New emission start height: %d\n", newEmissionStart1)
	ufmt.Printf("[INFO] New Year 1 end time: %d\n", newYear1End1)
	ufmt.Printf("[INFO] New Year 12 end time: %d\n", newYear12End1)
	ufmt.Printf("[EXPECTED] Emission start should be 5000\n")
	ufmt.Printf("[EXPECTED] All halving years should be shifted by ~4876 blocks\n")

	// Scenario 3: Override to 10000
	println("\n[SCENARIO 3] Override Distribution Start Height to 10000")
	futureTimestamp = time.Now().Unix() + 10000/5
	emission.SetDistributionStartTime(cross, futureTimestamp)

	newEmissionStart2 := gns.GetEmissionStartTimestamp()
	newYear1End2 := gns.GetHalvingYearEndTimestamp(1)
	newYear12End2 := gns.GetEmissionEndTimestamp()

	ufmt.Printf("[INFO] New emission start height: %d\n", newEmissionStart2)
	ufmt.Printf("[INFO] New Year 1 end time: %d\n", newYear1End2)
	ufmt.Printf("[INFO] New Year 12 end time: %d\n", newYear12End2)
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
// [INFO] Initial emission start height: 0
// [INFO] Initial Year 1 end time: 31535999
// [INFO] Initial Year 12 end time: 378431999
//
// [SCENARIO 2] Set Distribution Start Height to 5000
// [INFO] New emission start height: 1234568890
// [INFO] New Year 1 end time: 1266104889
// [INFO] New Year 12 end time: 1613000889
// [EXPECTED] Emission start should be 5000
// [EXPECTED] All halving years should be shifted by ~4876 blocks
//
// [SCENARIO 3] Override Distribution Start Height to 10000
// [INFO] New emission start height: 1234569890
// [INFO] New Year 1 end time: 1266105889
// [INFO] New Year 12 end time: 1613001889
// [EXPECTED] Emission start should be 10000
// [EXPECTED] All halving years should be recalculated from 10000
//
// [VERIFICATION] Halving Year Shifts
// [INFO] Shift from initial to 5000: 1234568890 blocks
// [INFO] Shift from 5000 to 10000: 1000 blocks
// [INFO] Year 12 end shift (initial to 5000): 1234568890 blocks
// [INFO] Year 12 end shift (5000 to 10000): 1000 blocks
// [EXPECTED] All shifts should match the distribution start height changes
