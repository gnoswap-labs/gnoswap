// staker external native coin incentive scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/demo/wugnot"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	wugnotAddr std.Address = "g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6"

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	gnsPath    = "gno.land/r/gnoswap/v1/gns"
	wugnotPath = "gno.land/r/demo/wugnot"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint position 01")
	mintPosition01()
	println()

	println("[SCENARIO] 4. Create external incentive with native coin (gnot)")
	createExternalIncentiveWithNativeCoin()
	println()

	println("[SCENARIO] 5. Stake token 01")
	stakeToken01()
	println()

	println("[SCENARIO] 6. Collect external reward with unwrap")
	collectExternalRewardWithUnwrap()
	println()

	println("[SCENARIO] 7. Collect external reward without unwrap")
	collectExternalRewardWithoutUnwrap()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve gns for pool creation")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())

	println("[INFO] create bar:baz:100 pool")
	pl.CreatePool(cross, barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SkipHeights(1)
}

func mintPosition01() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(2)

	println("[INFO] mint position 01 (tick range: -1000 ~ 1000)")
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-1000),
		int32(1000),
		"100000",
		"100000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position ID: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s, amount1: %s\n", amount0, amount1)

	testing.SkipHeights(1)
}

func createExternalIncentiveWithNativeCoin() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve wugnot for external incentive")
	wugnot.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	println("[INFO] prepare native coins for external incentive")
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 100_000_000_000_000}})
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminAddr, stakerAddr, std.Coins{{"ugnot", 1_000_000_000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 1_000_000_000}})

	println("[INFO] create external incentive with gnot (native coin)")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100", // targetPoolPath
		"gnot",                      // rewardToken (native coin)
		1_000_000_000,               // rewardAmount (100 gnot)
		1234569600,                  // startTimestamp
		1234569600+TIMESTAMP_90DAYS, // endTimestamp
	)

	ufmt.Printf("[INFO] native coin external incentive created\n")
	ufmt.Printf("[INFO] start time: %d, end time: %d\n", 1234569600, 1234569600+TIMESTAMP_90DAYS)

	testing.SkipHeights(1)
}

func stakeToken01() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))

	println("[INFO] stake token 01")
	sr.StakeToken(cross, 1, "")

	testing.SkipHeights(1)
}

func collectExternalRewardWithUnwrap() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate rewards")
	testing.SkipHeights(900)
	sr.CollectReward(cross, 1, false)

	testing.SkipHeights(1)

	println("[INFO] check balances before collecting with unwrap")
	oldUgnotBal := ugnotBalanceOf(adminAddr)
	oldWugnotBal := wugnot.BalanceOf(adminAddr)

	ufmt.Printf("[INFO] ugnot balance before: %d\n", oldUgnotBal)
	ufmt.Printf("[INFO] wugnot balance before: %d\n", oldWugnotBal)

	println("[INFO] collect reward with unwrap=true")
	sr.CollectReward(cross, 1, true) // unwrap=true

	newUgnotBal := ugnotBalanceOf(adminAddr)
	newWugnotBal := wugnot.BalanceOf(adminAddr)

	ufmt.Printf("[EXPECTED] ugnot balance after: %d\n", newUgnotBal)
	ufmt.Printf("[EXPECTED] wugnot balance after: %d\n", newWugnotBal)

	ugnotIncrease := newUgnotBal - oldUgnotBal
	wugnotChange := newWugnotBal - oldWugnotBal

	ufmt.Printf("[EXPECTED] ugnot increase (unwrapped): %d\n", ugnotIncrease)
	ufmt.Printf("[EXPECTED] wugnot change (should be 0): %d\n", wugnotChange)

	if ugnotIncrease <= 0 {
		panic("should have received unwrapped ugnot")
	}

	if wugnotChange != 0 {
		panic("wugnot balance should not change when unwrapping")
	}
}

func collectExternalRewardWithoutUnwrap() {
	testing.SetRealm(adminRealm)

	println("[INFO] check balances before collecting without unwrap")
	oldUgnotBal := ugnotBalanceOf(adminAddr)
	oldWugnotBal := wugnot.BalanceOf(adminAddr)

	ufmt.Printf("[INFO] ugnot balance before: %d\n", oldUgnotBal)
	ufmt.Printf("[INFO] wugnot balance before: %d\n", oldWugnotBal)

	testing.SkipHeights(1)

	println("[INFO] collect reward with unwrap=false")
	sr.CollectReward(cross, 1, false) // unwrap=false

	newUgnotBal := ugnotBalanceOf(adminAddr)
	newWugnotBal := wugnot.BalanceOf(adminAddr)

	ufmt.Printf("[EXPECTED] ugnot balance after: %d\n", newUgnotBal)
	ufmt.Printf("[EXPECTED] wugnot balance after: %d\n", newWugnotBal)

	ugnotChange := newUgnotBal - oldUgnotBal
	wugnotIncrease := newWugnotBal - oldWugnotBal

	ufmt.Printf("[EXPECTED] ugnot change (should be 0): %d\n", ugnotChange)
	ufmt.Printf("[EXPECTED] wugnot increase (wrapped): %d\n", wugnotIncrease)

	if ugnotChange != 0 {
		panic("ugnot balance should not change when not unwrapping")
	}

	if wugnotIncrease <= 0 {
		panic("should have received wrapped wugnot")
	}
}

func ugnotBalanceOf(addr std.Address) uint64 {
	banker := std.NewBanker(std.BankerTypeReadonly)
	coins := banker.GetCoins(addr)
	return uint64(coins.AmountOf("ugnot"))
}

func positionIdFrom(positionId any) grc721.TokenID {
	if positionId == nil {
		panic("positionId is nil")
	}

	switch positionId.(type) {
	case string:
		return grc721.TokenID(positionId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(positionId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId.(uint64))))
	case grc721.TokenID:
		return positionId.(grc721.TokenID)
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize and setup
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create bar:baz:100 pool
// [INFO] approve gns for pool creation
// [INFO] create bar:baz:100 pool
//
// [SCENARIO] 3. Mint position 01
// [INFO] approve tokens for minting
// [INFO] mint position 01 (tick range: -1000 ~ 1000)
// [EXPECTED] position ID: 1
// [EXPECTED] liquidity: 2050516
// [EXPECTED] amount0: 100000, amount1: 100000
//
// [SCENARIO] 4. Create external incentive with native coin (gnot)
// [INFO] approve wugnot for external incentive
// [INFO] prepare native coins for external incentive
// [INFO] create external incentive with gnot (native coin)
// [INFO] native coin external incentive created
// [INFO] start time: 1234569600, end time: 1242345600
//
// [SCENARIO] 5. Stake token 01
// [INFO] approve NFT to staker
// [INFO] stake token 01
//
// [SCENARIO] 6. Collect external reward with unwrap
// [INFO] skip blocks to accumulate rewards
// [INFO] check balances before collecting with unwrap
// [INFO] ugnot balance before: 99999000000000
// [INFO] wugnot balance before: 4394
// [INFO] collect reward with unwrap=true
// [EXPECTED] ugnot balance after: 99999000000076
// [EXPECTED] wugnot balance after: 4394
// [EXPECTED] ugnot increase (unwrapped): 76
// [EXPECTED] wugnot change (should be 0): 0
//
// [SCENARIO] 7. Collect external reward without unwrap
// [INFO] check balances before collecting without unwrap
// [INFO] ugnot balance before: 99999000000076
// [INFO] wugnot balance before: 4394
// [INFO] collect reward with unwrap=false
// [EXPECTED] ugnot balance after: 99999000000076
// [EXPECTED] wugnot balance after: 4470
// [EXPECTED] ugnot change (should be 0): 0
// [EXPECTED] wugnot increase (wrapped): 76
