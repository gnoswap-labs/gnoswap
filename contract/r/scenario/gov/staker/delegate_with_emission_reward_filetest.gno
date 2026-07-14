// PKGPATH: gno.land/r/gnoswap/v1/main

// delegate with emission reward distribution

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	en "gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/protocol_fee"

	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

var (
	admin      = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(admin)

	govStakerAddr, _ = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm   = testing.NewUserRealm(govStakerAddr)

	dummyToAddr  = testutils.TestAddress("dummyTo")
	dummyToRealm = testing.NewUserRealm(dummyToAddr)

	dummyAddr  = testutils.TestAddress("dummy")
	dummyRealm = testing.NewUserRealm(dummyAddr)

	minAmount = int64(1_000_000)
)

func main(cur realm) {
	println("[SCENARIO] 1. Change GNS emission distribution ratio")
	changeEmissionDistribution(cur)
	println()

	println("[SCENARIO] 2. Admin delegates GNS to dummyTo")
	adminDelegateToDummyTo(cur)
	println()

	println("[SCENARIO] 3. Admin delegates GNS to dummy")
	adminDelegateToDummy(cur)
	println()

	println("[SCENARIO] 4. Skip blocks and distribute emission")
	skipBlocksAndDistribute(cur)
	println()

	println("[SCENARIO] 5. Check and collect emission reward")
	emissionRewardScenario(cur)
	println()
}

// Change emission distribution ratio
func changeEmissionDistribution(cur realm) {
	// change emission distribution ratio
	testing.SetRealm(adminRealm)
	en.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	en.ChangeDistributionPct(
		cross(cur),
		7000, // liquidityStakerPct
		2000, // devOpsPct
		500,  // communityPoolPct
		500,  // govStakerPct
	)
	println("[INFO] emission distribution ratio changed: staker 70%, devops 20%, community 5%, govstaker 5%")
}

// Admin delegates GNS to dummyTo
func adminDelegateToDummyTo(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), govStakerAddr, minAmount)
	staker.Delegate(cross(cur), dummyToAddr, int64(minAmount), "")
	ufmt.Printf("[INFO] delegated %d GNS from admin to dummyTo\n", minAmount)
}

// Admin delegates GNS to dummy
func adminDelegateToDummy(cur realm) {
	testing.SetRealm(adminRealm)
	amount := 5 * minAmount
	gns.Transfer(cross(cur), dummyAddr, amount)
	testing.SetRealm(dummyRealm)
	gns.Approve(cross(cur), govStakerAddr, amount)
	staker.Delegate(cross(cur), dummyAddr, int64(amount), "")
	ufmt.Printf("[INFO] delegated %d GNS from admin to dummy\n", amount)
}

// Skip blocks and distribute emission
func skipBlocksAndDistribute(cur realm) {
	// skip blocks and distribute emission
	testing.SkipHeights(10)
	en.MintAndDistributeGns(cross(cur))
	println("[INFO] skipped 10 blocks and distributed emission")
}

func formatProtocolFees(cur realm, fees map[string]int64) string {
	if len(fees) == 0 {
		return "map[]"
	}
	result := "map["
	first := true
	for k, v := range fees {
		if !first {
			result += " "
		}
		result += k + ":" + ufmt.Sprintf("%d", v)
		first = false
	}
	result += "]"
	return result
}

// check and collect emission reward for dummy
func emissionRewardScenario(cur realm) {
	testing.SetRealm(govStakerRealm)
	emission.MintAndDistributeGns(cross(cur))
	protocol_fee.DistributeProtocolFee(cross(cur))
	emissionReward, protocolFees, _ := staker.GetClaimableRewardByAddress(dummyAddr)
	ufmt.Printf("[INFO] claimable reward (dummy): emissionReward=%d, protocolFees=%s\n", emissionReward, formatProtocolFees(cur, protocolFees))

	// Collect reward
	testing.SetOriginCaller(dummyAddr)
	staker.CollectReward(cross(cur))
	println("[INFO] collected emission reward for dummy")
	after := gns.BalanceOf(dummyAddr)
	ufmt.Printf("[EXPECTED] dummy GNS balance after collect: %d\n", after)
}

// Output:
// [SCENARIO] 1. Change GNS emission distribution ratio
// [INFO] emission distribution ratio changed: staker 70%, devops 20%, community 5%, govstaker 5%
//
// [SCENARIO] 2. Admin delegates GNS to dummyTo
// [INFO] delegated 1000000 GNS from admin to dummyTo
//
// [SCENARIO] 3. Admin delegates GNS to dummy
// [INFO] delegated 5000000 GNS from admin to dummy
//
// [SCENARIO] 4. Skip blocks and distribute emission
// [INFO] skipped 10 blocks and distributed emission
//
// [SCENARIO] 5. Check and collect emission reward
// [INFO] claimable reward (dummy): emissionReward=14863964, protocolFees=map[]
// [INFO] collected emission reward for dummy
// [EXPECTED] dummy GNS balance after collect: 14863964
