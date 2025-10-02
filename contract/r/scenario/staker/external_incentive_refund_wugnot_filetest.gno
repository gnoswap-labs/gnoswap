// External incentive WUGNOT refund test
// Test 2: Create incentive with WUGNOT -> refunds in WUGNOT

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"chain/banker"
	"testing"
	"time"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/onbloc/bar"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"

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
	println("[TEST] WUGNOT incentive -> WUGNOT refund test")
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

	println("[STEP 4] Create external incentive with WUGNOT")
	createExternalIncentiveWithWUGNOT()
	println()

	println("[STEP 5] End external incentive and verify WUGNOT refund")
	endIncentiveAndVerifyWUGNOTRefund()
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

	// Wrap some GNOT first to create WUGNOT pool
	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 10_000_000_000}})
	testing.SetOriginSend(chain.Coins{{"ugnot", 5_000_000_000}})
	wugnot.Deposit(cross)

	wugnot.Approve(cross, poolAddr, maxInt64)
	bar.Approve(cross, poolAddr, maxInt64)

	println("[INFO] create wugnot:bar:100 pool")
	pl.CreatePool(cross, wugnotPath, barPath, fee100, "79228162514264337593543950336") // sqrt(1) * 2^96

	testing.SkipHeights(1)
}

func mintPosition() {
	testing.SetRealm(adminRealm)

	wugnot.Approve(cross, poolAddr, maxInt64)
	bar.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint position with liquidity")
	tokenId, liquidity, _, _ := pn.Mint(
		cross,
		wugnotPath,
		barPath,
		fee100,
		int32(-20),
		int32(20),
		"1000000000",
		"1000000000",
		"0",
		"0",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[INFO] position ID: %d\n", tokenId)
	ufmt.Printf("[INFO] liquidity: %s\n", liquidity)

	testing.SkipHeights(1)
}

func createExternalIncentiveWithWUGNOT() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve WUGNOT and GNS for external incentive")
	wugnot.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	oldUgnotBal := ugnotBalanceOf(adminAddr)
	oldWugnotBal := wugnot.BalanceOf(adminAddr)
	ufmt.Printf("[INFO] GNOT balance before creating incentive: %d\n", oldUgnotBal)
	ufmt.Printf("[INFO] WUGNOT balance before creating incentive: %d\n", oldWugnotBal)

	println("[INFO] create external incentive with WUGNOT (wrapped token)")

	currentTime := time.Now().Unix()
	ufmt.Printf("[INFO] current time: %d\n", currentTime)

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/gnoland/wugnot:gno.land/r/onbloc/bar:100",
		wugnotPath, // Use WUGNOT directly, not "gnot"
		1_000_000_000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	createdIncentiveID = ufmt.Sprintf("%s:%d:1", adminAddr.String(), currentTime)
	ufmt.Printf("[INFO] external incentive created successfully with ID: %s\n", createdIncentiveID)

	newUgnotBal := ugnotBalanceOf(adminAddr)
	newWugnotBal := wugnot.BalanceOf(adminAddr)
	ufmt.Printf("[INFO] GNOT balance after creating incentive: %d\n", newUgnotBal)
	ufmt.Printf("[INFO] WUGNOT balance after creating incentive: %d\n", newWugnotBal)
	ufmt.Printf("[INFO] WUGNOT spent for incentive: %d\n", oldWugnotBal-newWugnotBal)

	testing.SkipHeights(1)
}

func endIncentiveAndVerifyWUGNOTRefund() {
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
		"gno.land/r/gnoland/wugnot:gno.land/r/onbloc/bar:100",
		createdIncentiveID,
	)

	newUgnotBal := ugnotBalanceOf(adminAddr)
	newWugnotBal := wugnot.BalanceOf(adminAddr)

	ufmt.Printf("[INFO] GNOT balance after ending: %d\n", newUgnotBal)
	ufmt.Printf("[INFO] WUGNOT balance after ending: %d\n", newWugnotBal)

	gnotChange := newUgnotBal - oldUgnotBal
	wugnotRefunded := newWugnotBal - oldWugnotBal

	ufmt.Printf("[EXPECTED] GNOT change (should be 0): %d\n", gnotChange)
	ufmt.Printf("[EXPECTED] WUGNOT refunded: %d\n", wugnotRefunded)

	if gnotChange != 0 {
		panic("[FAIL] GNOT balance should not change when refunding WUGNOT incentive")
	}

	if wugnotRefunded <= 0 {
		panic("[FAIL] Expected WUGNOT refund but got none")
	}

	println("[PASS] WUGNOT incentive correctly refunded as WUGNOT")
}

func ugnotBalanceOf(addr address) uint64 {
	banker_ := banker.NewBanker(banker.BankerTypeReadonly)
	coins := banker_.GetCoins(addr)
	return uint64(coins.AmountOf("ugnot"))
}

// Output:
// [TEST] WUGNOT incentive -> WUGNOT refund test
//
// [STEP 1] Initialize and setup
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
//
// [STEP 2] Create pool
// [INFO] create wugnot:bar:100 pool
//
// [STEP 3] Mint position
// [INFO] mint position with liquidity
// [INFO] position ID: 1
// [INFO] liquidity: 1000550082495
//
// [STEP 4] Create external incentive with WUGNOT
// [INFO] approve WUGNOT and GNS for external incentive
// [INFO] GNOT balance before creating incentive: 10000000000
// [INFO] WUGNOT balance before creating incentive: 4000000000
// [INFO] create external incentive with WUGNOT (wrapped token)
// [INFO] current time: 1234567900
// [INFO] external incentive created successfully with ID: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d:1234567900:1
// [INFO] GNOT balance after creating incentive: 10000000000
// [INFO] WUGNOT balance after creating incentive: 3000000000
// [INFO] WUGNOT spent for incentive: 1000000000
//
// [STEP 5] End external incentive and verify WUGNOT refund
// [INFO] skip time to after incentive end time
// [INFO] end external incentive and check WUGNOT refund
// [INFO] GNOT balance before ending: 10000000000
// [INFO] WUGNOT balance before ending: 3000000000
// [INFO] ending incentive with ID: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d:1234567900:1
// [INFO] GNOT balance after ending: 10000000000
// [INFO] WUGNOT balance after ending: 4000000000
// [EXPECTED] GNOT change (should be 0): 0
// [EXPECTED] WUGNOT refunded: 1000000000
// [PASS] WUGNOT incentive correctly refunded as WUGNOT
