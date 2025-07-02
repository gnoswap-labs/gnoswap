// staked liquidity change by staking/unstaking internal incentive scenario

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

	println("[SCENARIO] 5. Stake position 01")
	testing.SkipHeights(1)
	stakePosition(1)
	println()

	println("[SCENARIO] 6. Stake position 02")
	testing.SkipHeights(1)
	stakePosition(2)
	println()

	println("[SCENARIO] 7. Collect reward")
	collectReward(1)
	collectReward(2)
	println()

	println("[SCENARIO] 8. Unstake position")
	unstakePosition(1)
	unstakePosition(2)
	println()
}

func initAccountAndEmission() {
	println("[INFO] send coins to admin")
	testing.SetRealm(adminRealm)
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 100_000_000_000_000}})

	println("[INFO] wrap gnot to wugnot")
	testing.SetRealm(adminRealm)
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminAddr, wugnotAddr, std.Coins{{"ugnot", 50_000_000_000_000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 50_000_000_000_000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(nil)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
	emission.RegisterGnsChangeCallback(cross)
}

func createPool() {
	println("[INFO] set pool creation fee to 0")
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] create pool gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000 at tick 0")
	testing.SetRealm(adminRealm)
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminAddr, poolAddr, std.Coins{{"ugnot", 1000000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 1000000}})
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

	println("[INFO] mint in-range position 01 (tick range: -60 ~ 60, requested amount: 1000000, 1000000)")
	pn.Mint(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		int32(-60),
		int32(60),
		"1000000",
		"1000000",
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

	println("[INFO] mint in-range position 02 (tick range: -60 ~ 60, requested amount: 1000000, 1000000)")
	pn.Mint(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		int32(-60),
		int32(60),
		"1000000",
		"1000000",
		"1",
		"1",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)
}

func stakePosition(positionId uint64) {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position", positionId)
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross, positionId, "")
}

func unstakePosition(positionId uint64) {
	testing.SetRealm(adminRealm)
	sr.CollectReward(cross, positionId, false)
	beforeGns := gns.BalanceOf(adminUser)

	testing.SkipHeights(1)

	ufmt.Printf("[INFO] unstake position %d with collected reward\n", positionId)
	sr.UnStakeToken(cross, positionId, false)

	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position %d reward collected: GNS=%d\n", positionId, diff)
}

func collectReward(positionId uint64) {
	testing.SetRealm(adminRealm)

	sr.CollectReward(cross, positionId, false)

	println("[INFO] collect reward for position", positionId)
	oldGns := gns.BalanceOf(adminUser)

	testing.SkipHeights(1)

	sr.CollectReward(cross, positionId, false)

	newGns := gns.BalanceOf(adminUser)

	diffGns := newGns - oldGns

	ufmt.Printf("[EXPECTED] position %d reward collected: GNS=%d\n", positionId, diffGns)
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
// [INFO] set unstaking fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create pool
// [INFO] set pool creation fee to 0
// [INFO] create pool gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000 at tick 0
//
// [SCENARIO] 3. Mint wugnot gns position 01
// [INFO] mint in-range position 01 (tick range: -60 ~ 60, requested amount: 1000000, 1000000)
//
// [SCENARIO] 4. Mint wugnot gns position 02
// [INFO] mint in-range position 02 (tick range: -60 ~ 60, requested amount: 1000000, 1000000)
//
// [SCENARIO] 5. Stake position 01
// [INFO] stake position 1
//
// [SCENARIO] 6. Stake position 02
// [INFO] stake position 2
//
// [SCENARIO] 7. Collect reward
// [INFO] collect reward for position 1
// [EXPECTED] position 1 reward collected: GNS=1605307
// [INFO] collect reward for position 2
// [EXPECTED] position 2 reward collected: GNS=1605307
//
// [SCENARIO] 8. Unstake position
// [INFO] unstake position 1 with collected reward
// [EXPECTED] position 1 reward collected: GNS=1605307
// [INFO] unstake position 2 with collected reward
// [EXPECTED] position 2 reward collected: GNS=3210615
