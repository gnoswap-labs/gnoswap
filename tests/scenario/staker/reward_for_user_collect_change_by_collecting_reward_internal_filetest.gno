// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. gnot:gns:3000

// POSITIONs:
// 1. in-range
// 2. in-range (will be unstaked)

// REWARDs:
// - internal tier 1 ( gnot:gns:3000 )

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/demo/wugnot"

	"gno.land/r/gnoswap/v1/access"

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
	poolAddr, _   = access.GetAddress(access.ROLE_POOL)

	wugnotAddr = consts.WUGNOT_ADDR

	gnsPath    = "gno.land/r/gnoswap/v1/gns"
	wugnotPath = "gno.land/r/demo/wugnot"

	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999
)

func main() {
	println("[SCENARIO] 1. Initialize account and warm-up periods")
	initAccountAndWarmUp()
	println()

	println("[SCENARIO] 2. Create wugnot:gns:3000 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint and stake wugnot:gns:3000 position 01")
	mintAndStakePosition01()
	println()

	println("[SCENARIO] 4. Mint and stake wugnot:gns:3000 position 02")
	mintAndStakePosition02()
	println()

	println("[SCENARIO] 5. Collect reward for position 01")
	collectReward(1)
}

func initAccountAndWarmUp() {
	println("[INFO] send coins to admin")
	testing.SetRealm(adminRealm)
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 100_000_000_000_000}})

	println("[INFO] prepare wugnot")
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminAddr, wugnotAddr, std.Coins{{"ugnot", 50_000_000_000_000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 50_000_000_000_000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(nil)

	println("[INFO] set short warm-up periods")
	sr.SetWarmUp(cross, 100, 901)
	sr.SetWarmUp(cross, 70, 301)
	sr.SetWarmUp(cross, 50, 151)
	sr.SetWarmUp(cross, 30, 1)
}

func createPool() {
	println("[INFO] set pool creation fee to 0")
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] create pool gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000 at tick 0")
	testing.SkipHeights(1)
	pl.CreatePool(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(), // 79228162514264337593543950337
	)
}

func mintAndStakePosition01() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for position 01")
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position 01 (tick range: -60 ~ 60, requested amount: 100, 100)")
	testing.SkipHeights(1)
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
	ufmt.Print("[INFO] stake position 01 (height: ", std.ChainHeight(), ")\n")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")
}

func mintAndStakePosition02() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for position 02")
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position 02 (tick range: -60 ~ 60, requested amount: 100, 100)")
	testing.SkipHeights(1)
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
	ufmt.Print("[INFO] stake position 02 (height: ", std.ChainHeight(), ")\n")
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")
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

func extractReward(positionId uint64) uint64 {
	apiReward := sr.ApiGetRewardsByLpTokenId(positionId)
	rawReward, _ := json.Unmarshal([]byte(apiReward))
	rawRewardObject, _ := rawReward.GetKey("response")
	arrReward, _ := rawRewardObject.GetArray()

	reward, _ := arrReward[0].GetKey("rewards")
	rewardArr, _ := reward.GetArray()
	if len(rewardArr) == 0 {
		return 0
	}
	rewardTokenAmount, _ := rewardArr[0].GetKey("rewardTokenAmount")

	rewardTokenAmountInt, _ := strconv.ParseUint(rewardTokenAmount.String(), 10, 64)
	return rewardTokenAmountInt
}

// Output:
// [SCENARIO] 1. Initialize account and warm-up periods
// [INFO] send coins to admin
// [INFO] prepare wugnot
// [INFO] set short warm-up periods
//
// [SCENARIO] 2. Create wugnot:gns:3000 pool
// [INFO] set pool creation fee to 0
// [INFO] create pool gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000 at tick 0
//
// [SCENARIO] 3. Mint and stake wugnot:gns:3000 position 01
// [INFO] approve tokens for position 01
// [INFO] mint in-range position 01 (tick range: -60 ~ 60, requested amount: 100, 100)
// [INFO] stake position 01 (height:  126 )
//
// [SCENARIO] 4. Mint and stake wugnot:gns:3000 position 02
// [INFO] approve tokens for position 02
// [INFO] mint in-range position 02 (tick range: -60 ~ 60, requested amount: 100, 100)
// [INFO] stake position 02 (height:  128 )
//
// [SCENARIO] 5. Collect reward for position 01
// [INFO] collect reward for position 1
// [EXPECTED] position 1 reward collected: GNS=2648758
