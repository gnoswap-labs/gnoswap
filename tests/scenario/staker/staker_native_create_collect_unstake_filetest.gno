// staker native token create, collect, and unstake scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"fmt"
	"math"
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

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
	stakerRealm   = std.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _     = access.GetAddress(prabc.ROLE_POOL.String())
	positionAddr, _ = access.GetAddress(prabc.ROLE_POSITION.String())

	wugnotAddr std.Address = "g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6"

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	gnsPath    = "gno.land/r/gnoswap/v1/gns"
	wugnotPath = "gno.land/r/demo/wugnot"

	fee500 uint32 = 500

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60
)

func main() {
	println("[SCENARIO] 1. Initialize with short warm-up periods")
	initWithShortWarmUp()
	println()

	println("[SCENARIO] 2. Create pools")
	createPools()
	println()

	println("[SCENARIO] 3. Mint native position 01")
	mintNativePosition01()
	println()

	println("[SCENARIO] 4. Mint native position 02")
	mintNativePosition02()
	println()

	println("[SCENARIO] 5. Create external incentive with native coin")
	createExternalIncentiveNative()
	println()

	println("[SCENARIO] 6. Stake token 01")
	stakeToken01()
	println()

	println("[SCENARIO] 7. Stake token 02")
	stakeToken02()
	println()

	println("[SCENARIO] 8. Collect reward for token 01")
	collectReward01()
	println()

	println("[SCENARIO] 9. Unstake token 02")
	unstakeToken02()
	println()

	println("[SCENARIO] 10. End external incentive")
	endExternalIncentive()
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
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] set community pool distribution to 0%")
	emission.ChangeDistributionPctByAdmin(
		cross,
		1, 7500, // staker
		2, 2500, // devOps
		3, 0, // community pool
		4, 0, // xGNS
	)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPools() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve gns for pool creation")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
	testing.SkipHeights(1)

	println("[INFO] create bar:foo:500 pool")
	pl.CreatePool(cross, barPath, fooPath, 500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	println("[INFO] create wugnot:gns:500 pool")
	pl.CreatePool(
		cross,
		"gno.land/r/demo/wugnot",
		"gno.land/r/gnoswap/v1/gns",
		500,
		common.TickMathGetSqrtRatioAtTick(-10000).ToString(),
	)

	println("[INFO] set pool tiers")
	sr.SetPoolTierByAdmin(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", 1)
	sr.SetPoolTierByAdmin(cross, "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:500", 2)

	testing.SkipHeights(18)
}

func mintNativePosition01() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for native minting")
	gns.Approve(cross, poolAddr, maxInt64)
	wugnot.Approve(cross, poolAddr, maxInt64)
	wugnot.Approve(cross, positionAddr, maxInt64)
	testing.SkipHeights(3)

	println("[INFO] prepare 50000005 ugnot (5 for refund test)")
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 50000005}})

	ugnotBalanceBefore := ugnotBalanceOf(adminAddr)
	positionUgnotBalanceBefore := ugnotBalanceOf(positionAddr)

	ufmt.Printf("[INFO] admin ugnot balance before: %d\n", ugnotBalanceBefore)
	ufmt.Printf("[INFO] position contract ugnot balance before: %d\n", positionUgnotBalanceBefore)

	println("[INFO] send ugnot to position contract and set origin send")
	banker := std.NewBanker(std.BankerTypeRealmIssue)
	banker.SendCoins(adminAddr, positionAddr, std.Coins{{"ugnot", 50000005}})
	testing.SetOriginSend(std.Coins{{"ugnot", 50000005}})

	ugnotBalanceAfterSend := ugnotBalanceOf(adminAddr)
	positionUgnotBalanceAfterSend := ugnotBalanceOf(positionAddr)

	ufmt.Printf("[INFO] admin ugnot balance after send: %d\n", ugnotBalanceAfterSend)
	ufmt.Printf("[INFO] position contract ugnot balance after send: %d\n", positionUgnotBalanceAfterSend)

	adminOldWugnotBalance := wugnot.BalanceOf(adminUser)
	ufmt.Printf("[INFO] admin wugnot balance before mint: %d\n", adminOldWugnotBalance)

	println("[INFO] mint native position 01 (gns:gnot)")
	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		"gno.land/r/gnoswap/v1/gns",
		"gnot",
		fee500,
		int32(9000),
		int32(11000),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 01 - ID: %d\n", lpTokenId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s, amount1: %s\n", amount0, amount1)

	owner := gnft.MustOwnerOf(positionIdFrom(lpTokenId))
	ufmt.Printf("[EXPECTED] position owner: %s\n", owner)

	testing.SkipHeights(1)
}

func mintNativePosition02() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for second native minting")
	gns.Approve(cross, poolAddr, maxInt64)
	wugnot.Approve(cross, poolAddr, maxInt64)
	wugnot.Approve(cross, positionAddr, maxInt64)
	testing.SkipHeights(3)

	println("[INFO] prepare another 50000005 ugnot")
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 50000005}})

	ugnotBalanceBefore := ugnotBalanceOf(adminAddr)
	ufmt.Printf("[INFO] admin ugnot balance before second mint: %d\n", ugnotBalanceBefore)

	println("[INFO] send ugnot to position contract for second mint")
	banker := std.NewBanker(std.BankerTypeRealmIssue)
	banker.SendCoins(adminAddr, positionAddr, std.Coins{{"ugnot", 50000005}})
	testing.SetOriginSend(std.Coins{{"ugnot", 50000005}})

	adminOldWugnotBalance := wugnot.BalanceOf(adminUser)
	ufmt.Printf("[INFO] admin wugnot balance before second mint: %d\n", adminOldWugnotBalance)

	println("[INFO] mint native position 02 (gns:gnot)")
	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		"gno.land/r/gnoswap/v1/gns",
		"gnot",
		fee500,
		int32(9000),
		int32(11000),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 02 - ID: %d\n", lpTokenId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s, amount1: %s\n", amount0, amount1)

	owner := gnft.MustOwnerOf(positionIdFrom(lpTokenId))
	ufmt.Printf("[EXPECTED] position owner: %s\n", owner)

	testing.SkipHeights(1)
}

func createExternalIncentiveNative() {
	testing.SetRealm(adminRealm)

	println("[INFO] prepare 10_000_000_000 ugnot for external incentive")
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 10_000_000_000}})

	println("[INFO] add token and approve gns")
	sr.AddToken(cross, "gno.land/r/onbloc/obl")
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive with native coin")

	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 10_000_000_000}})
	banker := std.NewBanker(std.BankerTypeRealmIssue)
	banker.SendCoins(adminAddr, stakerAddr, std.Coins{{"ugnot", 10_000_000_000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 10_000_000_000}})
	wugnot.Approve(cross, stakerAddr, maxInt64)

	incentiveID := fmt.Sprintf("%s:%d:%d", adminAddr, std.ChainHeight(), 1)
	println("[INFO] create external incentive with incentiveID: ", incentiveID)

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:500", // targetPoolPath
		"gnot",                      // rewardToken (native)
		10_000_000_000,              // rewardAmount
		1234569600,                  // startTimestamp
		1234569600+TIMESTAMP_90DAYS, // endTimestamp
	)

	ufmt.Printf("[INFO] external incentive created - start: %d, end: %d\n", 1234569600, 1234569600+TIMESTAMP_90DAYS)

	adminNewWugnotBalance := wugnot.BalanceOf(adminUser)
	ufmt.Printf("[EXPECTED] admin wugnot balance after external incentive: %d\n", adminNewWugnotBalance)

	testing.SkipHeights(1)
}

func stakeToken01() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker for token 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	testing.SkipHeights(1)

	println("[INFO] stake token 01")
	sr.StakeToken(cross, 1, "")

	testing.SkipHeights(1)

	owner := gnft.MustOwnerOf(positionIdFrom(1))
	ufmt.Printf("[EXPECTED] NFT owner after staking: %s\n", owner)
}

func stakeToken02() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker for token 02")
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	testing.SkipHeights(1)

	println("[INFO] stake token 02")
	sr.StakeToken(cross, 2, "")

	testing.SkipHeights(1)

	owner := gnft.MustOwnerOf(positionIdFrom(2))
	ufmt.Printf("[EXPECTED] NFT owner after staking: %s\n", owner)
}

func collectReward01() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate rewards")
	testing.SkipHeights(1000)

	wugnotBalanceBefore := wugnot.BalanceOf(adminUser)
	ugnotBalanceBefore := ugnotBalanceOf(adminAddr)

	ufmt.Printf("[INFO] wugnot balance before collect: %d\n", wugnotBalanceBefore)
	ufmt.Printf("[INFO] ugnot balance before collect: %d\n", ugnotBalanceBefore)

	println("[INFO] collect reward for token 01 (no unwrap)")
	sr.CollectReward(cross, 1, false)

	testing.SkipHeights(1)

	wugnotBalanceAfter := wugnot.BalanceOf(adminUser)
	ugnotBalanceAfter := ugnotBalanceOf(adminAddr)

	wugnotIncrease := wugnotBalanceAfter - wugnotBalanceBefore
	ugnotChange := ugnotBalanceAfter - ugnotBalanceBefore

	ufmt.Printf("[EXPECTED] wugnot balance after collect: %d\n", wugnotBalanceAfter)
	ufmt.Printf("[EXPECTED] ugnot balance after collect: %d\n", ugnotBalanceAfter)
	ufmt.Printf("[EXPECTED] wugnot increase: %d\n", wugnotIncrease)
	ufmt.Printf("[EXPECTED] ugnot change: %d\n", ugnotChange)
}

func unstakeToken02() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip more blocks")
	testing.SkipHeights(335)

	wugnotBalanceBefore := wugnot.BalanceOf(adminUser)
	ugnotBalanceBefore := ugnotBalanceOf(adminAddr)

	ufmt.Printf("[INFO] wugnot balance before unstake: %d\n", wugnotBalanceBefore)
	ufmt.Printf("[INFO] ugnot balance before unstake: %d\n", ugnotBalanceBefore)

	println("[INFO] unstake token 02 (no unwrap)")
	sr.UnStakeToken(cross, 2, false)
	testing.SkipHeights(1)

	owner := gnft.MustOwnerOf(positionIdFrom(2))
	ufmt.Printf("[EXPECTED] NFT owner after unstaking: %s\n", owner)

	wugnotBalanceAfter := wugnot.BalanceOf(adminUser)
	ugnotBalanceAfter := ugnotBalanceOf(adminAddr)

	wugnotIncrease := wugnotBalanceAfter - wugnotBalanceBefore
	ugnotChange := ugnotBalanceAfter - ugnotBalanceBefore

	ufmt.Printf("[EXPECTED] wugnot balance after unstake: %d\n", wugnotBalanceAfter)
	ufmt.Printf("[EXPECTED] ugnot balance after unstake: %d\n", ugnotBalanceAfter)
	ufmt.Printf("[EXPECTED] wugnot increase from unstake: %d\n", wugnotIncrease)
	ufmt.Printf("[EXPECTED] ugnot change from unstake: %d\n", ugnotChange)
}

func endExternalIncentive() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve wugnot for unwrapping")
	wugnot.Approve(cross, stakerAddr, maxInt64)

	wugnotBalanceBefore := wugnot.BalanceOf(adminUser)
	ugnotBalanceBefore := ugnotBalanceOf(adminAddr)

	ufmt.Printf("[INFO] wugnot balance before end: %d\n", wugnotBalanceBefore)
	ufmt.Printf("[INFO] ugnot balance before end: %d\n", ugnotBalanceBefore)

	println("[INFO] skip to end of external incentive")
	testing.SkipHeights(9999999)

	println("[INFO] end external incentive")
	incentiveID := "g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d:150:1"
	sr.EndExternalIncentive(
		cross,
		"gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:500",
		incentiveID,
	)
	testing.SkipHeights(1)

	wugnotBalanceAfter := wugnot.BalanceOf(adminUser)
	ugnotBalanceAfter := ugnotBalanceOf(adminAddr)

	wugnotChange := wugnotBalanceAfter - wugnotBalanceBefore
	ugnotIncrease := ugnotBalanceAfter - ugnotBalanceBefore

	ufmt.Printf("[EXPECTED] wugnot balance after end: %d\n", wugnotBalanceAfter)
	ufmt.Printf("[EXPECTED] ugnot balance after end: %d\n", ugnotBalanceAfter)
	ufmt.Printf("[EXPECTED] wugnot change: %d\n", wugnotChange)
	ufmt.Printf("[EXPECTED] ugnot refund: %d\n", ugnotIncrease)
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
// [SCENARIO] 1. Initialize with short warm-up periods
// [INFO] override warm-up periods for testing
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] set community pool distribution to 0%
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create pools
// [INFO] approve gns for pool creation
// [INFO] create bar:foo:500 pool
// [INFO] create wugnot:gns:500 pool
// [INFO] set pool tiers
//
// [SCENARIO] 3. Mint native position 01
// [INFO] approve tokens for native minting
// [INFO] prepare 50000005 ugnot (5 for refund test)
// [INFO] admin ugnot balance before: 50000005
// [INFO] position contract ugnot balance before: 0
// [INFO] send ugnot to position contract and set origin send
// [INFO] admin ugnot balance after send: 0
// [INFO] position contract ugnot balance after send: 50000005
// [INFO] admin wugnot balance before mint: 0
// [INFO] mint native position 01 (gns:gnot)
// [EXPECTED] position 01 - ID: 1
// [EXPECTED] liquidity: 12437
// [EXPECTED] amount0: 1000, amount1: 368
// [EXPECTED] position owner: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
//
// [SCENARIO] 4. Mint native position 02
// [INFO] approve tokens for second native minting
// [INFO] prepare another 50000005 ugnot
// [INFO] admin ugnot balance before second mint: 99999010
// [INFO] send ugnot to position contract for second mint
// [INFO] admin wugnot balance before second mint: 0
// [INFO] mint native position 02 (gns:gnot)
// [EXPECTED] position 02 - ID: 2
// [EXPECTED] liquidity: 12437
// [EXPECTED] amount0: 1000, amount1: 368
// [EXPECTED] position owner: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
//
// [SCENARIO] 5. Create external incentive with native coin
// [INFO] prepare 10_000_000_000 ugnot for external incentive
// [INFO] add token and approve gns
// [INFO] create external incentive with native coin
// [INFO] create external incentive with incentiveID:  g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d:150:1
// [INFO] external incentive created - start: 1234569600, end: 1242345600
// [EXPECTED] admin wugnot balance after external incentive: 0
//
// [SCENARIO] 6. Stake token 01
// [INFO] approve NFT to staker for token 01
// [INFO] stake token 01
// [EXPECTED] NFT owner after staking: g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu
//
// [SCENARIO] 7. Stake token 02
// [INFO] approve NFT to staker for token 02
// [INFO] stake token 02
// [EXPECTED] NFT owner after staking: g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu
//
// [SCENARIO] 8. Collect reward for token 01
// [INFO] skip blocks to accumulate rewards
// [INFO] wugnot balance before collect: 0
// [INFO] ugnot balance before collect: 10099998010
// [INFO] collect reward for token 01 (no unwrap)
// [EXPECTED] wugnot balance after collect: 196243
// [EXPECTED] ugnot balance after collect: 10099998010
// [EXPECTED] wugnot increase: 196243
// [EXPECTED] ugnot change: 0
//
// [SCENARIO] 9. Unstake token 02
// [INFO] skip more blocks
// [INFO] wugnot balance before unstake: 196243
// [INFO] ugnot balance before unstake: 10099998010
// [INFO] unstake token 02 (no unwrap)
// [EXPECTED] NFT owner after unstaking: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
// [EXPECTED] wugnot balance after unstake: 694953
// [EXPECTED] ugnot balance after unstake: 10099998010
// [EXPECTED] wugnot increase from unstake: 498710
// [EXPECTED] ugnot change from unstake: 0
//
// [SCENARIO] 10. End external incentive
// [INFO] approve wugnot for unwrapping
// [INFO] wugnot balance before end: 694953
// [INFO] ugnot balance before end: 10099998010
// [INFO] skip to end of external incentive
// [INFO] end external incentive
// [EXPECTED] wugnot balance after end: 694953
// [EXPECTED] ugnot balance after end: 10099998010
// [EXPECTED] wugnot change: 0
// [EXPECTED] ugnot refund: 0
