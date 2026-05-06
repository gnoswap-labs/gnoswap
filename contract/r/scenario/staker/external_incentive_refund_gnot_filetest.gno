// External incentive GNOT refund test
// Test 1: Create incentive with GNOT -> refunds in WUGNOT

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"chain/banker"
	"testing"
	"time"

	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/access"
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
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	wugnotAddr address = "g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	gnsPath    = "gno.land/r/gnoswap/gns"
	wugnotPath = "gno.land/r/gnoland/wugnot"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60

	createdIncentiveID string // Store incentive ID for later use
)

func main() {
	println("[TEST] GNOT incentive -> GNOT refund test")
	println()

	println("[STEP 1] Initialize and setup")
	initAndSetup()
	println()

	println("[STEP 2] Create pool")
	createPool()
	println()

	println("[STEP 3] Mint position")
	mintPosition()
	println()

	println("[STEP 4] Create external incentive with GNOT")
	// Deposit must be called from main() due to AssertOriginCall frame limit
	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 100_000_000_000_000}})
	testing.SetRealm(adminRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 1_000_000_000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(chain.Coins{})
	createExternalIncentiveWithGNOT()
	println()

	println("[STEP 5] End external incentive and verify GNOT refund")
	endIncentiveAndVerifyGNOTRefund()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)
}

func createPool() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	println("[INFO] create bar:baz:100 pool")
	pl.CreatePool(cross, barPath, bazPath, fee100, "70710695859404174631") // sqrt(2500) * 2^96

	testing.SkipHeights(1)
}

func mintPosition() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint position with liquidity")
	tokenId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-20),
		int32(20),
		"100000",
		"100000",
		"0",
		"0",
		maxTimeout,
		adminAddr,
		"")

	ufmt.Printf("[INFO] position ID: %d\n", tokenId)
	ufmt.Printf("[INFO] liquidity: %s\n", liquidity)

	testing.SkipHeights(1)
}

func createExternalIncentiveWithGNOT() {
	testing.SetRealm(adminRealm)

	// Deposit already done in main()
	println("[INFO] approve WUGNOT and GNS for external incentive")
	wugnot.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	oldWugnotBal := wugnot.BalanceOf(adminAddr)
	ufmt.Printf("[INFO] WUGNOT balance before creating incentive: %d\n", oldWugnotBal)

	println("[INFO] create external incentive with GNOT (native coin)")
	defer func() {
		if r := recover(); r != nil {
			ufmt.Printf("[ERROR] Failed to create incentive: %v\n", r)
			panic(r)
		}
	}()

	currentTime := time.Now().Unix()
	ufmt.Printf("[INFO] current time: %d\n", currentTime)

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100",
		wugnotPath,
		1_000_000_000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	createdIncentiveID = ufmt.Sprintf("%s:%d:1", adminAddr.String(), currentTime)
	ufmt.Printf("[INFO] external incentive created successfully with ID: %s\n", createdIncentiveID)

	newWugnotBal := wugnot.BalanceOf(adminAddr)
	ufmt.Printf("[INFO] WUGNOT balance after creating incentive: %d\n", newWugnotBal)
	ufmt.Printf("[INFO] WUGNOT spent for incentive: %d\n", oldWugnotBal-newWugnotBal)

	testing.SkipHeights(1)
}

func endIncentiveAndVerifyGNOTRefund() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip time to after incentive end time")
	testing.SkipHeights(999999999) // Skip far into the future

	println("[INFO] end external incentive and check WUGNOT refund")

	oldUgnotBal := ugnotBalanceOf(adminAddr)
	oldWugnotBal := wugnot.BalanceOf(adminAddr)

	ufmt.Printf("[INFO] GNOT balance before ending: %d\n", oldUgnotBal)
	ufmt.Printf("[INFO] WUGNOT balance before ending: %d\n", oldWugnotBal)

	ufmt.Printf("[INFO] ending incentive with ID: %s\n", createdIncentiveID)
	sr.EndExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100",
		createdIncentiveID,
		adminUser,
	)

	newUgnotBal := ugnotBalanceOf(adminAddr)
	newWugnotBal := wugnot.BalanceOf(adminAddr)

	ufmt.Printf("[INFO] GNOT balance after ending: %d\n", newUgnotBal)
	ufmt.Printf("[INFO] WUGNOT balance after ending: %d\n", newWugnotBal)

	ugnotChange := newUgnotBal - oldUgnotBal
	wugnotRefunded := newWugnotBal - oldWugnotBal

	ufmt.Printf("[EXPECTED] GNOT change (should be 0): %d\n", ugnotChange)
	ufmt.Printf("[EXPECTED] WUGNOT refunded: %d\n", wugnotRefunded)

	if ugnotChange != 0 {
		panic("[FAIL] GNOT balance should not change, refund is now in WUGNOT")
	}

	if wugnotRefunded <= 0 {
		panic("[FAIL] Expected WUGNOT refund but got none")
	}

	println("[PASS] GNOT incentive correctly refunded as WUGNOT")
}

func ugnotBalanceOf(addr address) uint64 {
	banker_ := banker.NewBanker(banker.BankerTypeReadonly)
	coins := banker_.GetCoins(addr)
	return uint64(coins.AmountOf("ugnot"))
}

// Output:
// [TEST] GNOT incentive -> GNOT refund test
//
// [STEP 1] Initialize and setup
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
//
// [STEP 2] Create pool
// [INFO] create bar:baz:100 pool
//
// [STEP 3] Mint position
// [INFO] mint position with liquidity
// [INFO] position ID: 1
// [INFO] liquidity: 50002491
//
// [STEP 4] Create external incentive with GNOT
// [INFO] approve WUGNOT and GNS for external incentive
// [INFO] WUGNOT balance before creating incentive: 1000000000
// [INFO] create external incentive with GNOT (native coin)
// [INFO] current time: 1234567900
// [INFO] external incentive created successfully with ID: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5:1234567900:1
// [INFO] WUGNOT balance after creating incentive: 0
// [INFO] WUGNOT spent for incentive: 1000000000
//
// [STEP 5] End external incentive and verify GNOT refund
// [INFO] skip time to after incentive end time
// [INFO] end external incentive and check WUGNOT refund
// [INFO] GNOT balance before ending: 100000000000000
// [INFO] WUGNOT balance before ending: 0
// [INFO] ending incentive with ID: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5:1234567900:1
// [INFO] GNOT balance after ending: 100000000000000
// [INFO] WUGNOT balance after ending: 1000000000
// [EXPECTED] GNOT change (should be 0): 0
// [EXPECTED] WUGNOT refunded: 1000000000
// [PASS] GNOT incentive correctly refunded as WUGNOT
