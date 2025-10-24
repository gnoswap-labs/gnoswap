// position reward should be halved when average block time (2000ms to 4000ms)

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"chain/banker"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoland/wugnot"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	prabc "gno.land/p/gnoswap/rbac"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/v1/staker"

	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/rbac"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	wugnotAddr address = "g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"

	gnsPath    = "gno.land/r/gnoswap/gns"
	wugnotPath = "gno.land/r/gnoland/wugnot"

	fee3000 uint32 = 3000

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	poolPath = "gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000"
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

	println("[SCENARIO] 5. Collect reward for 1 blocks")
	collectRewardWithSkippingBlocks(1, 1)
	println()

	println("[SCENARIO] 6. Collect reward for 1 blocks")
	collectRewardWithSkippingBlocks(1, 1)
}

func initAccountAndEmission() {
	println("[INFO] send coins to admin")
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 100_000_000_000_000}})

	testing.SetRealm(adminRealm)
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(adminAddr, wugnotAddr, chain.Coins{{"ugnot", 50_000_000_000_000}})
	testing.SetOriginSend(chain.Coins{{"ugnot", 50_000_000_000_000}})

	println("[INFO] wrap gnot to wugnot")
	wugnot.Deposit(cross)
	testing.SetOriginSend(nil)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPool() {
	// set unstaking fee to 0
	println("[INFO] set unstaking fee to 0")
	testing.SetRealm(adminRealm)
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] set pool creation fee to 0")
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] create pool gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000 at tick 0")
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

	wugnot.Approve(cross, poolAddr, maxInt64)
	gns.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint in-range position (tick range: -60 ~ 60, requested amount: 50, 50)")
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
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)
}

func stakePosition() {
	testing.SetRealm(adminRealm)
	testing.SkipHeights(1)

	// stake
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	before := gns.BalanceOf(adminUser)

	testing.SkipHeights(100)
	sr.CollectReward(cross, 1, false)

	after := gns.BalanceOf(adminUser)

	diff := after - before
	ufmt.Println("[INFO] balance changes by 100 blocks", diff)
}

func collectRewardWithSkippingBlocks(positionId uint64, blocks int64) {
	testing.SetRealm(adminRealm)

	before := gns.BalanceOf(adminUser)
	testing.SkipHeights(blocks)

	sr.CollectReward(cross, positionId, false)
	after := gns.BalanceOf(adminUser)
	diff := after - before

	ufmt.Printf("[EXPECTED] position %d's reward for %d blocks: %d\n", positionId, blocks, diff)
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
// [INFO] create pool gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000 at tick 0
//
// [SCENARIO] 3. Mint wugnot gns position 01
// [INFO] mint in-range position (tick range: -60 ~ 60, requested amount: 50, 50)
//
// [SCENARIO] 4. Stake position 01
// [INFO] balance changes by 100 blocks 802654049
//
// [SCENARIO] 5. Collect reward for 1 blocks
// [EXPECTED] position 1's reward for 1 blocks: 8026540
//
// [SCENARIO] 6. Collect reward for 1 blocks
// [EXPECTED] position 1's reward for 1 blocks: 8026540
