// non existing position should not give reward to community pool

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

	poolAddr, _          = access.GetAddress(access.ROLE_POOL)
	communityPoolAddr, _ = access.GetAddress(access.ROLE_COMMUNITY_POOL)

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
	mintPosition()
	println()

	println("[SCENARIO] 4. Stake position 01")
	stakePosition()
	println()

	println("[SCENARIO] 5. Unstake position 01 and verify community pool reward")
	unstakePosition()
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

func mintPosition() {
	testing.SetRealm(adminRealm)

	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position (tick range: -60 ~ 60, requested amount: 50, 50)")
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

func stakePosition() {
	testing.SetRealm(adminRealm)

	// skip height 1 to make sure position 01 is not staked yet
	testing.SkipHeights(1)

	println("[INFO] stake position 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")
}

func unstakePosition() {
	testing.SetRealm(adminRealm)
	testing.SetOriginCaller(adminAddr)

	prevCommunityPoolGns := gns.BalanceOf(communityPoolAddr)
	ufmt.Printf("[INFO] community pool balance before unstake: %d\n", prevCommunityPoolGns)

	println("[INFO] unstake position 01")
	// this position-01 has been staked and staked same time
	sr.UnStakeToken(cross, 1, false)

	println("[INFO] skip height 1 and mint and distribute gns")
	testing.SkipHeights(1)
	emission.MintAndDistributeGns(cross)

	afterCommunityPoolGns := gns.BalanceOf(communityPoolAddr)
	ufmt.Printf("[INFO] community pool balance after unstake: %d\n", afterCommunityPoolGns)

	// therefore community pool should receive no-position-staked pool's reward
	increased := afterCommunityPoolGns - prevCommunityPoolGns
	ufmt.Printf("[EXPECTED] community pool reward increase: %d\n", increased)
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
// [INFO] mint in-range position (tick range: -60 ~ 60, requested amount: 50, 50)
//
// [SCENARIO] 4. Stake position 01
// [INFO] stake position 01
//
// [SCENARIO] 5. Unstake position 01 and verify community pool reward
// [INFO] community pool balance before unstake: 713470
// [INFO] unstake position 01
// [INFO] skip height 1 and mint and distribute gns
// [INFO] community pool balance after unstake: 1426940
// [EXPECTED] community pool reward increase: 713470
