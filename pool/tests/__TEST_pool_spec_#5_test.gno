package pool

import (
	"std"
	"testing"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"
	pl "gno.land/r/gnoswap/v2/pool"
)

var (
	test_tickLower                      = int32(9000)
	test_tickUpper                      = int32(11000)
	test_liquidityExpectStr             = "100000000"
	user1Addr               std.Address = "g1ecely4gjy0yl6s9kt409ll330q9hk2lj9ls3ec"
	minTick                             = int32(-887220)
	maxTick                             = int32(887220)
)

func init() {
	std.TestSkipHeights(100)
}

func AfterTest(t *testing.T) {
	poolRealm := std.NewUserRealm(consts.POOL_ADDR)
	std.TestSetRealm(poolRealm)
	std.TestSetOrigCaller(consts.POOL_ADDR)
	barBal := bar.BalanceOf(a2u(consts.POOL_ADDR))
	fooBal := foo.BalanceOf(a2u(consts.POOL_ADDR))
	bar.Transfer(a2u(gsa), barBal)
	foo.Transfer(a2u(gsa), fooBal)
	delete(pools, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000")
}

func TestSuccess_transfers_token1_only(t *testing.T) {
	// ================================ Pool Setup ================================================
	std.TestSetRealm(gsaRealm)
	std.TestSetOrigCaller(gsa)

	gns.Approve(a2u(consts.POOL_ADDR), poolCreationFee)

	token0Path := "gno.land/r/onbloc/foo"

	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	pl.CreatePool(barPath, token0Path, 3000, "25054144837504793118641380156") // encodePriceSqrt(1, 10)
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"

	std.TestSetRealm(posRealm)
	pl.Mint(token0Path, barPath, 3000, consts.POSITION_ADDR.String(), minTick, maxTick, "3161")

	// ===================== transfers token1 only =====================
	pool := GetPool(token0Path, barPath, 3000)
	tickSpacing := pool.tickSpacing

	std.TestSetRealm(posRealm)
	pl.Mint(token0Path, barPath, 3000, consts.POSITION_ADDR.String(), -46080, -23040, "10000")

	barBalance := bar.BalanceOf(a2u(consts.POOL_ADDR))
	fooBalance := foo.BalanceOf(a2u(consts.POOL_ADDR))

	shouldEQ(t, barBalance, uint64(9996))
	shouldEQ(t, fooBalance, uint64(1000+2162))

	AfterTest(t)
}

func TestSuccess_min_tick_with_max_leverage(t *testing.T) {
	// ================================ Pool Setup ================================================
	std.TestSetRealm(gsaRealm)
	std.TestSetOrigCaller(gsa)

	gns.Approve(a2u(consts.POOL_ADDR), poolCreationFee)

	token0Path := "gno.land/r/onbloc/foo"

	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	pl.CreatePool(barPath, token0Path, 3000, "25054144837504793118641380156") // encodePriceSqrt(1, 10)
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"

	std.TestSetRealm(posRealm)
	pl.Mint(token0Path, barPath, 3000, consts.POSITION_ADDR.String(), minTick, maxTick, "3161")

	// ===================== min tick with max leverage =====================
	pool := GetPool(token0Path, barPath, 3000)
	tickSpacing := pool.tickSpacing

	std.TestSetRealm(posRealm)
	pl.Mint(token0Path, barPath, 3000, consts.POSITION_ADDR.String(), minTick, minTick+tickSpacing, "5070602400912917605986812821504") // 2**102

	barBalance := bar.BalanceOf(a2u(consts.POOL_ADDR))
	fooBalance := foo.BalanceOf(a2u(consts.POOL_ADDR))

	shouldEQ(t, barBalance, uint64(9996)) // got 19992, expected 9996
	shouldEQ(t, fooBalance, uint64(1000+828011520))

	AfterTest(t)
}

func TestSuccess_work_for_min_tick(t *testing.T) {
	// ================================ Pool Setup ================================================
	std.TestSetRealm(gsaRealm)
	std.TestSetOrigCaller(gsa)

	gns.Approve(a2u(consts.POOL_ADDR), poolCreationFee)

	token0Path := "gno.land/r/onbloc/foo"

	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	pl.CreatePool(barPath, token0Path, 3000, "25054144837504793118641380156") // encodePriceSqrt(1, 10)
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"

	std.TestSetRealm(posRealm)
	pl.Mint(token0Path, barPath, 3000, consts.POSITION_ADDR.String(), minTick, maxTick, "3161")

	// ===================== work for min tick =====================
	pool := GetPool(token0Path, barPath, 3000)
	tickSpacing := pool.tickSpacing

	std.TestSetRealm(posRealm)
	pl.Mint(token0Path, barPath, 3000, consts.POSITION_ADDR.String(), minTick, -23040, "10000")

	barBalance := bar.BalanceOf(a2u(consts.POOL_ADDR))
	fooBalance := foo.BalanceOf(a2u(consts.POOL_ADDR))

	shouldEQ(t, barBalance, uint64(9996))
	shouldEQ(t, fooBalance, uint64(1000+3161))

	AfterTest(t)
}

func TestSuccess_removing_works(t *testing.T) {
	// ================================ Pool Setup ================================================
	std.TestSetRealm(gsaRealm)
	std.TestSetOrigCaller(gsa)

	gns.Approve(a2u(consts.POOL_ADDR), poolCreationFee)

	token0Path := "gno.land/r/onbloc/foo"

	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	pl.CreatePool(barPath, token0Path, 3000, "25054144837504793118641380156") // encodePriceSqrt(1, 10)
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"

	std.TestSetRealm(posRealm)
	pl.Mint(token0Path, barPath, 3000, consts.POSITION_ADDR.String(), minTick, maxTick, "3161")

	// ===================== removing works =====================
	pool := GetPool(token0Path, barPath, 3000)
	tickSpacing := pool.tickSpacing

	std.TestSetRealm(posRealm)
	pl.Mint(token0Path, barPath, 3000, consts.POSITION_ADDR.String(), -46080, -46020, "10000")
	amount0, amount1 := pl.Burn(token0Path, barPath, 3000, -46080, -46020, "10000")

	shouldEQ(t, amount0, "0")
	shouldEQ(t, amount1, "3")
}

func gnsBalance(addr std.Address) uint64 {
	return gns.BalanceOf(a2u(addr))
}
