// short warm-up period internal gnot:gns:3000 scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"math"
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

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	wugnotAddr = consts.WUGNOT_ADDR

	gnsPath    = "gno.land/r/gnoswap/v1/gns"
	wugnotPath = "gno.land/r/demo/wugnot"

	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999
)

func main() {
	println("[SCENARIO] 1. Initialize and setup short warm-up periods")
	initWithShortWarmUp()
	println()

	println("[SCENARIO] 2. Create wugnot:gns:3000 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint wugnot:gns position 01")
	mintWugnotGnsPos01()
	println()

	println("[SCENARIO] 4. Stake token 01")
	stakeToken01()
	println()

	println("[SCENARIO] 5. Collect reward")
	collectReward01()
}

func initWithShortWarmUp() {
	testing.SetRealm(adminRealm)

	println("[INFO] override warm-up periods for testing")
	sr.SetWarmUpByAdmin(cross, 30, 150)
	sr.SetWarmUpByAdmin(cross, 50, 300)
	sr.SetWarmUpByAdmin(cross, 70, 900)
	sr.SetWarmUpByAdmin(cross, 100, math.MaxInt64)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] set community pool distribution to 0%")
	emission.ChangeDistributionPctByAdmin(
		cross,
		1, 7500, // staker
		2, 2500, // devOps
		3, 0, // community pool
		4, 0, // xGNS
	)

	println("[INFO] prepare wugnot")
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 100_000_000_000_000}})
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminAddr, consts.WUGNOT_ADDR, std.Coins{{"ugnot", 50_000_000_000_000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 50_000_000_000_000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(nil)

	wugnotBalance := wugnot.BalanceOf(adminAddr)
	ufmt.Printf("[EXPECTED] wugnot balance: %d\n", wugnotBalance)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)

	testing.SkipHeights(1)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] create wugnot:gns:3000 pool at tick 0")
	pl.CreatePool(cross, wugnotPath, gnsPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SkipHeights(1)
	ufmt.Printf("[INFO] pool created, current height: %d\n", std.ChainHeight())
}

func mintWugnotGnsPos01() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint position 01 (tick range: -1020 ~ 1020)")
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		int32(-1020),
		int32(1020),
		"50",
		"50",
		"1",
		"1",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position ID: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s, amount1: %s\n", amount0, amount1)

	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	ufmt.Printf("[EXPECTED] position owner: %s\n", owner)

	testing.SkipHeights(1)
}

func stakeToken01() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve and stake token 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	testing.SkipHeights(1)
	ufmt.Printf("[INFO] token staked at height: %d\n", std.ChainHeight())
}

func collectReward01() {
	testing.SetRealm(adminRealm)

	communityPoolAddr, _ := access.GetAddress(prabc.ROLE_COMMUNITY_POOL.String())

	println("[INFO] check GNS balances before reward collection")
	gnsBefore := gns.BalanceOf(adminUser)
	communityPoolBefore := gns.BalanceOf(communityPoolAddr)

	ufmt.Printf("[INFO] user GNS balance before: %d\n", gnsBefore)
	ufmt.Printf("[INFO] community pool GNS balance before: %d\n", communityPoolBefore)

	println("[INFO] collect reward for position 01")
	sr.CollectReward(cross, 1, false)

	gnsAfter := gns.BalanceOf(adminUser)
	communityPoolAfter := gns.BalanceOf(communityPoolAddr)

	userReward := gnsAfter - gnsBefore
	communityReward := communityPoolAfter - communityPoolBefore

	ufmt.Printf("[EXPECTED] user reward: %d\n", userReward)
	ufmt.Printf("[EXPECTED] community pool reward: %d\n", communityReward)

	// Expected: position receives 30% warm-up reward, 70% goes to community pool as penalty
	// staker's emission reward per block: 10702054
	// user should get ~3210616 (30%), community pool should get unclaimable rewards + penalty

	testing.SkipHeights(1)
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
// [SCENARIO] 1. Initialize and setup short warm-up periods
// [INFO] override warm-up periods for testing
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] set community pool distribution to 0%
// [INFO] prepare wugnot
// [EXPECTED] wugnot balance: 50000000000000
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create wugnot:gns:3000 pool
// [INFO] create wugnot:gns:3000 pool at tick 0
// [INFO] pool created, current height: 125
//
// [SCENARIO] 3. Mint wugnot:gns position 01
// [INFO] approve tokens for minting
// [INFO] mint position 01 (tick range: -1020 ~ 1020)
// [EXPECTED] position ID: 1
// [EXPECTED] liquidity: 1005
// [EXPECTED] amount0: 50, amount1: 50
// [EXPECTED] position owner: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
//
// [SCENARIO] 4. Stake token 01
// [INFO] approve and stake token 01
// [INFO] token staked at height: 127
//
// [SCENARIO] 5. Collect reward
// [INFO] check GNS balances before reward collection
// [INFO] user GNS balance before: 99999999999950
// [INFO] community pool GNS balance before: 0
// [INFO] collect reward for position 01
// [EXPECTED] user reward: 3210615
// [EXPECTED] community pool reward: 28895546
