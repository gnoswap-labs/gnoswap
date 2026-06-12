// emission halt distribution
//
// Scenario:
//   1. Collect emission reward before halt
//   2. Halt emission
//   3. Collect emission reward after halt
//   4. Resume emission
//   5. Collect emission reward after resume

// PKGPATH: gno.land/r/demo/main

package main

import (
	"gno.land/p/gnoswap/gnsmath"
	"chain"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	_ "gno.land/r/gnoswap/rbac"
	"gno.land/r/gnoswap/staker"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	adminAddr, _       = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm         = testing.NewUserRealm(adminAddr)
	poolAddr, _        = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _      = access.GetAddress(prbac.ROLE_ROUTER.String())
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	stakerAddr, _      = access.GetAddress(prbac.ROLE_STAKER.String())
	emissionAddr, _    = access.GetAddress(prbac.ROLE_EMISSION.String())
	routerRealm        = testing.NewUserRealm(routerAddr)

	wugnotPath        = "gno.land/r/gnoland/wugnot"
	gnsPath           = "gno.land/r/gnoswap/gns"
	fee3000    uint32 = 3000

	wugnotGnsPoolPath = ufmt.Sprintf("%s:%s:%d", wugnotPath, gnsPath, fee3000)
)

func main(cur realm) {
	ufmt.Println("[SCENARIO] 1. Initialize emission state and pool")
	initEmissionState(cur)
	initPool(cur)
	testing.SkipHeights(1)
	println()

	ufmt.Println("[SCENARIO] 2. Mint position and stake")
	testing.SetRealm(adminRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 100000000000000}})
	wugnot.Deposit(cross(cur))
	testing.SetOriginSend(chain.Coins{})
	mintPositionAndStake(cur)
	testing.SkipHeights(1)
	println()

	ufmt.Println("[SCENARIO] 3. Collect rewards before halt")
	collectRewards(cur, 1)
	testing.SkipHeights(1)
	println()

	ufmt.Println("[SCENARIO] 4. Set emission halt")
	setEmissionHaltState(cur, true)
	println()

	ufmt.Println("[SCENARIO] 5. Collect rewards after halt")
	testing.SkipHeights(1)
	println()

	ufmt.Println("[SCENARIO] 5. Mint position and stake after halt")
	testing.SetRealm(adminRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 100000000000000}})
	wugnot.Deposit(cross(cur))
	testing.SetOriginSend(chain.Coins{})
	mintPositionAndStake(cur)
	testing.SkipHeights(1)
	println()

	ufmt.Println("[SCENARIO] 6. Resume emission")
	setEmissionHaltState(cur, false)
	println()

	ufmt.Println("[SCENARIO] 7. Collect rewards after resume")
	collectRewards(cur, 1, 2)
	testing.SkipHeights(1)
	println()
}

func initEmissionState(cur realm) {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)

	ufmt.Println("[INFO] Initializing emission state")
}

func initPool(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)

	testing.SetRealm(adminRealm)

	pool.CreatePool(
		cross(cur),
		wugnotPath,
		gnsPath,
		fee3000,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	ufmt.Println("[INFO] Pool created: %s (tier: 1)", wugnotGnsPoolPath)
}

func mintPositionAndStake(cur realm) {
	testing.SetRealm(adminRealm)

	wugnot.Approve(cross(cur), poolAddr, INT64_MAX)
	gns.Approve(cross(cur), poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting and staking position")
	testing.SetOriginSend(chain.Coins{})
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross(cur),
		wugnotPath,
		gnsPath,
		fee3000,
		-6960,
		6960,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		adminAddr,
		"",
	)

	gnft.Approve(cross(cur), stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId))))
	staker.StakeToken(cross(cur), positionId, "")

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func setEmissionHaltState(cur realm, halted bool) {
	testing.SetRealm(adminRealm)
	halt.SetOperationStatus(cross(cur), halt.OpTypeEmission, halted)

	ufmt.Printf("[INFO] Emission halt state set to %t\n", halted)
}

func collectRewards(cur realm, positionIds ...uint64) {
	testing.SetRealm(adminRealm)

	var totalAdminRewards int64
	var totalStakerBalanceChanges int64

	checkEmissionDistributionChangesFn(cur, func() {
		stakerBalanceBeforeMint := gns.BalanceOf(stakerAddr)
		emission.MintAndDistributeGns(cross(cur))
		totalStakerBalanceChanges = gns.BalanceOf(stakerAddr) - stakerBalanceBeforeMint

		for _, positionId := range positionIds {
			beforeCollectedGns := gns.BalanceOf(adminAddr)
			staker.CollectReward(cross(cur), positionId)
			afterCollectedGns := gns.BalanceOf(adminAddr)

			totalAdminRewards += (afterCollectedGns - beforeCollectedGns)
			ufmt.Printf("[INFO] reward accumulated for position %d: %d\n", positionId, afterCollectedGns-beforeCollectedGns)
		}
	})

	ufmt.Printf("[EXPECTED] total staker balance changes: %d\n", totalStakerBalanceChanges)
	ufmt.Printf("[EXPECTED] total reward: %d\n", totalAdminRewards)
}

func checkEmissionDistributionChangesFn(cur realm, fn func()) {
	beforeTimestamp := time.Now().Unix()
	beforeEmissionDistributionBalance := emission.GetDistributedToStaker()
	fn()
	afterTimestamp := time.Now().Unix()
	afterEmissionDistributionBalance := emission.GetDistributedToStaker()
	lastDistributedTimestamp := emission.GetLastExecutedTimestamp()
	ufmt.Printf("[INFO] Check emission distribution amount to staker (last distributed: %d)\n", lastDistributedTimestamp)
	ufmt.Printf("[INFO] Emission distribution balance changed: %d (%d seconds)\n", afterEmissionDistributionBalance-beforeEmissionDistributionBalance, afterTimestamp-beforeTimestamp)
}

// Output:
// [SCENARIO] 1. Initialize emission state and pool
// [INFO] Initializing emission state
// [INFO] Pool created: %s (tier: 1) gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000
//
// [SCENARIO] 2. Mint position and stake
// [INFO] Minting and staking position
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 170132354
// [EXPECTED] Amount0 should be 50000000
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 3. Collect rewards before halt
// [INFO] reward accumulated for position 1: 7946275
// [INFO] Check emission distribution amount to staker (last distributed: 1234567900)
// [INFO] Emission distribution balance changed: 26755137 (0 seconds)
// [EXPECTED] total staker balance changes: 26755137
// [EXPECTED] total reward: 7946275
//
// [SCENARIO] 4. Set emission halt
// [INFO] Emission halt state set to true
//
// [SCENARIO] 5. Collect rewards after halt
//
// [SCENARIO] 5. Mint position and stake after halt
// [INFO] Minting and staking position
// [EXPECTED] Position ID should be 2
// [EXPECTED] Liquidity should be 170132354
// [EXPECTED] Amount0 should be 50000000
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 6. Resume emission
// [INFO] Emission halt state set to false
//
// [SCENARIO] 7. Collect rewards after resume
// [INFO] reward accumulated for position 1: 19865688
// [INFO] reward accumulated for position 2: 3973138
// [INFO] Check emission distribution amount to staker (last distributed: 1234567915)
// [INFO] Emission distribution balance changed: 80265409 (0 seconds)
// [EXPECTED] total staker balance changes: 80265409
// [EXPECTED] total reward: 23838826
