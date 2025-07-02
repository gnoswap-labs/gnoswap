// pool add to tier2 and removed internal incentive

// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. gnot:gns:3000
// 2. bar:baz:100

// POSITIONs:
// 1. in-range ( gnot:gns:3000 )
// 2. in-range ( bar:baz:100 )

// REWARDs:
// - internal tier 1 ( gnot:gns:3000 )
// - internal tier 2 ( bar:baz:100 ) -> will be removed from internal tiers

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

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
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

	println("[SCENARIO] 4. Set bar:baz:100 pool to tier 2")
	setPoolTier2()
	println()

	println("[SCENARIO] 5. Mint and stake bar baz position 02")
	mintAndStakePosition02()
	println()

	println("[SCENARIO] 6. Remove bar:baz:100 pool from internal tiers")
	removePoolTier()
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

	println("[INFO] mint in-range position 01 (tick range: -60 ~ 60, requested amount: 100, 100)")
	pn.Mint(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		int32(-60),
		int32(60),
		"100",
		"100",
		"0",
		"0",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	testing.SkipHeights(1)

	ufmt.Printf("[INFO] stake position 01 (height: %d)\n", std.ChainHeight())
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	// check reward for position 01 (gnot:gns:3000 tier 01)
	testing.SetRealm(adminRealm)
	testing.SkipHeights(1)

	collectRewardOf1BlockByPositionId(1)
}

func setPoolTier2() {
	testing.SetRealm(adminRealm)

	ufmt.Printf("[INFO] set pool bar:baz:100 to tier 2 (height: %d)\n", std.ChainHeight())
	sr.SetPoolTierByAdmin(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100", 2)
}

func mintAndStakePosition02() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position 02 (tick range: -50 ~ 50, requested amount: 100, 100)")
	pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-50),
		int32(50),
		"100",
		"100",
		"0",
		"0",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	testing.SkipHeights(1)

	ufmt.Printf("[INFO] stake position 02 (height: %d)\n", std.ChainHeight())
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")
	testing.SkipHeights(1)

	collectRewardOf1BlockByPositionId(1)
	collectRewardOf1BlockByPositionId(2)
}

func removePoolTier() {
	testing.SetRealm(adminRealm)

	println("[INFO] remove pool bar:baz:100 from internal tiers")
	testing.SkipHeights(1)
	sr.RemovePoolTierByAdmin(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100")

	testing.SkipHeights(1)
	// check reward for position 01 (gnot:gns:3000 tier 01) - should be back to 100%
	collectRewardOf1BlockByPositionId(1)

	// check reward for position 02 (bar:baz:100) - should be 0 as removed from internal tiers
	collectRewardOf1BlockByPositionId(2)
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
// [INFO] set unstaking fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create wugnot:gns:3000 and bar:baz:100 pools
// [INFO] set pool creation fee to 0
// [INFO] create pool gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000 at tick 0
// [INFO] create pool gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100 at tick 0
//
// [SCENARIO] 3. Mint and stake wugnot:gns:3000 position 01
// [INFO] mint in-range position 01 (tick range: -60 ~ 60, requested amount: 100, 100)
// [INFO] stake position 01 (height: 124)
// [EXPECTED] position 1 of 1 block reward (height: 126): 3210615
//
// [SCENARIO] 4. Set bar:baz:100 pool to tier 2
// [INFO] set pool bar:baz:100 to tier 2 (height: 126)
//
// [SCENARIO] 5. Mint and stake bar baz position 02
// [INFO] mint in-range position 02 (tick range: -50 ~ 50, requested amount: 100, 100)
// [INFO] stake position 02 (height: 127)
// [EXPECTED] position 1 of 1 block reward (height: 129): 2247430
// [EXPECTED] position 2 of 1 block reward (height: 130): 963184
//
// [SCENARIO] 6. Remove bar:baz:100 pool from internal tiers
// [INFO] remove pool bar:baz:100 from internal tiers
// [EXPECTED] position 1 of 1 block reward (height: 133): 3210615
// [EXPECTED] position 2 of 1 block reward (height: 134): 0
