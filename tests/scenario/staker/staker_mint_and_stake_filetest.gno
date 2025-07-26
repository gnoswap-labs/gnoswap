// staker mint and stake scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/demo/wugnot"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
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
	quxPath = "gno.land/r/onbloc/qux"

	gnsPath    = "gno.land/r/gnoswap/v1/gns"
	wugnotPath = "gno.land/r/demo/wugnot"

	fee3000 uint32 = 3000

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807
)

func main() {
	println("[SCENARIO] 1. Initialize account and emission")
	initAccountAndEmission()
	println()

	println("[SCENARIO] 2. Create pools")
	createPools()
	println()

	println("[SCENARIO] 3. Mint and stake native token position")
	mintAndStakeNative()
	println()

	println("[SCENARIO] 4. Mint and stake GRC20 pair position")
	mintAndStakeGRC20Pair()
}

func initAccountAndEmission() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPools() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve gns for pool creation")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
	testing.SkipHeights(1)

	println("[INFO] create gnot:gns:3000 pool")
	pl.CreatePool(cross, "gnot", "gno.land/r/gnoswap/v1/gns", 3000, common.TickMathGetSqrtRatioAtTick(0).ToString()) // price ratio 1:1

	println("[INFO] create bar:qux:3000 pool")
	pl.CreatePool(cross, barPath, quxPath, 3000, common.TickMathGetSqrtRatioAtTick(10000).ToString()) // tick 10_000 ≈ x2.7

	println("[INFO] set bar:qux:3000 pool to tier 1")
	sr.SetPoolTierByAdmin(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000", 1)

	testing.SkipHeights(1)
}

func mintAndStakeNative() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for native mint and stake")
	gns.Approve(cross, poolAddr, maxInt64)
	wugnot.Approve(cross, poolAddr, maxInt64)
	wugnot.Approve(cross, positionAddr, maxInt64)

	testing.SkipHeights(2)

	println("[INFO] prepare 100005 ugnot (5 for refund test)")
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 100005}})

	ugnotBalance := ugnotBalanceOf(adminAddr)
	ufmt.Printf("[INFO] admin ugnot balance before: %d\n", ugnotBalance)

	positionUgnotBalance := ugnotBalanceOf(positionAddr)
	ufmt.Printf("[INFO] position contract ugnot balance before: %d\n", positionUgnotBalance)

	println("[INFO] send ugnot to staker and set origin send")
	banker := std.NewBanker(std.BankerTypeRealmIssue)
	banker.SendCoins(adminAddr, stakerAddr, std.Coins{{"ugnot", 100005}})
	testing.SetOriginSend(std.Coins{{"ugnot", 100005}})

	adminOldWugnotBalance := wugnot.BalanceOf(adminUser)
	ufmt.Printf("[INFO] admin wugnot balance before mint and stake: %d\n", adminOldWugnotBalance)

	println("[INFO] mint and stake native position")
	lpTokenId, liquidity, amount0, amount1, poolPath := sr.MintAndStake(
		cross,
		"gnot",
		"gno.land/r/gnoswap/v1/gns",
		fee3000,
		int32(-5040),
		int32(5040),
		"100000",
		"100000",
		"1",
		"1",
		maxTimeout,
		"",
	)

	ufmt.Printf("[EXPECTED] native mint and stake - LP token ID: %d\n", lpTokenId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s, amount1: %s\n", amount0, amount1)
	ufmt.Printf("[EXPECTED] pool path: %s\n", poolPath)

	testing.SkipHeights(1)

	// Check final balances
	adminNewWugnotBalance := wugnot.BalanceOf(adminUser)
	ufmt.Printf("[EXPECTED] admin wugnot balance after: %d\n", adminNewWugnotBalance)

	finalUgnotBalance := ugnotBalanceOf(adminAddr)
	ufmt.Printf("[EXPECTED] admin ugnot balance after (refund): %d\n", finalUgnotBalance)
}

func mintAndStakeGRC20Pair() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for GRC20 mint and stake")
	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(2)

	println("[INFO] mint and stake GRC20 pair position")
	lpTokenId, liquidity, amount0, amount1, poolPath := sr.MintAndStake(
		cross,
		barPath,
		quxPath,
		fee3000,
		int32(9000),
		int32(12000),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		"",
	)

	ufmt.Printf("[EXPECTED] GRC20 mint and stake - LP token ID: %d\n", lpTokenId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s, amount1: %s\n", amount0, amount1)
	ufmt.Printf("[EXPECTED] pool path: %s\n", poolPath)

	testing.SkipHeights(1)
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
// [SCENARIO] 1. Initialize account and emission
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create pools
// [INFO] approve gns for pool creation
// [INFO] create gnot:gns:3000 pool
// [INFO] create bar:qux:3000 pool
// [INFO] set bar:qux:3000 pool to tier 1
//
// [SCENARIO] 3. Mint and stake native token position
// [INFO] approve tokens for native mint and stake
// [INFO] prepare 100005 ugnot (5 for refund test)
// [INFO] admin ugnot balance before: 100005
// [INFO] position contract ugnot balance before: 0
// [INFO] send ugnot to staker and set origin send
// [INFO] admin wugnot balance before mint and stake: 0
// [INFO] mint and stake native position
// [EXPECTED] native mint and stake - LP token ID: 1
// [EXPECTED] liquidity: 448942
// [EXPECTED] amount0: 100000, amount1: 100000
// [EXPECTED] pool path: gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000
// [EXPECTED] admin wugnot balance after: 0
// [EXPECTED] admin ugnot balance after (refund): 5
//
// [SCENARIO] 4. Mint and stake GRC20 pair position
// [INFO] approve tokens for GRC20 mint and stake
// [INFO] mint and stake GRC20 pair position
// [EXPECTED] GRC20 mint and stake - LP token ID: 2
// [EXPECTED] liquidity: 12437
// [EXPECTED] amount0: 718, amount1: 1000
// [EXPECTED] pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000
