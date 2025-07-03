// pool add to tier2 and change to tier3 internal incentive

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/testutils"
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

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	// g1v4u8getjdeskcsmjv4shgmmjta047h6lua7mup
	externalCreatorAddr  = testutils.TestAddress("externalCreator")
	externalCreatorUser  = externalCreatorAddr
	externalCreatorRealm = std.NewUserRealm(externalCreatorAddr)

	stakerAddr, _ = access.GetAddress(access.ROLE_STAKER)
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	wugnotAddr = consts.WUGNOT_ADDR

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	gnsPath    = "gno.land/r/gnoswap/v1/gns"
	wugnotPath = "gno.land/r/demo/wugnot"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS  int64 = 90 * 24 * 60 * 60
	TIMESTAMP_180DAYS int64 = 180 * 24 * 60 * 60
	TIMESTAMP_365DAYS int64 = 365 * 24 * 60 * 60

	poolPath1 = "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000"
	poolPath2 = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
)

func main() {
	println("[SCENARIO] 1. Initialize account and emission")
	initAccountAndEmission()
	println()

	println("[SCENARIO] 2. Create wugnot:gns:3000 and bar:baz:100 pools")
	createPools()
	println()

	println("[SCENARIO] 3. Mint and stake wugnot:gns:3000 position 01")
	mintAndStakePosition01()
	println()

	println("[SCENARIO] 4. Set bar:baz:100 pool's tier to 2")
	setPoolTier2()
	println()

	println("[SCENARIO] 5. Mint and stake bar:baz:100 position 02")
	mintAndStakePosition02()
	println()

	println("[SCENARIO] 6. Change bar:baz:100 pool's tier to 3")
	changePoolTier3()
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

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
	emission.RegisterGnsChangeCallback(cross)
}

func createPools() {
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

	println("[INFO] create pool gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 at tick 0")
	pl.CreatePool(
		cross,
		barPath,
		bazPath,
		fee100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(), // 79228162514264337593543950337
	)
}

func mintAndStakePosition01() {
	testing.SetRealm(adminRealm)

	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position 01 (tick range: -60 ~ 60, requested amount: 5000000, 5000000)")
	pn.Mint(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		int32(-60),
		int32(60),
		"5000000",
		"5000000",
		"1",
		"1",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	testing.SkipHeights(1)

	ufmt.Printf("[INFO] stake position 01 (height: %d)\n", std.ChainHeight())
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	sr.CollectReward(cross, 1, false)
	beforeGns := gns.BalanceOf(adminUser)

	testing.SkipHeights(1)
	// check reward for position 01 (gnot:gns:3000 tier 01)
	testing.SetRealm(adminRealm)

	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 01 tier1 of 1 block reward (height: %d): %d\n", std.ChainHeight(), diff)
}

func setPoolTier2() {
	testing.SetRealm(adminRealm)

	println("[INFO] set pool bar:baz:100 to tier 2")
	testing.SkipHeights(1)
	sr.SetPoolTierByAdmin(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100", 2)
}

func mintAndStakePosition02() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position 02 (tick range: -50 ~ 50, requested amount: 5000000, 5000000)")
	pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-50),
		int32(50),
		"5000000",
		"5000000",
		"1",
		"1",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	testing.SkipHeights(1)

	ufmt.Printf("[INFO] stake position 02 (height: %d)\n", std.ChainHeight())
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")

	sr.CollectReward(cross, 2, false)
	beforeGns := gns.BalanceOf(adminUser)

	testing.SkipHeights(1)
	// check reward for position 02 (bar:baz:100 tier 02)
	testing.SetRealm(adminRealm)
	sr.CollectReward(cross, 2, false)
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 02 tier2 of 1 block reward (height: %d): %d\n", std.ChainHeight(), diff)
}

func changePoolTier3() {
	testing.SetRealm(adminRealm)

	testing.SkipHeights(1)
	ufmt.Printf("[INFO] change pool bar:baz:100 to tier 3 (height: %d)\n", std.ChainHeight())
	sr.SetPoolTierByAdmin(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100", 3)

	sr.CollectReward(cross, 2, false)
	beforeGns := gns.BalanceOf(adminUser)

	testing.SkipHeights(1)
	// check reward for position 02 (bar:baz:100 tier 03)
	testing.SetRealm(adminRealm)
	sr.CollectReward(cross, 2, false)
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 02 tier3 of 1 block reward (height: %d): %d\n", std.ChainHeight(), diff)
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
// [SCENARIO] 2. Create wugnot:gns:3000 and bar:baz:100 pools
// [INFO] set pool creation fee to 0
// [INFO] create pool gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000 at tick 0
// [INFO] create pool gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 at tick 0
//
// [SCENARIO] 3. Mint and stake wugnot:gns:3000 position 01
// [INFO] mint in-range position 01 (tick range: -60 ~ 60, requested amount: 5000000, 5000000)
// [INFO] stake position 01 (height: 124)
// [EXPECTED] position 01 tier1 of 1 block reward (height: 125): 3210615
//
// [SCENARIO] 4. Set bar:baz:100 pool's tier to 2
// [INFO] set pool bar:baz:100 to tier 2
//
// [SCENARIO] 5. Mint and stake bar:baz:100 position 02
// [INFO] mint in-range position 02 (tick range: -50 ~ 50, requested amount: 5000000, 5000000)
// [INFO] stake position 02 (height: 127)
// [EXPECTED] position 02 tier2 of 1 block reward (height: 128): 963184
//
// [SCENARIO] 6. Change bar:baz:100 pool's tier to 3
// [INFO] change pool bar:baz:100 to tier 3 (height: 129)
// [EXPECTED] position 02 tier3 of 1 block reward (height: 130): 642122
