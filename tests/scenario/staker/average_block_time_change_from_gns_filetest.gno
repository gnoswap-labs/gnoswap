// PKGPATH: gno.land/r/gnoswap/v1/main
// POOLs:
// 1. gnot:gns:3000

// POSITIONs:
// 1. in-range ( will be unstaked )

// REWARDs:
// - internal tier 1 ( gnot:gns:3000 )
// - halving changes

package main

import (
	"math"
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

	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	quxPath = "gno.land/r/onbloc/qux"
	oblPath = "gno.land/r/onbloc/obl"

	gnsPath    = "gno.land/r/gnoswap/v1/gns"
	wugnotPath = "gno.land/r/demo/wugnot"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999

	// external incentive deposit fee
	depositGnsAmount uint64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS  int64 = 90 * 24 * 60 * 60
	TIMESTAMP_180DAYS int64 = 180 * 24 * 60 * 60
	TIMESTAMP_365DAYS int64 = 365 * 24 * 60 * 60

	poolPath = "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000"
)

func main() {
	testInit()
	testCreatePool()
	testMintWugnotGnsPos01()
	testStakeTokenPos01()
	testGnsAvgBlockTime()
}

func testInit() {
	testing.SetRealm(adminRealm)

	// prepare wugnot
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 100_000_000_000_000}})
	testing.SetRealm(adminRealm)
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminAddr, wugnotAddr, std.Coins{{"ugnot", 50_000_000_000_000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 50_000_000_000_000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(nil)

	testing.SetRealm(stakerRealm)
	emission.RegisterGnsChangeCallback(cross)

	// set unstaking fee to 0
	testing.SetRealm(adminRealm)
	sr.SetUnStakingFeeByAdmin(cross, 0)
}

func testCreatePool() {
	testing.SetRealm(adminRealm)

	pl.SetPoolCreationFeeByAdmin(cross, 0)

	testing.SkipHeights(1)
	pl.CreatePool(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(), // 79228162514264337593543950337
	)
}

func testMintWugnotGnsPos01() {
	testing.SetRealm(adminRealm)

	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	testing.SkipHeights(1)
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

func testStakeTokenPos01() {
	testing.SetRealm(adminRealm)

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

func testGnsAvgBlockTime() {
	testing.SetRealm(adminRealm)

	before := gns.BalanceOf(adminUser)
	testing.SkipHeights(1)
	sr.CollectReward(cross, 1, false)
	after := gns.BalanceOf(adminUser)

	diff := after - before // actual reward for 1 block when avg block time was 2000ms(2s)
	ufmt.Println("[INFO] balance changes by 1 block when avg block time was 2000ms(2s)", diff)

	gns.SetAvgBlockTimeInMsByAdmin(cross, 4000) // orig block time was 2000ms(2s), change it to 4s

	before = gns.BalanceOf(adminUser)
	testing.SkipHeights(1)
	sr.CollectReward(cross, 1, false) // actual reward for 1 block when avg block time was 4000ms(4s)
	after = gns.BalanceOf(adminUser)
	diff = after - before
	ufmt.Println("[INFO] balance changes by 1 block when avg block time was 4000ms(4s)", diff)
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

// returns true if actual is within 0.0001% of expected
func isInErrorRange(expected int64, actual int64) bool {
	maxSafeValue := int64(math.MaxInt64 / 100001)
	var lowerBound, upperBound int64
	if expected > maxSafeValue {
		lowerBound = expected / 1000000 * 999999
		upperBound = expected / 1000000 * 1000001
	} else {
		lowerBound = expected * 999999 / 1000000
		upperBound = expected * 1000001 / 1000000
	}
	return actual >= lowerBound && actual <= upperBound
}

// Output:
// [INFO] balance changes by 100 blocks 321061619
// [INFO] balance changes by 1 block when avg block time was 2000ms(2s) 3210615
// [INFO] balance changes by 1 block when avg block time was 4000ms(4s) 6421232
