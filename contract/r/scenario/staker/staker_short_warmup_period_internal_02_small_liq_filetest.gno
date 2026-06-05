// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	en "gno.land/r/gnoswap/emission"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"

	fee100 uint32 = 100

	max_timeout           int64 = 9999999999
	maxInt64              int64 = 9223372036854775807
	MUST_EXISTS_IN_TIER_1       = "gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000"
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup(cur)
	println()

	println("[SCENARIO] 2. Mint and distribute GNS")
	doubleMint(cur)
	println()

	println("[SCENARIO] 3. Create pool")
	createPool(cur)
	println()

	println("[SCENARIO] 4. Mint position 01 with large liquidity")
	mintBarQux100_1(cur)
	println()

	println("[SCENARIO] 5. Mint position 02 with small liquidity")
	mintBarQux100_2(cur)
	println()

	println("[SCENARIO] 6. Stake both positions")
	stakeToken_1_2(cur)
	println()

	println("[SCENARIO] 7. Collect rewards and verify distribution")
	collectRewardBoth(cur)
	println()
}

func initAndSetup(cur realm) {
	testing.SetRealm(adminRealm)
	en.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)

	// override warm-up period for testing
	sr.SetWarmUp(cross(cur), 30, 150)
	sr.SetWarmUp(cross(cur), 50, 300)
	sr.SetWarmUp(cross(cur), 70, 900)
	sr.SetWarmUp(cross(cur), 100, maxInt64)

	// set unstaking fee to 0
	sr.SetUnStakingFee(cross(cur), 0)

	// set pool creation fee to 0
	pl.SetPoolCreationFee(cross(cur), 0)

	// set community pool distribution to 0% (give it to devOps)
	en.ChangeDistributionPct(
		cross(cur),
		7500, // liquidityStakerPct
		2500, // devOpsPct
		0, // communityPoolPct
		0, // govStakerPct
	)

	testing.SetRealm(stakerRealm)
	testing.SkipHeights(1)
}

func doubleMint(cur realm) {
	testing.SetRealm(adminRealm)
	en.MintAndDistributeGns(cross(cur))
	en.MintAndDistributeGns(cross(cur))

	ufmt.Printf("[EXPECTED] GNS minted and distributed\n")
	testing.SkipHeights(1)
}

func createPool(cur realm) {
	testing.SetRealm(adminRealm)

	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee()*3)

	pl.CreatePool(cross(cur), barPath, quxPath, 100, "79228162514264337593543950337")
	sr.SetPoolTier(cross(cur), "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", 1)

	ufmt.Printf("[EXPECTED] pool created and set to tier 1\n")
	testing.SkipHeights(1)
}

func mintBarQux100_1(cur realm) {
	testing.SetRealm(adminRealm)

	bar.Approve(cross(cur), poolAddr, maxInt64)
	qux.Approve(cross(cur), poolAddr, maxInt64)

	positionId, _, _, _ := pn.Mint(
		cross(cur),
		barPath,
		quxPath,
		fee100,
		int32(-1000),
		int32(1000),
		"500000000",
		"500000000",
		"1",
		"1",
		max_timeout,
		adminUser,
		"",
	)

	if positionId != 1 {
		panic("expected position id 1")
	}

	owner, err := gnft.OwnerOf(positionIdFrom(cur, positionId))
	if err != nil || owner != adminUser {
		panic("unexpected owner")
	}

	ufmt.Printf("[EXPECTED] position 01 minted with large liquidity: id=%d\n", positionId)
	testing.SkipHeights(1)
}

func mintBarQux100_2(cur realm) {
	testing.SetRealm(adminRealm)

	bar.Approve(cross(cur), poolAddr, maxInt64)
	qux.Approve(cross(cur), poolAddr, maxInt64)

	positionId, _, _, _ := pn.Mint(
		cross(cur),
		barPath,
		quxPath,
		fee100,
		int32(-1000),
		int32(1000),
		"500",
		"500",
		"1",
		"1",
		max_timeout,
		adminUser,
		"",
	)

	if positionId != 2 {
		panic("expected position id 2")
	}

	owner, err := gnft.OwnerOf(positionIdFrom(cur, positionId))
	if err != nil || owner != adminUser {
		panic("unexpected owner")
	}

	ufmt.Printf("[EXPECTED] position 02 minted with small liquidity: id=%d\n", positionId)
	testing.SkipHeights(1)
}

func stakeToken_1_2(cur realm) {
	testing.SetRealm(adminRealm)

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, 1))
	sr.StakeToken(cross(cur), 1, "")

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, 2))
	sr.StakeToken(cross(cur), 2, "")

	ufmt.Printf("[EXPECTED] both positions staked successfully\n")
	testing.SkipHeights(1)
}

func collectRewardBoth(cur realm) {
	// reward per block 10702054

	// total staked liquidity = 10252593386
	// > position-01: 10252583134 // ratio 99.9999000058%
	//  > 10702054 * 99.9999000058% = 10702043.2985667191
	//  > warm up = 10702043.2985667191 * 30% = 3210612.9895700157

	// > position-02: 10252 // ratio 0.0000999942%
	//  > 10702054 * 0.0000999942% = 10.7014332809
	//  > warm up = 10.7014332809 * 30% = 3.2104299843

	println("[INFO] collecting reward for position 01 (large liquidity)")
	testing.SetRealm(adminRealm)

	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), 1)
	newGns := gns.BalanceOf(adminUser)
	diff := newGns - beforeGns
	ufmt.Printf("[EXPECTED] position 01 reward: %d GNS\n", diff)
	// reward 3210612
	// penalty 7491431
	// total 10702043

	println("[INFO] collecting reward for position 02 (small liquidity)")
	testing.SetRealm(adminRealm)

	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), 2)
	newGns = gns.BalanceOf(adminUser)
	diff = newGns - beforeGns
	ufmt.Printf("[EXPECTED] position 02 reward: %d GNS\n", diff)
	// reward 3
	// penalty 7
	// total 10
}

func positionIdFrom(cur realm, positionId any) grc721.TokenID {
	switch positionId := positionId.(type) {
	case string:
		return grc721.TokenID(positionId)
	case int:
		return grc721.TokenID(strconv.Itoa(positionId))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId)))
	case grc721.TokenID:
		return positionId
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize and setup
//
// [SCENARIO] 2. Mint and distribute GNS
// [EXPECTED] GNS minted and distributed
//
// [SCENARIO] 3. Create pool
// [EXPECTED] pool created and set to tier 1
//
// [SCENARIO] 4. Mint position 01 with large liquidity
// [EXPECTED] position 01 minted with large liquidity: id=1
//
// [SCENARIO] 5. Mint position 02 with small liquidity
// [EXPECTED] position 02 minted with small liquidity: id=2
//
// [SCENARIO] 6. Stake both positions
// [EXPECTED] both positions staked successfully
//
// [SCENARIO] 7. Collect rewards and verify distribution
// [INFO] collecting reward for position 01 (large liquidity)
// [EXPECTED] position 01 reward: 4013265 GNS
// [INFO] collecting reward for position 02 (small liquidity)
// [EXPECTED] position 02 reward: 3 GNS
