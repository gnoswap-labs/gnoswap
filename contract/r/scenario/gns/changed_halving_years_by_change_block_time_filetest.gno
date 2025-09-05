// changed halving years by change block time (2000ms -> 3500ms)
package main

import (
	"testing"
	"time"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	_ "gno.land/r/gnoswap/v1/staker"
)

var t *testing.T

var adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())

const (
	milliSecondsOfYear = 31536000000 // 365 * 24 * 60 * 60 * 1000
	defaultBlockTime   = 2000        // 2000ms
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize emission")
	initEmission()
	println()

	ufmt.Println("[SCENARIO] 2. Get halving years")
	getHalvingYears()
	println()

	ufmt.Println("[SCENARIO] 3. Skip 10000 blocks (distribute of half of 1 year)")
	testing.SetOriginCaller(adminAddr)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+10000*5)
	testing.SkipHeights(10000)
	println()

	ufmt.Println("[SCENARIO] 4. Get halving years")
	getHalvingYears()
	println()
}

func initEmission() {}

func getHalvingYears() {
	println("[INFO] current halving years", gns.GetHalvingYear(time.Now().Unix()))

	for year := int64(1); year <= 12; year++ {
		startBlockTime := gns.GetHalvingYearStartTimestamp(year)
		endBlockTime := gns.GetHalvingYearEndTimestamp(year)
		timeDiff := endBlockTime - startBlockTime + 1
		ufmt.Printf("[EXPECTED] halving year %d time range %d~%d (time diff: %d)\n", year, startBlockTime, endBlockTime, timeDiff)
	}
}

// Output:
// [SCENARIO] 1. Initialize emission
//
// [SCENARIO] 2. Get halving years
// [INFO] current halving years 0
// [EXPECTED] halving year 1 time range 0~31535999 (time diff: 31536000)
// [EXPECTED] halving year 2 time range 31536000~63071999 (time diff: 31536000)
// [EXPECTED] halving year 3 time range 63072000~94607999 (time diff: 31536000)
// [EXPECTED] halving year 4 time range 94608000~126143999 (time diff: 31536000)
// [EXPECTED] halving year 5 time range 126144000~157679999 (time diff: 31536000)
// [EXPECTED] halving year 6 time range 157680000~189215999 (time diff: 31536000)
// [EXPECTED] halving year 7 time range 189216000~220751999 (time diff: 31536000)
// [EXPECTED] halving year 8 time range 220752000~252287999 (time diff: 31536000)
// [EXPECTED] halving year 9 time range 252288000~283823999 (time diff: 31536000)
// [EXPECTED] halving year 10 time range 283824000~315359999 (time diff: 31536000)
// [EXPECTED] halving year 11 time range 315360000~346895999 (time diff: 31536000)
// [EXPECTED] halving year 12 time range 346896000~378431999 (time diff: 31536000)
//
// [SCENARIO] 3. Skip 10000 blocks (distribute of half of 1 year)
//
// [SCENARIO] 4. Get halving years
// [INFO] current halving years 1
// [EXPECTED] halving year 1 time range 1234617890~1266153889 (time diff: 31536000)
// [EXPECTED] halving year 2 time range 1266153890~1297689889 (time diff: 31536000)
// [EXPECTED] halving year 3 time range 1297689890~1329225889 (time diff: 31536000)
// [EXPECTED] halving year 4 time range 1329225890~1360761889 (time diff: 31536000)
// [EXPECTED] halving year 5 time range 1360761890~1392297889 (time diff: 31536000)
// [EXPECTED] halving year 6 time range 1392297890~1423833889 (time diff: 31536000)
// [EXPECTED] halving year 7 time range 1423833890~1455369889 (time diff: 31536000)
// [EXPECTED] halving year 8 time range 1455369890~1486905889 (time diff: 31536000)
// [EXPECTED] halving year 9 time range 1486905890~1518441889 (time diff: 31536000)
// [EXPECTED] halving year 10 time range 1518441890~1549977889 (time diff: 31536000)
// [EXPECTED] halving year 11 time range 1549977890~1581513889 (time diff: 31536000)
// [EXPECTED] halving year 12 time range 1581513890~1613049889 (time diff: 31536000)
