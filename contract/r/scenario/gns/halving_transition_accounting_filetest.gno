// PKGPATH: gno.land/r/gnoswap/v1/main

// verifies monthly emission accounting across the complete halving schedule.
package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/scenarioutils"
)

var t *testing.T

var (
	user01Addr   = testutils.TestAddress("user01Addr")
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
)

const (
	secondsInYear    = int64(365 * 24 * 60 * 60)
	defaultBlockTime = int64(5)
	monthsInYear     = int64(12)
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize emission")
	testing.SetOriginCaller(adminAddr)
	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)

	println("[SCENARIO] 2. Mint monthly through all halving years")
	mintGNS(cur) // Establish the emission start.

	blocksInMonth := secondsInYear / monthsInYear / defaultBlockTime
	for year := int64(1); year <= 12; year++ {
		monthlyAccumulatedAmounts := make([]int64, monthsInYear)
		monthlyLeftAmounts := make([]int64, monthsInYear)

		for month := int64(1); month <= monthsInYear; month++ {
			testing.SkipHeights(blocksInMonth)
			mintGNS(cur)
			assertHalvingAccounting(year, month < monthsInYear)
			monthlyAccumulatedAmounts[month-1] = gns.GetHalvingYearAccuAmount(year)
			monthlyLeftAmounts[month-1] = gns.GetHalvingYearLeftAmount(year)
		}

		ufmt.Printf(
			"[CHECK] year %d monthly accumulated %d %d %d %d %d %d %d %d %d %d %d %d\n",
			year,
			monthlyAccumulatedAmounts[0], monthlyAccumulatedAmounts[1], monthlyAccumulatedAmounts[2], monthlyAccumulatedAmounts[3],
			monthlyAccumulatedAmounts[4], monthlyAccumulatedAmounts[5], monthlyAccumulatedAmounts[6], monthlyAccumulatedAmounts[7],
			monthlyAccumulatedAmounts[8], monthlyAccumulatedAmounts[9], monthlyAccumulatedAmounts[10], monthlyAccumulatedAmounts[11],
		)
		ufmt.Printf(
			"[CHECK] year %d monthly left %d %d %d %d %d %d %d %d %d %d %d %d\n",
			year,
			monthlyLeftAmounts[0], monthlyLeftAmounts[1], monthlyLeftAmounts[2], monthlyLeftAmounts[3],
			monthlyLeftAmounts[4], monthlyLeftAmounts[5], monthlyLeftAmounts[6], monthlyLeftAmounts[7],
			monthlyLeftAmounts[8], monthlyLeftAmounts[9], monthlyLeftAmounts[10], monthlyLeftAmounts[11],
		)
		ufmt.Printf("[CHECK] total minted amount %d\n", gns.MintedEmissionAmount())
	}
}

func mintGNS(cur realm) int64 {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/emission"))
	return gns.MintGns(cross(cur), user01Addr)
}

func assertHalvingAccounting(currentYear int64, expectPartialCurrentYear bool) {
	totalAccumulated := int64(0)

	for year := int64(1); year <= 12; year++ {
		maxAmount := gns.GetHalvingYearMaxAmount(year)
		accumulatedAmount := gns.GetHalvingYearAccuAmount(year)
		leftAmount := gns.GetHalvingYearLeftAmount(year)

		if accumulatedAmount+leftAmount != maxAmount {
			panic("halving accounting invariant violated")
		}
		totalAccumulated += accumulatedAmount
	}

	if totalAccumulated != gns.MintedEmissionAmount() {
		panic("halving accumulated amount does not match total minted amount")
	}

	for year := int64(1); year < currentYear; year++ {
		if gns.GetHalvingYearAccuAmount(year) != gns.GetHalvingYearMaxAmount(year) {
			panic("completed halving year is not fully minted")
		}
	}

	currentAccumulatedAmount := gns.GetHalvingYearAccuAmount(currentYear)
	if expectPartialCurrentYear && (currentAccumulatedAmount <= 0 || currentAccumulatedAmount >= gns.GetHalvingYearMaxAmount(currentYear)) {
		panic("current halving year is not partially minted")
	}
}

// Output:
// [SCENARIO] 1. Initialize emission
// [SCENARIO] 2. Mint monthly through all halving years
// [CHECK] year 1 monthly accumulated 18749999484000 37499998968000 56249998452000 74999997936000 93749997420000 112499996904000 131249996388000 149999995872000 168749995356000 187499994840000 206249994324000 225000000000000
// [CHECK] year 1 monthly left 206250000516000 187500001032000 168750001548000 150000002064000 131250002580000 112500003096000 93750003612000 75000004128000 56250004644000 37500005160000 18750005676000 0
// [CHECK] total minted amount 225000000000000
// [CHECK] year 2 monthly accumulated 18749999484000 37499998968000 56249998452000 74999997936000 93749997420000 112499996904000 131249996388000 149999995872000 168749995356000 187499994840000 206249994324000 225000000000000
// [CHECK] year 2 monthly left 206250000516000 187500001032000 168750001548000 150000002064000 131250002580000 112500003096000 93750003612000 75000004128000 56250004644000 37500005160000 18750005676000 0
// [CHECK] total minted amount 450000000000000
// [CHECK] year 3 monthly accumulated 9374998428000 18749996856000 28124995284000 37499993712000 46874992140000 56249990568000 65624988996000 74999987424000 84374985852000 93749984280000 103124982708000 112500000000000
// [CHECK] year 3 monthly left 103125001572000 93750003144000 84375004716000 75000006288000 65625007860000 56250009432000 46875011004000 37500012576000 28125014148000 18750015720000 9375017292000 0
// [CHECK] total minted amount 562500000000000
// [CHECK] year 4 monthly accumulated 9374998428000 18749996856000 28124995284000 37499993712000 46874992140000 56249990568000 65624988996000 74999987424000 84374985852000 93749984280000 103124982708000 112500000000000
// [CHECK] year 4 monthly left 103125001572000 93750003144000 84375004716000 75000006288000 65625007860000 56250009432000 46875011004000 37500012576000 28125014148000 18750015720000 9375017292000 0
// [CHECK] total minted amount 675000000000000
// [CHECK] year 5 monthly accumulated 4687497900000 9374995800000 14062493700000 18749991600000 23437489500000 28124987400000 32812485300000 37499983200000 42187481100000 46874979000000 51562476900000 56250000000000
// [CHECK] year 5 monthly left 51562502100000 46875004200000 42187506300000 37500008400000 32812510500000 28125012600000 23437514700000 18750016800000 14062518900000 9375021000000 4687523100000 0
// [CHECK] total minted amount 731250000000000
// [CHECK] year 6 monthly accumulated 4687497900000 9374995800000 14062493700000 18749991600000 23437489500000 28124987400000 32812485300000 37499983200000 42187481100000 46874979000000 51562476900000 56250000000000
// [CHECK] year 6 monthly left 51562502100000 46875004200000 42187506300000 37500008400000 32812510500000 28125012600000 23437514700000 18750016800000 14062518900000 9375021000000 4687523100000 0
// [CHECK] total minted amount 787500000000000
// [CHECK] year 7 monthly accumulated 2343747636000 4687495272000 7031242908000 9374990544000 11718738180000 14062485816000 16406233452000 18749981088000 21093728724000 23437476360000 25781223996000 28125000000000
// [CHECK] year 7 monthly left 25781252364000 23437504728000 21093757092000 18750009456000 16406261820000 14062514184000 11718766548000 9375018912000 7031271276000 4687523640000 2343776004000 0
// [CHECK] total minted amount 815625000000000
// [CHECK] year 8 monthly accumulated 2343747636000 4687495272000 7031242908000 9374990544000 11718738180000 14062485816000 16406233452000 18749981088000 21093728724000 23437476360000 25781223996000 28125000000000
// [CHECK] year 8 monthly left 25781252364000 23437504728000 21093757092000 18750009456000 16406261820000 14062514184000 11718766548000 9375018912000 7031271276000 4687523640000 2343776004000 0
// [CHECK] total minted amount 843750000000000
// [CHECK] year 9 monthly accumulated 1171872504000 2343745008000 3515617512000 4687490016000 5859362520000 7031235024000 8203107528000 9374980032000 10546852536000 11718725040000 12890597544000 14062500000000
// [CHECK] year 9 monthly left 12890627496000 11718754992000 10546882488000 9375009984000 8203137480000 7031264976000 5859392472000 4687519968000 3515647464000 2343774960000 1171902456000 0
// [CHECK] total minted amount 857812500000000
// [CHECK] year 10 monthly accumulated 1171872504000 2343745008000 3515617512000 4687490016000 5859362520000 7031235024000 8203107528000 9374980032000 10546852536000 11718725040000 12890597544000 14062500000000
// [CHECK] year 10 monthly left 12890627496000 11718754992000 10546882488000 9375009984000 8203137480000 7031264976000 5859392472000 4687519968000 3515647464000 2343774960000 1171902456000 0
// [CHECK] total minted amount 871875000000000
// [CHECK] year 11 monthly accumulated 1171872504000 2343745008000 3515617512000 4687490016000 5859362520000 7031235024000 8203107528000 9374980032000 10546852536000 11718725040000 12890597544000 14062500000000
// [CHECK] year 11 monthly left 12890627496000 11718754992000 10546882488000 9375009984000 8203137480000 7031264976000 5859392472000 4687519968000 3515647464000 2343774960000 1171902456000 0
// [CHECK] total minted amount 885937500000000
// [CHECK] year 12 monthly accumulated 1171872504000 2343745008000 3515617512000 4687490016000 5859362520000 7031235024000 8203107528000 9374980032000 10546852536000 11718725040000 12890597544000 14062500000000
// [CHECK] year 12 monthly left 12890627496000 11718754992000 10546882488000 9375009984000 8203137480000 7031264976000 5859392472000 4687519968000 3515647464000 2343774960000 1171902456000 0
// [CHECK] total minted amount 900000000000000
