// PKGPATH: gno.land/r/gnoswap/v1/main

// Collecting an exit checkpoint must not disturb the pool's unclaimable bookkeeping.
//
// That accumulator is pool-global and only moves forward, while a checkpoint collects at the
// timestamp its position left the pool. Running it at that past timestamp rewinds the pool's
// marker, and everything since is then re-counted as unclaimable and paid to the community pool
// out of the shared reserve - on top of the rewards it already owes its stakers.
//
// One position opens an unclaimable period by unstaking, a pair of identical positions closes
// it, and the checkpoint is collected between that and their collects. The pair must be paid
// the same: whatever the checkpoint collect did to the pool, it did not land on one of them.

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	"gno.land/r/gnoswap/scenarioutils"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"

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
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _    = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _      = access.GetAddress(prabc.ROLE_POOL.String())
	communityAddr, _ = access.GetAddress(prabc.ROLE_COMMUNITY_POOL.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	bazPath = "gno.land/r/onbloc/baz.BAZ"

	fee100 uint32 = 100

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807
)

func main(cur realm) {
	println("[SCENARIO] 1. Open an unclaimable period, then close it with two identical positions")
	setup(cur)

	println()
	println("[SCENARIO] 2. Collect the checkpoint of the position that opened it")
	collectCheckpoint(cur)

	println()
	println("[SCENARIO] 3. The identical pair must collect identical amounts")
	comparePair(cur)
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)

	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)

	pl.CreatePool(cross(cur), barPath, bazPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross(cur), poolPath, 1)

	// Position 1 is the pool's only staked position, so unstaking it drops the pool to zero
	// staked liquidity and opens an unclaimable period.
	mint(cur)
	stake(cur, 1)
	testing.SkipHeights(100)
	sr.UnStakeToken(cross(cur), 1)
	testing.SkipHeights(100)

	// The pair closes that period and accrues identically from here on.
	mint(cur)
	stake(cur, 2)
	mint(cur)
	stake(cur, 3)
	testing.SkipHeights(100)
}

func collectCheckpoint(cur realm) {
	testing.SetRealm(adminRealm)

	before := gns.BalanceOf(communityAddr)
	sr.CollectReward(cross(cur), 1)

	ufmt.Printf("[EXPECTED] the unclaimable period was paid to the community pool: %t\n",
		gns.BalanceOf(communityAddr)-before > 0)
	ufmt.Printf("[EXPECTED] the checkpoint is gone: %t\n", !sr.HasUnstakedPosition(1))

	testing.SkipHeights(500)
}

func comparePair(cur realm) {
	testing.SetRealm(adminRealm)

	ownerFirst, communityFirst := collectDeltas(cur, 2)
	ownerSecond, communitySecond := collectDeltas(cur, 3)

	ufmt.Printf("[EXPECTED] both were paid a reward: %t\n", ownerFirst > 0 && ownerSecond > 0)
	ufmt.Printf("[EXPECTED] the owner amounts match: %t\n", ownerFirst == ownerSecond)
	// The pool always had liquidity over their window, so neither may be charged an unclaimable
	// amount on top of its own warmup penalty. The rewind paid the first collector more than six
	// times its owner amount; the penalty alone is a little over twice it.
	ufmt.Printf("[EXPECTED] neither was charged a rewound unclaimable amount: %t\n",
		communityFirst < ownerFirst*4 && communitySecond < ownerSecond*4)
}

// collectDeltas collects one position and reports what the owner and the community pool got.
func collectDeltas(cur realm, positionId uint64) (int64, int64) {
	ownerBefore := gns.BalanceOf(adminUser)
	communityBefore := gns.BalanceOf(communityAddr)

	sr.CollectReward(cross(cur), positionId)

	return gns.BalanceOf(adminUser) - ownerBefore, gns.BalanceOf(communityAddr) - communityBefore
}

func mint(cur realm) {
	pn.Mint(cross(cur), barPath, bazPath, fee100, -100, 100, "10000000", "10000000", "0", "0", maxTimeout, adminUser, "")
}

func stake(cur realm, positionId uint64) {
	gnft.Approve(cross(cur), stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId))))
	sr.StakeToken(cross(cur), positionId, "")
}

// Output:
// [SCENARIO] 1. Open an unclaimable period, then close it with two identical positions
//
// [SCENARIO] 2. Collect the checkpoint of the position that opened it
// [EXPECTED] the unclaimable period was paid to the community pool: true
// [EXPECTED] the checkpoint is gone: true
//
// [SCENARIO] 3. The identical pair must collect identical amounts
// [EXPECTED] both were paid a reward: true
// [EXPECTED] the owner amounts match: true
// [EXPECTED] neither was charged a rewound unclaimable amount: true
