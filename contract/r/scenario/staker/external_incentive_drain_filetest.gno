// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100

// POSITIONs:
// 1. in-range

// REWARDs:
// - external gns 90 days ( bar:qux:100 )

// This test demonstrates the vulnerability where EndExternalIncentive
// can be called multiple times to drain GNS from the staker contract
package main

import (
	"gno.land/p/gnoswap/gnsmath"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	externalCreatorAddr  = testutils.TestAddress("externalCreator")
	externalCreatorUser  = externalCreatorAddr
	externalCreatorRealm = testing.NewUserRealm(externalCreatorAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"
	gnsPath = "gno.land/r/gnoswap/gns"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60

	// global variable to store the actual incentive ID
	actualIncentiveID string

	t *testing.T
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize account and settings")
	initAccountAndSettings(cur)
	println()

	println("[SCENARIO] 2. Create pool")
	createPool(cur)
	println()

	println("[SCENARIO] 3. Mint bar qux position")
	mintBarQuxPosition(cur)
	println()

	println("[SCENARIO] 4. Create external incentive GNS")
	createExternalIncentiveGns(cur)
	println()

	println("[SCENARIO] 5. Start external incentive")
	startExternalIncentive(cur)
	println()

	println("[SCENARIO] 6. Stake position")
	stakePosition(cur)
	println()

	println("[SCENARIO] 7. End external incentive")
	endExternalGnsIncentive(cur)
	println()

	println("[SCENARIO] 8. FIX VERIFICATION: Verify EndExternalIncentive cannot be called multiple times")
	demonstrateVulnerability(cur)
	println()

	println("[SCENARIO] 9. Final verification")
	checkFinalState(cur)
}

func initAccountAndSettings(cur realm) {
	println("[INFO] set unstaking fee to 0")
	testing.SetRealm(adminRealm)
	sr.SetUnStakingFee(cross(cur), 0)

	// Transfer extra GNS to staker for testing drain
	println("[INFO] transfer extra GNS to staker contract for drain test")
	gns.Transfer(cross(cur), stakerAddr, 10_000_000_000) // 10,000 GNS
}

func createPool(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross(cur), 0)

	println("[INFO] create pool gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100 at tick 0")
	testing.SkipHeights(1)
	pl.CreatePool(
		cross(cur),
		barPath,
		quxPath,
		fee100,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
}

func mintBarQuxPosition(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for position")
	bar.Approve(cross(cur), poolAddr, maxInt64)
	qux.Approve(cross(cur), poolAddr, maxInt64)

	println("[INFO] mint in-range position (tick range: -50 ~ 50, requested amount: 50, 50)")
	testing.SkipHeights(1)
	pn.Mint(
		cross(cur),
		barPath,
		quxPath,
		fee100,
		int32(-50),
		int32(50),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)
}

func createExternalIncentiveGns(cur realm) {
	println("[INFO] transfer GNS to external creator")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), externalCreatorUser, 9000000000)
	gns.Transfer(cross(cur), externalCreatorUser, depositGnsAmount)

	println("[INFO] approve GNS for external incentive creation")
	testing.SetRealm(externalCreatorRealm)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	println("[INFO] create external incentive for 90 days")
	testing.SkipHeights(1)

	// Generate the incentive ID the same way the system does
	// time.Now().Unix() returns 1234567910 in the test environment
	actualIncentiveID = ufmt.Sprintf("%s:%d:%d", externalCreatorAddr, time.Now().Unix(), 1)
	println("[INFO] create external incentive with incentiveID: ", actualIncentiveID)

	sr.CreateExternalIncentive(
		cross(cur),
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		gnsPath,
		9000000000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)
}

func startExternalIncentive(cur realm) {
	externalStartTime := int64(1234569600)
	nowTime := time.Now().Unix()
	timeLeft := externalStartTime - nowTime

	blockLeft := timeLeft / 5

	println("[INFO] skip blocks until external incentive starts")
	testing.SkipHeights(int64(blockLeft))
	ufmt.Printf("[INFO] external incentive started at timestamp: %d\n", externalStartTime)
}

func stakePosition(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position")
	testing.SkipHeights(1)
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, 1))
	sr.StakeToken(cross(cur), 1, "")
}

func endExternalGnsIncentive(cur realm) {
	externalEndTime := (1234569600 + TIMESTAMP_90DAYS)
	nowTime := time.Now().Unix()
	timeLeft := externalEndTime - nowTime

	blockLeft := timeLeft/5 + 1

	println("[INFO] skip blocks until external incentive ends")
	testing.SkipHeights(int64(blockLeft))

	println("[INFO] end external incentive FIRST TIME and collect remaining GNS")
	testing.SetRealm(externalCreatorRealm)

	stakerGnsBeforeFirstEnd := gns.BalanceOf(stakerAddr)
	creatorGnsBeforeFirstEnd := gns.BalanceOf(externalCreatorUser)

	// Use the actual incentive ID that was created
	sr.EndExternalIncentive(
		cross(cur),
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		actualIncentiveID,
		externalCreatorUser,
	)

	stakerGnsAfterFirstEnd := gns.BalanceOf(stakerAddr)
	creatorGnsAfterFirstEnd := gns.BalanceOf(externalCreatorUser)

	ufmt.Printf("[INFO] FIRST END - Staker GNS balance before: %d\n", stakerGnsBeforeFirstEnd)
	ufmt.Printf("[INFO] FIRST END - Staker GNS balance after: %d\n", stakerGnsAfterFirstEnd)
	ufmt.Printf("[INFO] FIRST END - Creator GNS balance before: %d\n", creatorGnsBeforeFirstEnd)
	ufmt.Printf("[INFO] FIRST END - Creator GNS balance after: %d\n", creatorGnsAfterFirstEnd)
	ufmt.Printf("[INFO] FIRST END - Creator received: %d GNS\n", creatorGnsAfterFirstEnd-creatorGnsBeforeFirstEnd)
}

func demonstrateVulnerability(cur realm) {
	testing.SetRealm(externalCreatorRealm)

	println("[FIX VERIFICATION] Attempting to call EndExternalIncentive multiple times")
	println("[EXPECTED] Second call should fail with 'cannot end non existent incentive' error")

	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-008]", func() {
		sr.EndExternalIncentive(
			cross(cur),
			"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
			actualIncentiveID,
			externalCreatorUser,
		)
	})
}

func checkFinalState(cur realm) {
	stakerFinalBalance := gns.BalanceOf(stakerAddr)
	creatorFinalBalance := gns.BalanceOf(externalCreatorUser)

	println("[RESULT] Final balances after fix:")
	ufmt.Printf("  - Staker GNS balance: %d\n", stakerFinalBalance)
	ufmt.Printf("  - Creator GNS balance: %d\n", creatorFinalBalance)

	println("[VERIFIED] Staker was NOT drained - only one GNS deposit was refunded")
	println("[VERIFIED] The vulnerability has been successfully fixed")
}

func positionIdFrom(cur realm, positionId int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(positionId))
}

// Output:
// [SCENARIO] 1. Initialize account and settings
// [INFO] set unstaking fee to 0
// [INFO] transfer extra GNS to staker contract for drain test
//
// [SCENARIO] 2. Create pool
// [INFO] set pool creation fee to 0
// [INFO] create pool gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100 at tick 0
//
// [SCENARIO] 3. Mint bar qux position
// [INFO] approve tokens for position
// [INFO] mint in-range position (tick range: -50 ~ 50, requested amount: 50, 50)
//
// [SCENARIO] 4. Create external incentive GNS
// [INFO] transfer GNS to external creator
// [INFO] approve GNS for external incentive creation
// [INFO] create external incentive for 90 days
// [INFO] create external incentive with incentiveID:  g1v4u8getjdeskcsmjv4shgmmjta047h6lua7mup:1234567905:1
//
// [SCENARIO] 5. Start external incentive
// [INFO] skip blocks until external incentive starts
// [INFO] external incentive started at timestamp: 1234569600
//
// [SCENARIO] 6. Stake position
// [INFO] stake position
//
// [SCENARIO] 7. End external incentive
// [INFO] skip blocks until external incentive ends
// [INFO] end external incentive FIRST TIME and collect remaining GNS
// [INFO] FIRST END - Staker GNS balance before: 20000000000
// [INFO] FIRST END - Staker GNS balance after: 18999994212
// [INFO] FIRST END - Creator GNS balance before: 0
// [INFO] FIRST END - Creator GNS balance after: 1000005788
// [INFO] FIRST END - Creator received: 1000005788 GNS
//
// [SCENARIO] 8. FIX VERIFICATION: Verify EndExternalIncentive cannot be called multiple times
// [FIX VERIFICATION] Attempting to call EndExternalIncentive multiple times
// [EXPECTED] Second call should fail with 'cannot end non existent incentive' error
//
// [SCENARIO] 9. Final verification
// [RESULT] Final balances after fix:
//   - Staker GNS balance: 18999994212
//   - Creator GNS balance: 1000005788
// [VERIFIED] Staker was NOT drained - only one GNS deposit was refunded
// [VERIFIED] The vulnerability has been successfully fixed
