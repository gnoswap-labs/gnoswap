// position inrange change by swap internal incentive

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/demo/wugnot"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(access.ROLE_STAKER)
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _   = access.GetAddress(access.ROLE_POOL)
	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)
	routerRealm   = std.NewUserRealm(routerAddr)

	wugnotAddr = consts.WUGNOT_ADDR

	gnsPath    = "gno.land/r/gnoswap/v1/gns"
	wugnotPath = "gno.land/r/demo/wugnot"

	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999

	poolPath = "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000"
)

func main() {
	println("[SCENARIO] 1. Initialize account and emission")
	initAccountAndEmission()
	println()

	println("[SCENARIO] 2. Create pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint wugnot gns position 01")
	mintPosition01()
	println()

	println("[SCENARIO] 4. Mint wugnot gns position 02")
	mintPosition02()
	println()

	println("[SCENARIO] 5. Stake position 01 and 02")
	stakePositions()
	println()

	println("[SCENARIO] 6. Check reward for both in-range positions")
	checkReward01()
	println()

	println("[SCENARIO] 7. Make position 01 out-range by swap")
	makePosition1OutRangeBySwap()
	println()

	println("[SCENARIO] 8. Check reward with position 01 out-range")
	checkReward02()
	println()

	println("[SCENARIO] 9. Make position 01 in-range by swap")
	makePosition1InRangeBySwap()
	println()

	println("[SCENARIO] 10. Check reward with both positions in-range")
	checkReward03()
}

func initAccountAndEmission() {
	println("[INFO] send coins to admin")
	testing.SetRealm(adminRealm)
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 100_000_000_000_000}})

	testing.SetRealm(adminRealm)
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminAddr, wugnotAddr, std.Coins{{"ugnot", 50_000_000_000_000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 50_000_000_000_000}})

	println("[INFO] wrap gnot to wugnot")
	wugnot.Deposit(cross)
	testing.SetOriginSend(nil)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
	emission.RegisterGnsChangeCallback(cross)
}

func createPool() {
	println("[INFO] set pool creation fee to 0")
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] create pool gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000 at tick 0")
	pl.CreatePool(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(), // 79228162514264337593543950337
	)
}

func mintPosition01() {
	testing.SetRealm(adminRealm)

	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position 01 (tick range: -60 ~ 60, requested amount: 50, 50)")
	pn.Mint(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		int32(-60),
		int32(60),
		"50",
		"50",
		"1",
		"1",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)
}

func mintPosition02() {
	testing.SetRealm(adminRealm)

	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position 02 (tick range: -1020 ~ 1020, requested amount: 500000, 500000)")
	pn.Mint(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		int32(-1020),
		int32(1020),
		"500000",
		"500000",
		"1",
		"1",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)
}

func stakePositions() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve and stake position 01 and 02")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))

	testing.SkipHeights(1)
	sr.StakeToken(cross, 1, "")
	sr.StakeToken(cross, 2, "")
}

func checkReward01() {
	testing.SkipHeights(1)
	testing.SetRealm(adminRealm)

	println("[INFO] check reward for position 01 (both positions in-range)")
	collectRewardOf1BlockByPositionId(1)
}

func makePosition1OutRangeBySwap() {
	testing.SetRealm(adminRealm)

	println("[INFO] make position 01 out-range by swap")
	poolTick := pl.PoolGetSlot0Tick(poolPath)

	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)
	wugnot.Approve(cross, routerAddr, consts.INT64_MAX)
	gns.Approve(cross, routerAddr, consts.INT64_MAX)

	// swap to move price outside position 01's range
	testing.SetRealm(routerRealm)
	pl.Swap(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		adminAddr,
		true,         // zeroForOne
		"1000",       // amountSpecified
		"4295128740", // sqrtPriceLimitX96
		adminAddr,
	)

	newPoolTick := pl.PoolGetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] pool tick changed from %d to %d\n", poolTick, newPoolTick)

	println("[EXPECTED] position 01 moved out of range")
}

func checkReward02() {
	testing.SkipHeights(1)
	testing.SetRealm(adminRealm)

	println("[INFO] check reward for position 01 (position 01 out-range)")
	collectRewardOf1BlockByPositionId(1)
}

func makePosition1InRangeBySwap() {
	testing.SetRealm(adminRealm)

	println("[INFO] make position 01 in-range by swap")
	poolTick := pl.PoolGetSlot0Tick(poolPath)

	gns.Approve(cross, poolAddr, consts.INT64_MAX)
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)

	gns.Approve(cross, routerAddr, consts.INT64_MAX)
	wugnot.Approve(cross, routerAddr, consts.INT64_MAX)

	// swap to move price back inside position 01's range
	testing.SetRealm(routerRealm)
	pl.Swap(
		cross,
		gnsPath,
		wugnotPath,
		fee3000,
		adminAddr,
		false,  // zeroForOne
		"1000", // amountSpecified
		"1461446703485210103287273052203988822378723970340", // sqrtPriceLimitX96
		adminAddr,
	)

	newPoolTick := pl.PoolGetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] pool tick changed from %d to %d\n", poolTick, newPoolTick)

	println("[EXPECTED] position 01 moved back in range")
}

func checkReward03() {
	testing.SetRealm(adminRealm)

	println("[INFO] check reward for position 01 (both positions in-range again)")
	collectRewardOf1BlockByPositionId(1)
}

func collectRewardOf1BlockByPositionId(positionId uint64) {
	testing.SetRealm(adminRealm)
	sr.CollectReward(cross, positionId, false)
	beforeGns := gns.BalanceOf(adminUser)

	testing.SkipHeights(1)
	sr.CollectReward(cross, positionId, false)
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position %d of 1 block reward (height: %d): %d\n", positionId, std.ChainHeight(), diff)
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
// [SCENARIO] 1. Initialize account and emission
// [INFO] send coins to admin
// [INFO] wrap gnot to wugnot
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create pool
// [INFO] set pool creation fee to 0
// [INFO] create pool gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000 at tick 0
//
// [SCENARIO] 3. Mint wugnot gns position 01
// [INFO] mint in-range position 01 (tick range: -60 ~ 60, requested amount: 50, 50)
//
// [SCENARIO] 4. Mint wugnot gns position 02
// [INFO] mint in-range position 02 (tick range: -1020 ~ 1020, requested amount: 500000, 500000)
//
// [SCENARIO] 5. Stake position 01 and 02
// [INFO] approve and stake position 01 and 02
//
// [SCENARIO] 6. Check reward for both in-range positions
// [INFO] check reward for position 01 (both positions in-range)
// [EXPECTED] position 1 of 1 block reward (height: 126): 5267
//
// [SCENARIO] 7. Make position 01 out-range by swap
// [INFO] make position 01 out-range by swap
// [INFO] pool tick changed from 0 to -2
// [EXPECTED] position 01 moved out of range
//
// [SCENARIO] 8. Check reward with position 01 out-range
// [INFO] check reward for position 01 (position 01 out-range)
// [EXPECTED] position 1 of 1 block reward (height: 128): 5267
//
// [SCENARIO] 9. Make position 01 in-range by swap
// [INFO] make position 01 in-range by swap
// [INFO] pool tick changed from -2 to 0
// [EXPECTED] position 01 moved back in range
//
// [SCENARIO] 10. Check reward with both positions in-range
// [INFO] check reward for position 01 (both positions in-range again)
// [EXPECTED] position 1 of 1 block reward (height: 129): 5267
