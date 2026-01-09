// staker protocol fee reward

package main

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/gov/staker"

	"gno.land/r/gnoswap/gns"
)

var (
	t *testing.T

	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	poolAddr      = access.MustGetAddress(prbac.ROLE_POOL.String())
	stakerAddr    = access.MustGetAddress(prbac.ROLE_STAKER.String())
	gnoStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())

	aliceAddr = testutils.TestAddress("alice")

	gnsPath = "gno.land/r/gnoswap/gns"
	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"
)

func main() {
	println("[SCENARIO] 1. Delegate GNS from alice to admin")
	delegateWithMint(aliceAddr, adminAddr, 1_000_000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 2. Add protocol fee by pool creation")
	createPoolByAdmin(barPath, quxPath, 3000)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 3. Check and collect protocol fee reward for alice (include create pool fee)")
	createPoolByAdmin(barPath, quxPath, 500)
	checkBalanceFn(gnsPath, aliceAddr, func() {
		collectProtocolFee(aliceAddr)
	})
	println()

	println("[SCENARIO] 4. Not available to claim protocol fee reward in same block")
	createPoolByAdmin(barPath, quxPath, 100)
	uassert.AbortsContains(t, "not claimable", func() {
		collectProtocolFee(aliceAddr)
	})
	println("[EXPECTED] not claimable protocol fee reward twice in same block")
}

func delegateWithMint(from, to address, amount int64) {
	// if from is not admin, transfer GNS from admin to from
	if from != adminAddr {
		testing.SetRealm(adminRealm)
		gns.Transfer(cross, from, amount)
	}

	testing.SetRealm(testing.NewUserRealm(from))
	gns.Approve(cross, gnoStakerAddr, amount)
	staker.Delegate(cross, to, int64(amount), "")

	ufmt.Printf("[INFO] delegated %d GNS from %s to %s\n", amount, from, to)
}

func createPoolByAdmin(token0, token1 string, fee int64) {
	testing.SetRealm(adminRealm)
	poolCreationFee := pool.GetPoolCreationFee()
	gns.Approve(cross, poolAddr, poolCreationFee)

	pool.CreatePool(cross, token0, token1, uint32(fee), common.TickMathGetSqrtRatioAtTick(0).ToString())

	ufmt.Printf("[INFO] created %s:%s:%d pool (poolCreationFee: %d)\n", token0, token1, fee, poolCreationFee)
}

func collectProtocolFee(addr address) {
	testing.SetRealm(testing.NewUserRealm(addr))
	staker.CollectReward(cross)

	println("[INFO] collected protocol fee reward for ", addr)
}

func checkBalanceFn(tokenPath string, addr address, fn func()) {
	testing.SetRealm(testing.NewUserRealm(addr))

	balanceBefore := common.BalanceOf(tokenPath, addr)
	fn()
	balanceAfter := common.BalanceOf(tokenPath, addr)

	ufmt.Printf("[EXPECTED] %s's balance of %s: %d\n", addr, tokenPath, balanceAfter-balanceBefore)
}

// Output:
// [SCENARIO] 1. Delegate GNS from alice to admin
// [INFO] delegated 1000000 GNS from g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
//
// [SCENARIO] 2. Add protocol fee by pool creation
// [INFO] created gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000 pool (poolCreationFee: 100000000)
//
// [SCENARIO] 3. Check and collect protocol fee reward for alice (include create pool fee)
// [INFO] created gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:500 pool (poolCreationFee: 100000000)
// [INFO] collected protocol fee reward for  g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
// [EXPECTED] g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh's balance of gno.land/r/gnoswap/gns: 200000000
//
// [SCENARIO] 4. Not available to claim protocol fee reward in same block
// [INFO] created gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100 pool (poolCreationFee: 100000000)
// [EXPECTED] not claimable protocol fee reward twice in same block
