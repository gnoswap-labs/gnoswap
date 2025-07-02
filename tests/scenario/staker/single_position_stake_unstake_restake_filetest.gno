// single position stake -> unstake -> restake scenario

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

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

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

	println("[SCENARIO] 6. Unstake position 01")
	unstakePosition01()
	println()

	println("[SCENARIO] 7. Restake position 01")
	restakePosition01()
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
	// set unstaking fee to 0
	println("[INFO] set unstaking fee to 0")
	testing.SetRealm(adminRealm)
	sr.SetUnStakingFeeByAdmin(cross, 0)

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
	testing.SkipHeights(1)

	println("[INFO] approve and stake position 01 and 02")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))

	sr.StakeToken(cross, 1, "")
	sr.StakeToken(cross, 2, "")
}

func unstakePosition01() {
	testing.SetRealm(adminRealm)
	testing.SkipHeights(1)

	println("[INFO] unstake position 01")
	beforeGns := gns.BalanceOf(adminUser)
	sr.UnStakeToken(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 01 reward from unstake: %d\n", diff)
}

func restakePosition01() {
	testing.SetRealm(adminRealm)
	testing.SkipHeights(1)

	println("[INFO] restake position 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	// reward check for staked > unstaked > staked position
	testing.SkipHeights(1)
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 01 reward after restake: %d\n", diff)
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
// [INFO] set unstaking fee to 0
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
// [SCENARIO] 6. Unstake position 01
// [INFO] unstake position 01
// [EXPECTED] position 01 reward from unstake: 5320
//
// [SCENARIO] 7. Restake position 01
// [INFO] restake position 01
// [EXPECTED] position 01 reward after restake: 5320
